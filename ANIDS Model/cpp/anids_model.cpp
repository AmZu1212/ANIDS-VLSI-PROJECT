#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

constexpr int DMA_VECTOR_WIDTH = 128;
constexpr int HIDDEN_NEURON_COUNT = 64;
constexpr int OUTPUT_NEURON_COUNT = 128;
constexpr int Q07_WIDTH = 8;
constexpr int HL_ACC_WIDTH = 15;
constexpr int OL_ACC_WIDTH = 15;
constexpr int LF_ACC_WIDTH = 15;
constexpr int LUT_ADDR_WIDTH = 8;

struct Config {
    int n = 128;
    int threshold = 0;
    std::array<std::array<int, DMA_VECTOR_WIDTH>, HIDDEN_NEURON_COUNT> hidden_weights{};
    std::array<int, HIDDEN_NEURON_COUNT> hidden_biases{};
    std::array<std::array<int, HIDDEN_NEURON_COUNT>, OUTPUT_NEURON_COUNT> output_weights{};
    std::array<int, OUTPUT_NEURON_COUNT> output_biases{};
    std::array<int, 1 << LUT_ADDR_WIDTH> function_lut{};
};

uint64_t mask_bits(int bits) {
    if (bits >= 64) {
        return UINT64_MAX;
    }
    return (uint64_t{1} << bits) - 1;
}

int to_signed(int64_t value, int bits) {
    uint64_t raw = static_cast<uint64_t>(value) & mask_bits(bits);
    uint64_t sign_bit = uint64_t{1} << (bits - 1);
    if (raw & sign_bit) {
        return static_cast<int>(static_cast<int64_t>(raw) - (int64_t{1} << bits));
    }
    return static_cast<int>(raw);
}

int wrap_signed(int64_t value, int bits) {
    return to_signed(value, bits);
}

int wrap_unsigned(int64_t value, int bits) {
    return static_cast<int>(static_cast<uint64_t>(value) & mask_bits(bits));
}

int trunc_slice_signed(int value, int in_bits, int msb, int width) {
    uint64_t raw = static_cast<uint64_t>(value) & mask_bits(in_bits);
    int lsb = msb - width + 1;
    uint64_t sliced = (raw >> lsb) & mask_bits(width);
    return to_signed(static_cast<int64_t>(sliced), width);
}

int saturating_add_q07(int lhs, int rhs) {
    int total = lhs + rhs;
    if (total > 127) {
        return 127;
    }
    if (total < -128) {
        return -128;
    }
    return total;
}

int relu_q07(int value) {
    return value > 0 ? value : 0;
}

int parse_int_token(const std::string &token) {
    std::size_t idx = 0;
    int base = 10;
    if (token.size() > 2 && token[0] == '0' && (token[1] == 'x' || token[1] == 'X')) {
        base = 16;
    }
    int value = std::stoi(token, &idx, base);
    if (idx != token.size()) {
        throw std::runtime_error("bad integer token: " + token);
    }
    return value;
}

unsigned __int128 parse_hex128(const std::string &token) {
    std::string s = token;
    if (s.size() > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        s = s.substr(2);
    }
    unsigned __int128 value = 0;
    for (char c : s) {
        int digit = 0;
        if (c >= '0' && c <= '9') {
            digit = c - '0';
        } else if (c >= 'a' && c <= 'f') {
            digit = c - 'a' + 10;
        } else if (c >= 'A' && c <= 'F') {
            digit = c - 'A' + 10;
        } else {
            throw std::runtime_error("bad hex vector token: " + token);
        }
        value = (value << 4) | static_cast<unsigned>(digit);
    }
    return value;
}

std::string trim_comment(const std::string &line) {
    std::size_t pos = line.find('#');
    return line.substr(0, pos);
}

std::vector<std::string> split_tokens(const std::string &line) {
    std::istringstream iss(trim_comment(line));
    std::vector<std::string> tokens;
    std::string token;
    while (iss >> token) {
        tokens.push_back(token);
    }
    return tokens;
}

int input_layer_pair(unsigned __int128 feature_vector, int counter) {
    if (counter < 0) {
        return 0;
    }
    int bit0 = static_cast<int>((feature_vector >> (counter * 2)) & 1);
    int bit1 = static_cast<int>((feature_vector >> (counter * 2 + 1)) & 1);
    return (bit1 << 1) | bit0;
}

int memory_mapper(int in_value) {
    int raw = wrap_unsigned(in_value, Q07_WIDTH);
    int sign = (raw >> 7) & 1;
    return ((~sign & 1) << 7) | (raw & 0x7f);
}

int hidden_neuron_result(unsigned __int128 feature_vector, const std::array<int, DMA_VECTOR_WIDTH> &weights, int bias, int n) {
    int acc = 0;
    int last_pair_index = (n >> 1) - 1;
    for (int counter = 0; counter <= last_pair_index; ++counter) {
        int pair = input_layer_pair(feature_vector, counter - 1);
        int gated0 = (pair & 1) ? weights[counter * 2] : 0;
        int gated1 = (pair & 2) ? weights[counter * 2 + 1] : 0;
        int pair_sum = wrap_signed(gated0 + gated1, 9);
        int acc_next = wrap_signed(acc + pair_sum, HL_ACC_WIDTH);
        if (counter == last_pair_index) {
            int trunc8 = trunc_slice_signed(acc_next, HL_ACC_WIDTH, HL_ACC_WIDTH - 1, Q07_WIDTH);
            return relu_q07(saturating_add_q07(trunc8, bias));
        }
        acc = acc_next;
    }
    throw std::runtime_error("invalid N: hidden loop did not run");
}

int output_neuron_result(const std::array<int, HIDDEN_NEURON_COUNT> &hidden_results,
                         const std::array<int, HIDDEN_NEURON_COUNT> &weights,
                         int bias,
                         int n) {
    int acc = 0;
    int last_step_index = (n >> 1) - 1;
    for (int counter = 0; counter <= last_step_index; ++counter) {
        int product_full = wrap_signed(hidden_results[counter] * weights[counter], 16);
        int product_q07 = trunc_slice_signed(product_full, 16, 14, 8);
        int acc_next = wrap_signed(acc + product_q07, OL_ACC_WIDTH);
        if (counter == last_step_index) {
            int trunc8 = trunc_slice_signed(acc_next, OL_ACC_WIDTH, OL_ACC_WIDTH - 1, Q07_WIDTH);
            return saturating_add_q07(trunc8, bias);
        }
        acc = acc_next;
    }
    throw std::runtime_error("invalid N: output loop did not run");
}

int loss_result(unsigned __int128 feature_vector, const std::array<int, OUTPUT_NEURON_COUNT> &output_results, const Config &config) {
    int acc = 0;
    int last_pair_index = (config.n >> 1) - 1;
    for (int counter = 0; counter <= last_pair_index; ++counter) {
        int pair = input_layer_pair(feature_vector, counter - 1);
        int x0 = pair & 1;
        int x1 = (pair >> 1) & 1;
        int r0 = output_results[counter * 2];
        int r1 = output_results[counter * 2 + 1];
        int f0 = config.function_lut[memory_mapper(r0)];
        int f1 = config.function_lut[memory_mapper(r1)];
        int pair_sum = std::abs(x0 - f0) + std::abs(x1 - f1);
        int acc_next = wrap_signed(acc + pair_sum, LF_ACC_WIDTH);
        if (counter == last_pair_index) {
            return trunc_slice_signed(acc_next, LF_ACC_WIDTH, LF_ACC_WIDTH - 1, Q07_WIDTH);
        }
        acc = acc_next;
    }
    throw std::runtime_error("invalid N: loss loop did not run");
}

std::pair<int, int> run_model(unsigned __int128 feature_vector, const Config &config) {
    std::array<int, HIDDEN_NEURON_COUNT> hidden{};
    std::array<int, OUTPUT_NEURON_COUNT> output{};

    for (int i = 0; i < HIDDEN_NEURON_COUNT; ++i) {
        hidden[i] = hidden_neuron_result(feature_vector, config.hidden_weights[i], config.hidden_biases[i], config.n);
    }
    for (int i = 0; i < OUTPUT_NEURON_COUNT; ++i) {
        output[i] = output_neuron_result(hidden, config.output_weights[i], config.output_biases[i], config.n);
    }

    int loss = loss_result(feature_vector, output, config);
    int anomaly = loss > config.threshold ? 1 : 0;
    return {loss, anomaly};
}

void load_loss_function(const std::string &path, Config &config) {
    std::ifstream in(path);
    if (!in) {
        throw std::runtime_error("cannot open loss function file: " + path);
    }

    std::string line;
    int line_no = 0;
    while (std::getline(in, line)) {
        ++line_no;
        auto tokens = split_tokens(line);
        if (tokens.empty()) {
            continue;
        }

        try {
            if (tokens[0] == "LUT") {
                if (tokens.size() != 3) {
                    throw std::runtime_error("LUT expects address value");
                }
                config.function_lut.at(parse_int_token(tokens[1])) = to_signed(parse_int_token(tokens[2]), 8);
            } else {
                if (tokens.size() != 2) {
                    throw std::runtime_error("expected: LUT <address> <value> or <address> <value>");
                }
                config.function_lut.at(parse_int_token(tokens[0])) = to_signed(parse_int_token(tokens[1]), 8);
            }
        } catch (const std::exception &e) {
            throw std::runtime_error(path + ":" + std::to_string(line_no) + ": " + e.what());
        }
    }
}

Config load_weights(const std::string &path) {
    Config config;
    std::ifstream in(path);
    if (!in) {
        throw std::runtime_error("cannot open weights file: " + path);
    }

    std::string line;
    int line_no = 0;
    while (std::getline(in, line)) {
        ++line_no;
        auto tokens = split_tokens(line);
        if (tokens.empty()) {
            continue;
        }
        const std::string &kind = tokens[0];
        try {
            if (kind == "N") {
                if (tokens.size() != 2) throw std::runtime_error("N expects 1 value");
                config.n = parse_int_token(tokens[1]);
            } else if (kind == "HLW") {
                if (tokens.size() != 4) throw std::runtime_error("HLW expects neuron feature value");
                config.hidden_weights.at(parse_int_token(tokens[1])).at(parse_int_token(tokens[2])) =
                    to_signed(parse_int_token(tokens[3]), 8);
            } else if (kind == "HLB") {
                if (tokens.size() != 3) throw std::runtime_error("HLB expects neuron value");
                config.hidden_biases.at(parse_int_token(tokens[1])) = to_signed(parse_int_token(tokens[2]), 8);
            } else if (kind == "OLW") {
                if (tokens.size() != 4) throw std::runtime_error("OLW expects neuron hidden_index value");
                config.output_weights.at(parse_int_token(tokens[1])).at(parse_int_token(tokens[2])) =
                    to_signed(parse_int_token(tokens[3]), 8);
            } else if (kind == "OLB") {
                if (tokens.size() != 3) throw std::runtime_error("OLB expects neuron value");
                config.output_biases.at(parse_int_token(tokens[1])) = to_signed(parse_int_token(tokens[2]), 8);
            } else {
                throw std::runtime_error("unknown directive: " + kind);
            }
        } catch (const std::exception &e) {
            throw std::runtime_error(path + ":" + std::to_string(line_no) + ": " + e.what());
        }
    }

    return config;
}

int load_threshold(const std::string &path) {
    std::ifstream in(path);
    if (!in) {
        throw std::runtime_error("cannot open threshold file: " + path);
    }
    std::string token;
    in >> token;
    if (token.empty()) {
        throw std::runtime_error("empty threshold file: " + path);
    }
    return to_signed(parse_int_token(token), 8);
}

std::vector<unsigned __int128> load_inputs(const std::string &path) {
    std::ifstream in(path);
    if (!in) {
        throw std::runtime_error("cannot open inputs file: " + path);
    }
    std::vector<unsigned __int128> inputs;
    std::string line;
    while (std::getline(in, line)) {
        auto tokens = split_tokens(line);
        if (!tokens.empty()) {
            inputs.push_back(parse_hex128(tokens[0]));
        }
    }
    if (inputs.empty()) {
        throw std::runtime_error("no input vectors in: " + path);
    }
    return inputs;
}

} // namespace

int main(int argc, char **argv) {
    if (argc != 5) {
        std::cerr << "Usage: anids_model <weights.txt> <threshold.txt> <loss_function.txt> <inputs.txt>\n";
        return 2;
    }

    try {
        Config config = load_weights(argv[1]);
        config.threshold = load_threshold(argv[2]);
        load_loss_function(argv[3], config);
        auto inputs = load_inputs(argv[4]);

        for (std::size_t i = 0; i < inputs.size(); ++i) {
            auto [loss, anomaly] = run_model(inputs[i], config);
            std::cout << "RESULT vector=" << i
                      << " loss=" << loss
                      << " anomaly=" << anomaly << "\n";
        }
    } catch (const std::exception &e) {
        std::cerr << "error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
