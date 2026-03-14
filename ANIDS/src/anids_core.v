// ANIDS Core Datapath
`include "anids_defines.vh"

module anids_core (
		clk,
		resetN,
		regfile,
		mfu_features,
		mfu_updated,
		fetch_next_vector,
		done,
		outlier_pulse,
		loss_result
	);

	parameter REG_WIDTH            = `APB_DATA_WIDTH;
	parameter REG_COUNT            = `REG_COUNT;
	parameter FEATURE_WIDTH        = `PIPELINE_VECTOR_WIDTH;
	parameter FEATURE_PAIR_WIDTH   = `INPUT_LAYER_PAIR_WIDTH;
	parameter COUNTER_WIDTH        = `PIPELINE_COUNTER_WIDTH;
	parameter HIDDEN_COUNT         = 64;
	parameter OUTPUT_COUNT         = 128;
	parameter HIDDEN_RESULT_WIDTH  = `HL_RESULT_WIDTH;
	parameter OUTPUT_RESULT_WIDTH  = `OL_RESULT_WIDTH;
	parameter LOSS_RESULT_WIDTH    = `LF_OUT_WIDTH;
	parameter LUT_ADDR_WIDTH       = `LUT_ADDR_WIDTH;
	parameter LUT_DATA_WIDTH       = `LUT_DATA_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	// system signals
	input  wire                                     clk;
	input  wire                                     resetN;

	// internal configuration register bus from the APB regfile
	input  wire signed [REG_WIDTH-1:0]             regfile [0:REG_COUNT-1];

	// memory fetch unit handshake and fetched feature vector
	input  wire [FEATURE_WIDTH-1:0]                 mfu_features;
	input  wire                                     mfu_updated;
	output wire                                     fetch_next_vector;

	// core completion and anomaly outputs
	output wire                                     done;
	output wire                                     outlier_pulse;
	output wire signed [LOSS_RESULT_WIDTH-1:0]      loss_result;

	// ----------------------------------------------------------------------
	//                  		Register-Control Signals
	// ----------------------------------------------------------------------
	wire                               start_core     = regfile[`START_REG][0];
	wire [REG_WIDTH-1:0]               vector_length  = regfile[`N_REG];
	wire signed [REG_WIDTH-1:0]        threshold      = regfile[`THRESHOLD_REG];
	wire [LUT_ADDR_WIDTH-1:0]          lut_wr_addr    = regfile[`LUT_ADDR][LUT_ADDR_WIDTH-1:0];
	wire [LUT_DATA_WIDTH-1:0]          lut_wr_data    = regfile[`LUT_DATA][LUT_DATA_WIDTH-1:0];
	wire                               lut_wr_en      = regfile[`LUT_CTRL][0];

	// ----------------------------------------------------------------------
	//                  		Pipeline Control
	// ----------------------------------------------------------------------
	wire                               hidden_enable;
	wire                               output_enable;
	wire                               loss_enable;
	wire [FEATURE_WIDTH-1:0]           next_vector;
	wire [FEATURE_WIDTH-1:0]           validate_vector;
	wire [COUNTER_WIDTH-1:0]           counter;

	pipeline_manager pipeline_manager_inst (
		.clk             (clk),
		.resetN          (resetN),
		.start           (start_core),
		.N               (vector_length),
		.mfu_features    (mfu_features),
		.mfu_updated     (mfu_updated),
		.fetch           (fetch_next_vector),
		.enable          (hidden_enable),
		.output_enable   (output_enable),
		.loss_enable     (loss_enable),
		.next_vector     (next_vector),
		.validate_vector (validate_vector),
		.counter         (counter)
	);

	// ----------------------------------------------------------------------
	//                  		Input Selection
	// ----------------------------------------------------------------------
	wire [FEATURE_PAIR_WIDTH-1:0] current_features;
	wire [FEATURE_PAIR_WIDTH-1:0] validate_features;

	input_layer input_layer_inst (
		.clk              (clk),
		.resetN           (resetN),
		.enable           (hidden_enable),
		.features         (next_vector),
		.counter          (counter),
		.current_features (current_features)
	);

	input_layer validate_input_layer_inst (
		.clk              (clk),
		.resetN           (resetN),
		.enable           (loss_enable),
		.features         (validate_vector),
		.counter          (counter),
		.current_features (validate_features)
	);

	// ----------------------------------------------------------------------
	//                  		Hidden Layer
	// ----------------------------------------------------------------------
	wire signed [HIDDEN_RESULT_WIDTH-1:0] hidden_results [0:HIDDEN_COUNT-1];
	wire                                  hidden_ready   [0:HIDDEN_COUNT-1];

	hidden_layer hidden_layer_inst (
		.clk      (clk),
		.resetN   (resetN),
		.enable   (hidden_enable),
		.N        (vector_length),
		.features (current_features),
		.counter  (counter),
		.regfile  (regfile),
		.results  (hidden_results),
		.ready    (hidden_ready)
	);

	// ----------------------------------------------------------------------
	//                  		Output Layer
	// ----------------------------------------------------------------------
	wire signed [OUTPUT_RESULT_WIDTH-1:0] output_results [0:OUTPUT_COUNT-1];
	wire                                  output_ready   [0:OUTPUT_COUNT-1];

	output_layer output_layer_inst (
		.clk            (clk),
		.resetN         (resetN),
		.enable         (output_enable),
		.N              (vector_length),
		.hidden_results (hidden_results),
		.counter        (counter),
		.regfile        (regfile),
		.results        (output_results),
		.ready          (output_ready)
	);

	// ----------------------------------------------------------------------
	//                  		Loss Function + Outlier Detection
	// ----------------------------------------------------------------------
	wire signed [LOSS_RESULT_WIDTH-1:0] loss_result_int;
	wire                                loss_ready;
	wire signed [OUTPUT_RESULT_WIDTH-1:0] loss_result_0 = output_results[counter * 2];
	wire signed [OUTPUT_RESULT_WIDTH-1:0] loss_result_1 = output_results[(counter * 2) + 1'b1];
	wire                                outlier_ready;

	loss_function loss_function_inst (
		.clk         (clk),
		.resetN      (resetN),
		.enable      (loss_enable),
		.N           (vector_length),
		.counter     (counter),
		.lut_wr_addr (lut_wr_addr),
		.lut_wr_data (lut_wr_data),
		.lut_wr_en   (lut_wr_en),
		.x_in        (validate_features),
		.result_0    (loss_result_0),
		.result_1    (loss_result_1),
		.result      (loss_result_int),
		.ready       (loss_ready)
	);

	outlier_detector outlier_detector_inst (
		.clk           (clk),
		.resetN        (resetN),
		.ready         (loss_ready),
		.data_in       (loss_result_int),
		.threshold     (threshold),
		.outlier_pulse (outlier_pulse),
		.output_ready  (outlier_ready)
	);

	assign loss_result = loss_result_int;
	assign done        = outlier_ready;

endmodule
