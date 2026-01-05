module anids_regfile (
	// APB Interface
    input  wire                   		PCLK,
    input  wire                   		PRESETn,
    input  wire                   		PSEL,
    input  wire                   		PENABLE,
    input  wire                   		PWRITE,
    input  wire [`APB_ADDR_WIDTH - 1:0]	PADDR,
    input  wire [`APB_DATA_WIDTH - 1:0] PWDATA,
    output reg  [`APB_DATA_WIDTH - 1:0] PRDATA,
    output wire                   		PREADY,
    output wire                   		PSLVERR
);

    // Always-ready, no error
    assign PREADY  = 1'b1; // *** if you want wait states, it is important that you modify Pready logic.
    assign PSLVERR = 1'b0;

    wire apb_wr = PSEL && PENABLE && PWRITE;
    wire apb_rd = PSEL && !PWRITE; // PRDATA driven combinationally below

    // ----------------------------
    // Control registers (8-bit each)
    // ----------------------------
    reg [`APB_DATA_WIDTH - 1:0] start_reg;
    reg [`APB_DATA_WIDTH - 1:0] n_reg;
    reg [`APB_DATA_WIDTH - 1:0] threshold_reg;
    reg [`APB_DATA_WIDTH - 1:0] result_reg;
    reg [`APB_DATA_WIDTH - 1:0] ctrl1_reg, ctrl2_reg, ctrl3_reg, ctrl4_reg;


	// ----------------------------
    // Large byte-addressed memories
    // ----------------------------
		// Hidden Layer
	reg [`APB_DATA_WIDTH - 1:0] HL_weights 	[0:`HL_WEIGHT_BYTES - 1];
	reg [`APB_DATA_WIDTH - 1:0] HL_bias 	[0:`HL_BIAS_BYTES - 1];
		// Output Layer
	reg [`APB_DATA_WIDTH - 1:0] OL_weights 	[0:`OL_WEIGHT_BYTES - 1];
	reg [`APB_DATA_WIDTH - 1:0] OL_bias 	[0:`OL_BIAS_BYTES - 1];


	//=======================================================================

    // ----------------------------
    // Write path
    // ----------------------------
    integer i;
    always @(posedge PCLK) begin
        if (!PRESETn) begin
            start_reg     <= #1 {`APB_DATA_WIDTH{1'b0}};
            n_reg         <= #1 {`APB_DATA_WIDTH{1'b0}};
            threshold_reg <= #1 {`APB_DATA_WIDTH{1'b0}};
            result_reg    <= #1 {`APB_DATA_WIDTH{1'b0}};
            ctrl1_reg     <= #1 {`APB_DATA_WIDTH{1'b0}};
            ctrl2_reg     <= #1 {`APB_DATA_WIDTH{1'b0}};
            ctrl3_reg     <= #1 {`APB_DATA_WIDTH{1'b0}};
            ctrl4_reg     <= #1 {`APB_DATA_WIDTH{1'b0}};

            // Optional: clear memories (can be expensive in synthesis; remove if not needed)
			for (i = 0; i < `HL_WEIGHT_BYTES; i = i + 1) HL_weights[i] <= #1 {`APB_DATA_WIDTH{1'b0}};
			for (i = 0; i < `HL_BIAS_BYTES;   i = i + 1) HL_bias[i]    <= #1 {`APB_DATA_WIDTH{1'b0}};
			for (i = 0; i < `OL_WEIGHT_BYTES; i = i + 1) OL_weights[i] <= #1 {`APB_DATA_WIDTH{1'b0}};
			for (i = 0; i < `OL_BIAS_BYTES;   i = i + 1) OL_bias[i]    <= #1 {`APB_DATA_WIDTH{1'b0}};


        end else if (apb_wr) begin
            // Control regs
            if 		(PADDR == `START_REG)       start_reg     <= #1 PWDATA;
            else if (PADDR == `N_REG)      		n_reg         <= #1 PWDATA;
            else if (PADDR == `THRESHOLD_REG) 	threshold_reg <= #1 PWDATA;
			else if (PADDR == `RESULT_REG) 		result_reg    <= #1 PWDATA;
            else if (PADDR == `CTRL1_REG)  		ctrl1_reg     <= #1 PWDATA;
            else if (PADDR == `CTRL2_REG)  		ctrl2_reg     <= #1 PWDATA;
            else if (PADDR == `CTRL3_REG)  		ctrl3_reg     <= #1 PWDATA;
            else if (PADDR == `CTRL4_REG)  		ctrl4_reg     <= #1 PWDATA;

			// Hidden weights window: [W_BASE .. W_BASE + 8191]
			else if ((PADDR >= `HL_WEIGHT_BASE) && (PADDR <= `HL_WEIGHT_END)) begin
				HL_weights[PADDR - `HL_WEIGHT_BASE] <= #1 PWDATA;
			end
			// Hidden bias window: [HL_BIAS_BASE .. HL_BIAS_BASE + 63]
			else if ((PADDR >= `HL_BIAS_BASE) && (PADDR <= `HL_BIAS_END)) begin
				HL_bias[PADDR - `HL_BIAS_BASE] <= #1 PWDATA;
			end
			// Output weights window: [OL_WEIGHT_BASE .. OL_WEIGHT_BASE + 8191]
			else if ((PADDR >= `OL_WEIGHT_BASE) && (PADDR <= `OL_WEIGHT_END)) begin
				OL_weights[PADDR - `OL_WEIGHT_BASE] <= #1 PWDATA;
			end
			// Output bias window: [OL_BIAS_BASE .. OL_BIAS_BASE + 127]
			else if ((PADDR >= `OL_BIAS_BASE) && (PADDR <= `OL_BIAS_END)) begin
				OL_bias[PADDR - `OL_BIAS_BASE] <= #1 PWDATA;
			end
        end
    end

    // ----------------------------
    // Read path (combinational)
    // ----------------------------
    always @(*) begin
        PRDATA = {`APB_DATA_WIDTH{1'b0}};

        // Control regs
		if 		(PADDR == `START_REG)     PRDATA = start_reg;
        else if (PADDR == `N_REG)         PRDATA = n_reg;
        else if (PADDR == `THRESHOLD_REG) PRDATA = threshold_reg;
        else if (PADDR == `RESULT_REG)    PRDATA = result_reg;
        else if (PADDR == `CTRL1_REG)     PRDATA = ctrl1_reg;
        else if (PADDR == `CTRL2_REG)     PRDATA = ctrl2_reg;
        else if (PADDR == `CTRL3_REG)     PRDATA = ctrl3_reg;
        else if (PADDR == `CTRL4_REG)     PRDATA = ctrl4_reg;

        // Memories
        else if ((PADDR >= `HL_WEIGHT_BASE) && (PADDR <= `HL_WEIGHT_END)) begin
			HL_weights[PADDR - `HL_WEIGHT_BASE] <= #1 PWDATA;
		end
		else if ((PADDR >= `HL_BIAS_BASE) && (PADDR <= `HL_BIAS_END)) begin
			HL_bias[PADDR - `HL_BIAS_BASE] <= #1 PWDATA;
		end
		else if ((PADDR >= `OL_WEIGHT_BASE) && (PADDR <= `OL_WEIGHT_END)) begin
			OL_weights[PADDR - `OL_WEIGHT_BASE] <= #1 PWDATA;
		end
		else if ((PADDR >= `OL_BIAS_BASE) && (PADDR <= `OL_BIAS_END)) begin
			OL_bias[PADDR - `OL_BIAS_BASE] <= #1 PWDATA;
		end
    end
endmodule
