module top (
	output wire i2s_sclk,
	output wire i2s_din,
	input  wire i2s_dout,
	output wire i2s_lrclk,
	inout  wire scl_led,
	inout  wire sda_btn,
	input  wire sys_clk
);

	// Signals
	// -------


	// I2C
	wire i2c_done;

	// Reset
	reg [7:0] rst_cnt = 0;
	wire      rst_i;
	wire      rst;


	// I2S
	// ---

	reg [16:0] sine [0:1023];

	initial
		$readmemh("rtl/sine.hex", sine);

	reg  [4:0] i2s_data_timer = 0;
	reg [15:0] i2s_data = 0;
	reg  [9:0] i2s_data_index = 0;

	always @(posedge sys_clk) begin
		if (i2s_data_timer == 23) begin
			i2s_data <= sine[i2s_data_index];
			i2s_data_index <= i2s_data_index + 1;
			i2s_data_timer <= 0;
		end else begin
			i2s_data_timer <= i2s_data_timer + 1;
		end
	end

	i2s_master i2s(
		.CLK (sys_clk),
		.SMP (i2s_data),
		.SCK (),
		.BCK (i2s_sclk),
		.DIN (i2s_din),
		.LCK (i2s_lrclk)
	);


	// I2C init
	// --------

	i2c_state_machine ism (
		.scl_led (scl_led),
		.sda_btn (sda_btn),
		.btn     (),
		.led     (1'b0),
		.done    (i2c_done),
		.clk     (sys_clk),
		.rst     (rst)
	);

	// Reset
	// -----

	always @(posedge sys_clk)
		if (~rst_cnt[7])
			rst_cnt <= rst_cnt + 1;

	assign rst_i = ~rst_cnt[7];

	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(rst_i),
		.GLOBAL_BUFFER_OUTPUT(rst)
	);

endmodule
