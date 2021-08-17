module i2s_master(
      input CLK,          // 24Mhz input clock
      input [15:0] SMP,   // input sample data (twos-compliment format)
      output SCK,
      output BCK,
      output DIN,
      output LCK          // ~48Khz
);

  reg [ 8:0] counter;
  reg [15:0] shift;
  reg out;

  assign SCK = CLK;           // (sck)           24 Mhz
  assign BCK = counter[2];    // (sck / 8)        3 Mhz
  assign LCK = counter[8];    // (sck / 512)  46875 Hz
  assign DIN = shift[15];     // (sck / 8)        3 Mhz

  initial begin
    counter <= 'd0;
    shift <= 'd0;
  end

  always @(posedge CLK) begin
    // on the falling edge of BCK
    if (counter[2:0] == 0) begin
      if (counter[7:3] == 1) begin
        // re-sample at on BCK after LRCK edge
        shift <= SMP;
      end else begin
        // shift out data
        shift <= { shift[14:0], 1'b0 };
      end
    end
    counter <= counter + 'd1;
  end
endmodule
