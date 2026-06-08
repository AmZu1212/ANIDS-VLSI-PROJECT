#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace std;

// ---------------------------------------------------------------------------
// Design constants mirrored from ANIDS/anids_defines.vh
// ---------------------------------------------------------------------------

constexpr int dmaVectorWidth = 128;
constexpr int hiddenNeuronCount = 64;
constexpr int outputNeuronCount = 128;
constexpr int q07Width = 8;
constexpr int hiddenAccWidth = 15;
constexpr int outputAccWidth = 15;
constexpr int lossAccWidth = 15;
constexpr int lutAddrWidth = 8;

// Full programmable state needed by the model. All numeric model parameters are
// stored as signed integer codes, not floating-point values. For Q0.7, a stored
// value of 64 represents +0.5, and -128 represents -1.0.
struct Config {
    int n = 128;
    int threshold = 0;
    array<array<int, dmaVectorWidth>, hiddenNeuronCount> hiddenWeights{};
    array<int, hiddenNeuronCount> hiddenBiases{};
    array<array<int, hiddenNeuronCount>, outputNeuronCount> outputWeights{};
    array<int, outputNeuronCount> outputBiases{};
    array<int, 1 << lutAddrWidth> functionLut{};
};

struct InputVector {
    uint64_t low = 0;
    uint64_t high = 0;
};

// ---------------------------------------------------------------------------
// Bit-accurate integer helpers
// ---------------------------------------------------------------------------

/**
 * @brief Return a mask with the requested number of low bits set.
 */
uint64_t MaskBits(int bits) {
    return bits >= 64 ? UINT64_MAX : ((uint64_t{1} << bits) - 1);
}

/**
 * @brief Interpret the low bits of a value as a two's-complement integer.
 */
int ToSigned(int64_t value, int bits) {
    const uint64_t raw = static_cast<uint64_t>(value) & MaskBits(bits);
    const uint64_t signBit = uint64_t{1} << (bits - 1);
    if (raw & signBit) {
        return static_cast<int>(static_cast<int64_t>(raw) - (int64_t{1} << bits));
    }
    return static_cast<int>(raw);
}

/**
 * @brief Wrap a value to a signed two's-complement width.
 */
int WrapSigned(int64_t value, int bits) {
    return ToSigned(value, bits);
}

/**
 * @brief Wrap a value to an unsigned bit width.
 */
int WrapUnsigned(int64_t value, int bits) {
    return static_cast<int>(static_cast<uint64_t>(value) & MaskBits(bits));
}

/**
 * @brief Model a SystemVerilog part-select followed by signed interpretation.
 */
int TruncSliceSigned(int value, int inBits, int msb, int width) {
    const uint64_t raw = static_cast<uint64_t>(value) & MaskBits(inBits);
    const int lsb = msb - width + 1;
    const uint64_t sliced = (raw >> lsb) & MaskBits(width);
    return ToSigned(static_cast<int64_t>(sliced), width);
}

/**
 * @brief Add two Q0.7 codes and saturate to the signed 8-bit range.
 */
int SaturatingAddQ07(int lhs, int rhs) {
    const int total = lhs + rhs;
    if (total > 127) {
        return 127;
    }
    if (total < -128) {
        return -128;
    }
    return total;
}

/**
 * @brief Apply ReLU to a signed Q0.7 code.
 */
int ReluQ07(int value) {
    return value > 0 ? value : 0;
}

// ---------------------------------------------------------------------------
// Input parsing helpers
// ---------------------------------------------------------------------------

/**
 * @brief Remove comments from one input-file line.
 */
string TrimComment(const string &line) {
    return line.substr(0, line.find('#'));
}

/**
 * @brief Split an input-file line into whitespace-separated tokens.
 */
vector<string> SplitTokens(const string &line) {
    istringstream iss(TrimComment(line));
    vector<string> tokens;
    string token;
    while (iss >> token) {
        tokens.push_back(token);
    }
    return tokens;
}

/**
 * @brief Parse a decimal or 0x-prefixed integer token.
 */
int ParseIntToken(const string &token) {
    size_t parsed = 0;
    const int base = (token.size() > 2 && token[0] == '0' &&
                     (token[1] == 'x' || token[1] == 'X')) ? 16 : 10;
    const int value = stoi(token, &parsed, base);
    if (parsed != token.size()) {
        throw runtime_error("bad integer token: " + token);
    }
    return value;
}

/**
 * @brief Parse a 128-bit input vector written as hexadecimal text.
 */
InputVector ParseHex128(const string &token) {
    string text = token;
    if (text.size() > 2 && text[0] == '0' && (text[1] == 'x' || text[1] == 'X')) {
        text = text.substr(2);
    }

    InputVector value;
    for (char c : text) {
        int digit = 0;
        if (c >= '0' && c <= '9') {
            digit = c - '0';
        } else if (c >= 'a' && c <= 'f') {
            digit = c - 'a' + 10;
        } else if (c >= 'A' && c <= 'F') {
            digit = c - 'A' + 10;
        } else {
            throw runtime_error("bad hex vector token: " + token);
        }
        value.high = (value.high << 4) | (value.low >> 60);
        value.low = (value.low << 4) | static_cast<uint64_t>(digit);
    }
    return value;
}

/**
 * @brief Read one bit from a 128-bit input vector.
 */
int GetInputBit(const InputVector &featureVector, int bitIndex) {
    if (bitIndex < 0 || bitIndex >= dmaVectorWidth) {
        return 0;
    }
    if (bitIndex < 64) {
        return static_cast<int>((featureVector.low >> bitIndex) & 1);
    }
    return static_cast<int>((featureVector.high >> (bitIndex - 64)) & 1);
}

// ---------------------------------------------------------------------------
// RTL-equivalent datapath helpers
// ---------------------------------------------------------------------------

/**
 * @brief Select the two feature bits consumed at a given pipeline counter.
 */
int InputLayerPair(const InputVector &featureVector, int counter) {
    if (counter < 0) {
        return 0;
    }
    const int bit0 = GetInputBit(featureVector, counter * 2);
    const int bit1 = GetInputBit(featureVector, counter * 2 + 1);
    return (bit1 << 1) | bit0;
}

/**
 * @brief Convert a signed Q0.7 output value into the LUT address used by RTL.
 */
int MemoryMapper(int inValue) {
    const int raw = WrapUnsigned(inValue, q07Width);
    const int sign = (raw >> 7) & 1;
    return ((~sign & 1) << 7) | (raw & 0x7f);
}

/**
 * @brief Compute one hidden-layer neuron's ReLU-clamped output.
 */
int HiddenNeuronResult(
    const InputVector &featureVector,
    const array<int, dmaVectorWidth> &weights,
    int bias,
    int n
) {
    int acc = 0;
    const int lastPairIndex = (n >> 1) - 1;

    for (int counter = 0; counter <= lastPairIndex; ++counter) {
        const int pair = InputLayerPair(featureVector, counter - 1);
        const int gated0 = (pair & 1) ? weights[counter * 2] : 0;
        const int gated1 = (pair & 2) ? weights[counter * 2 + 1] : 0;
        const int pairSum = WrapSigned(gated0 + gated1, 9);
        const int accNext = WrapSigned(acc + pairSum, hiddenAccWidth);

        if (counter == lastPairIndex) {
            const int trunc8 = TruncSliceSigned(accNext, hiddenAccWidth, hiddenAccWidth - 1, q07Width);
            return ReluQ07(SaturatingAddQ07(trunc8, bias));
        }

        acc = accNext;
    }

    throw runtime_error("invalid N: hidden loop did not run");
}

/**
 * @brief Compute one output-layer neuron's saturated Q0.7 output.
 */
int OutputNeuronResult(
    const array<int, hiddenNeuronCount> &hiddenResults,
    const array<int, hiddenNeuronCount> &weights,
    int bias,
    int n
) {
    int acc = 0;
    const int lastStepIndex = (n >> 1) - 1;

    for (int counter = 0; counter <= lastStepIndex; ++counter) {
        const int productFull = WrapSigned(hiddenResults[counter] * weights[counter], 16);
        const int productQ07 = TruncSliceSigned(productFull, 16, 14, 8);
        const int accNext = WrapSigned(acc + productQ07, outputAccWidth);

        if (counter == lastStepIndex) {
            const int trunc8 = TruncSliceSigned(accNext, outputAccWidth, outputAccWidth - 1, q07Width);
            return SaturatingAddQ07(trunc8, bias);
        }

        acc = accNext;
    }

    throw runtime_error("invalid N: output loop did not run");
}

/**
 * @brief Accumulate the RTL loss function for one input vector.
 */
int LossResult(
    const InputVector &featureVector,
    const array<int, outputNeuronCount> &outputResults,
    const Config &config
) {
    int acc = 0;
    const int lastPairIndex = (config.n >> 1) - 1;

    for (int counter = 0; counter <= lastPairIndex; ++counter) {
        const int pair = InputLayerPair(featureVector, counter - 1);
        const int x0 = pair & 1;
        const int x1 = (pair >> 1) & 1;

        const int r0 = outputResults[counter * 2];
        const int r1 = outputResults[counter * 2 + 1];
        const int f0 = config.functionLut[MemoryMapper(r0)];
        const int f1 = config.functionLut[MemoryMapper(r1)];

        const int pairSum = abs(x0 - f0) + abs(x1 - f1);
        const int accNext = WrapSigned(acc + pairSum, lossAccWidth);

        if (counter == lastPairIndex) {
            return TruncSliceSigned(accNext, lossAccWidth, lossAccWidth - 1, q07Width);
        }

        acc = accNext;
    }

    throw runtime_error("invalid N: loss loop did not run");
}

/**
 * @brief Run the full ANIDS C++ model for one 128-bit input vector.
 */
pair<int, int> RunModel(const InputVector &featureVector, const Config &config) {
    array<int, hiddenNeuronCount> hidden{};
    array<int, outputNeuronCount> output{};

    for (int i = 0; i < hiddenNeuronCount; ++i) {
        hidden[i] = HiddenNeuronResult(
            featureVector,
            config.hiddenWeights[i],
            config.hiddenBiases[i],
            config.n
        );
    }

    for (int i = 0; i < outputNeuronCount; ++i) {
        output[i] = OutputNeuronResult(
            hidden,
            config.outputWeights[i],
            config.outputBiases[i],
            config.n
        );
    }

    const int loss = LossResult(featureVector, output, config);
    const int anomaly = loss > config.threshold ? 1 : 0;
    return {loss, anomaly};
}

// ---------------------------------------------------------------------------
// Test-file loaders
// ---------------------------------------------------------------------------

/**
 * @brief Load N, hidden weights/biases, and output weights/biases.
 */
Config LoadWeights(const string &path) {
    Config config;
    ifstream in(path);
    if (!in) {
        throw runtime_error("cannot open weights file: " + path);
    }

    string line;
    int lineNo = 0;
    while (getline(in, line)) {
        ++lineNo;
        const auto tokens = SplitTokens(line);
        if (tokens.empty()) {
            continue;
        }

        const string &kind = tokens[0];
        try {
            if (kind == "N") {
                if (tokens.size() != 2) {
                    throw runtime_error("N expects 1 value");
                }
                config.n = ParseIntToken(tokens[1]);
            } else if (kind == "HLW") {
                if (tokens.size() != 4) {
                    throw runtime_error("HLW expects neuron feature value");
                }
                config.hiddenWeights.at(ParseIntToken(tokens[1])).at(ParseIntToken(tokens[2])) =
                    ToSigned(ParseIntToken(tokens[3]), q07Width);
            } else if (kind == "HLB") {
                if (tokens.size() != 3) {
                    throw runtime_error("HLB expects neuron value");
                }
                config.hiddenBiases.at(ParseIntToken(tokens[1])) =
                    ToSigned(ParseIntToken(tokens[2]), q07Width);
            } else if (kind == "OLW") {
                if (tokens.size() != 4) {
                    throw runtime_error("OLW expects neuron hidden_index value");
                }
                config.outputWeights.at(ParseIntToken(tokens[1])).at(ParseIntToken(tokens[2])) =
                    ToSigned(ParseIntToken(tokens[3]), q07Width);
            } else if (kind == "OLB") {
                if (tokens.size() != 3) {
                    throw runtime_error("OLB expects neuron value");
                }
                config.outputBiases.at(ParseIntToken(tokens[1])) =
                    ToSigned(ParseIntToken(tokens[2]), q07Width);
            } else {
                throw runtime_error("unknown directive: " + kind);
            }
        } catch (const exception &e) {
            throw runtime_error(path + ":" + to_string(lineNo) + ": " + e.what());
        }
    }

    return config;
}

/**
 * @brief Load LUT/function table entries from a loss_function.txt file.
 */
void LoadLossFunction(const string &path, Config &config) {
    ifstream in(path);
    if (!in) {
        throw runtime_error("cannot open loss function file: " + path);
    }

    string line;
    int lineNo = 0;
    while (getline(in, line)) {
        ++lineNo;
        const auto tokens = SplitTokens(line);
        if (tokens.empty()) {
            continue;
        }

        try {
            if (tokens[0] == "LUT") {
                if (tokens.size() != 3) {
                    throw runtime_error("LUT expects address value");
                }
                config.functionLut.at(ParseIntToken(tokens[1])) =
                    ToSigned(ParseIntToken(tokens[2]), q07Width);
            } else {
                if (tokens.size() != 2) {
                    throw runtime_error("expected: LUT <address> <value> or <address> <value>");
                }
                config.functionLut.at(ParseIntToken(tokens[0])) =
                    ToSigned(ParseIntToken(tokens[1]), q07Width);
            }
        } catch (const exception &e) {
            throw runtime_error(path + ":" + to_string(lineNo) + ": " + e.what());
        }
    }
}

/**
 * @brief Load the signed Q0.7 anomaly threshold.
 */
int LoadThreshold(const string &path) {
    ifstream in(path);
    if (!in) {
        throw runtime_error("cannot open threshold file: " + path);
    }

    string token;
    in >> token;
    if (token.empty()) {
        throw runtime_error("empty threshold file: " + path);
    }

    return ToSigned(ParseIntToken(token), q07Width);
}

/**
 * @brief Load one or more 128-bit DMA input vectors.
 */
vector<InputVector> LoadInputs(const string &path) {
    ifstream in(path);
    if (!in) {
        throw runtime_error("cannot open inputs file: " + path);
    }

    vector<InputVector> inputs;
    string line;
    while (getline(in, line)) {
        const auto tokens = SplitTokens(line);
        if (!tokens.empty()) {
            inputs.push_back(ParseHex128(tokens[0]));
        }
    }

    if (inputs.empty()) {
        throw runtime_error("no input vectors in: " + path);
    }

    return inputs;
}

int main(int argc, char **argv) {
    if (argc != 5) {
        cerr << "Usage: anids_model <weights.txt> <threshold.txt> <loss_function.txt> <inputs.txt>\n";
        return 2;
    }

    try {
        Config config = LoadWeights(argv[1]);
        config.threshold = LoadThreshold(argv[2]);
        LoadLossFunction(argv[3], config);
        const auto inputs = LoadInputs(argv[4]);

        for (size_t i = 0; i < inputs.size(); ++i) {
            const auto [loss, anomaly] = RunModel(inputs[i], config);
            cout << "RESULT vector=" << i
                 << " loss=" << loss
                 << " anomaly=" << anomaly << "\n";
        }
    } catch (const exception &e) {
        cerr << "error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
