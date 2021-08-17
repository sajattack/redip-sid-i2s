module top (
    input sys_clk,
    inout scl_led,
    inout sda_btn,
    output i2s_sclk,
    output i2s_din,
    output i2s_dout,
    output i2s_lrclk,
);

wire btn;
reg go;
wire led;
wire rdy;
wire rst_i;
wire done;

reg [3:0] rst_cnt = 0;

i2c_state_machine ism (
    .scl_led(scl_led),
    .sda_btn(sda_btn),
    .btn(btn),
    .led(1'b0),
    .go(go),
    .rdy(rdy),
    .done(done),
    .clk(sys_clk),
    .rst(rst_i)
);

    // Logic reset generation
	always @(posedge sys_clk)
		if (~rst_cnt[3])
			rst_cnt <= rst_cnt + 1;

	assign rst_i = ~rst_cnt[3];

    wire rst_timer;
    reg [4:0] timer = 0;

    // go signal generation
    always @(posedge sys_clk) begin
        if (rst_timer) begin
            go <= 1;
	        timer <= 0;
        end else if (timer[4] == 1'b1) begin
	        go <= 0;
	        timer <= 0;
	    end else 
	        timer <= timer + 1;
	end

    assign rst_timer = rdy;

reg [16:0] sine [1023:0];

initial begin
    $readmemh("sine.hex", sine);
end

reg [4:0] i2s_data_timer = 0;
reg [15:0] i2s_data = 0;
reg [9:0] i2s_data_index = 0;

always @(posedge sys_clk) begin
    if (timer == 23) begin
        i2s_data <= sine[i2s_data_index];
        i2s_data_index <= i2s_data_index + 1;
        i2s_data_timer <= 0;
    end else begin
        i2s_data_timer <= i2s_data_timer + 1;
    end
end

i2s_master i2s(
    .CLK(sys_clk),
    .SMP(i2s_data),
    .SCK(i2s_sclk),
    .BCK(),
    .DIN(i2s_din),
    .LCK(i2s_lrclk)
);

endmodule
