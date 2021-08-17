`default_nettype none

module top (
	// I2S
	output wire i2s_din,
	input  wire i2s_dout,
	input  wire i2s_sclk,
	input  wire i2s_lrclk,

	// I2C (shared)
	inout  wire scl_led,
	inout  wire sda_btn,

	// USB
	inout  wire usb_dp,
	inout  wire usb_dn,
	output wire usb_pu,

	// Clock
	input  wire sys_clk
);

	// Signals
	// -------

	wire led;

	// Clocks / Reset
	reg [15:0] rst_cnt = 0;
	wire      rst_i;
	wire      rst;

	wire      clk_usb;
	wire      rst_usb;


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



	reg [1:0] i2s_sclk_sync;
	reg       i2s_sclk_rise;
	reg       i2s_sclk_fall;

	reg [1:0] i2s_lrclk_sync;
	reg       i2s_lrclk_rise;
	reg       i2s_lrclk_fall;

	always @(posedge sys_clk)
	begin
		i2s_sclk_sync  <= { i2s_sclk_sync[0],  i2s_sclk };
		i2s_sclk_rise  <=   i2s_sclk_sync[0] & ~i2s_sclk_sync[1];
		i2s_sclk_fall  <=  ~i2s_sclk_sync[0] &  i2s_sclk_sync[1];

		i2s_lrclk_sync <= { i2s_lrclk_sync[0], i2s_lrclk };
		i2s_lrclk_rise <=   i2s_lrclk_sync[0] & ~i2s_lrclk_sync[1];
		i2s_lrclk_fall <=  ~i2s_lrclk_sync[0] &  i2s_lrclk_sync[1];
	end

	reg w;
	reg [15:0] data;

	always @(posedge sys_clk)
	begin
		if (i2s_sclk_rise) begin
			// Reload on word select change
			if (i2s_lrclk_sync[1] ^ w)
				data <= i2s_data;

			// Save word select
			w <= i2s_lrclk_sync[1];
		end else if (i2s_sclk_fall) begin
			// Shift on falling edge
			data <= { data[14:0], 1'b0 };
		end
	end

	assign i2s_din = data[15];


	reg [20:0] cnt = 0;
	always @(posedge sys_clk)
		cnt <= cnt + i2s_sclk_rise;
	
	assign led = cnt[20];


//	i2s_master i2s(
//		.CLK (sys_clk),
//		.SMP (i2s_data),
//		.SCK (),
//		.BCK (i2s_sclk),
//		.DIN (i2s_din),
//		.LCK (i2s_lrclk)
//	);


	// I2C init
	// --------

	i2c_state_machine ism (
		.scl_led (scl_led),
		.sda_btn (sda_btn),
		.btn     (),
		.led     (led),
		.done    (),
		.clk     (sys_clk),
		.rst     (rst)
	);


	// muACM
	// -----

	// Local signals
	wire bootloader;
	reg boot = 1'b0;

	// Instance
	muacm acm_I (
		.usb_dp        (usb_dp),
		.usb_dn        (usb_dn),
		.usb_pu        (usb_pu),
		.in_data       (8'h00),
		.in_last       (),
		.in_valid      (1'b0),
		.in_ready      (),
		.in_flush_now  (1'b0),
		.in_flush_time (1'b1),
		.out_data      (),
		.out_last      (),
		.out_valid     (),
		.out_ready     (1'b1),
		.bootloader    (bootloader),
		.clk           (clk_usb),
		.rst           (rst_usb)
	);
	
	// Warmboot
	always @(posedge clk_usb)
		boot <= boot | bootloader;

	SB_WARMBOOT warmboot (
		.BOOT (boot),
		.S0   (1'b1),
		.S1   (1'b0)
	);


	// CRG
	// ---

	// Local reset
	always @(posedge sys_clk)
		if (~rst_cnt[15])
			rst_cnt <= rst_cnt + 1;

	assign rst_i = ~rst_cnt[15];

	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(rst_i),
		.GLOBAL_BUFFER_OUTPUT(rst)
	);

	// Use HF OSC to generate USB clock
	sysmgr_hfosc sysmgr_I (
		.rst_in (rst),
		.clk_out(clk_usb),
		.rst_out(rst_usb)
	);

endmodule
