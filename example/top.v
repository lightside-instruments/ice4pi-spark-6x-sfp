module top(input clk,

           //i2c slave interface
           inout i2c_sda, input i2c_scl,

           //sfp and leds x6
           output reg [5:0] led_blue,
           output reg [5:0] led_green,
           input [5:0] sfp_tx_disable,
           output [5:0] sfp_scl,
           output [5:0] sfp_rs0,
           output [5:0] sfp_rs1,
           inout [5:0] sfp_sda,
           input [5:0] sfp_mod_abs,
           input [5:0] sfp_rx_los,
           input [5:0] sfp_tx_fault);

   reg rst = 1'b1;
   reg [3:0] dummy;
   reg [7:0] pmod;
   wire [11:0] rot;
   wire [7:0] led_blue_i2c;
   wire [7:0] led_green_i2c;
   wire [7:0] mux_select_i2c;
   reg [7:0] mux_select= 4'd3;
   reg [27:0] startup_cnt = 28'd0;
   reg [27:0] counter = 28'd0;
   reg [27:0] i2c_state_counter = 28'd100000;
   reg [3:0] i2c_state = 4'd3;
   wire i2c_sda_out;
   wire i2c_sda_in;
   wire [5:0] sfp_sda_in;
   wire [5:0] sfp_sda_out;
   reg local_sda_in;
   wire local_sda_out;
   reg sfp_sda_sel_in = 1;
   reg sfp_sda_sel_out = 1;

//assign sda = (sdaOut == 1'b0) ? 1'b0 : 1'bz;
//assign sdaIn = sda;

SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b 1)
) pi_side_io (
    .PACKAGE_PIN(i2c_sda),
    .OUTPUT_ENABLE(~i2c_sda_out),
    .D_OUT_0(i2c_sda_out),
    .D_IN_0(i2c_sda_in)
);

genvar i;
generate
  for (i = 0; i <= 6 - 1; i = i + 1)
    begin: GEN
      SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b 1)
) sfp_side_io (
    .PACKAGE_PIN(sfp_sda[i]),
    .OUTPUT_ENABLE(~sfp_sda_out[i]),
    .D_OUT_0(sfp_sda_out[i]),
    .D_IN_0(sfp_sda_in[i])
);
    end
endgenerate

//SB_IO #(
//    .PIN_TYPE(6'b 1010_01),
//    .PULLUP(1'b 1)
//) sfp_side_io (
//    .PACKAGE_PIN(sfp_sda[3]),
//    .OUTPUT_ENABLE(~sfp_sda_out[3]),
//    .D_OUT_0(sfp_sda_out[3]),
//    .D_IN_0(sfp_sda_in[3])
//);


   rot rot0(.clk(clk), .rot(rot));

//   assign local_sda_in = 1'b1;

   i2cSlaveTop i2c0(.clk(clk), .rst(rst), .sdaIn(local_sda_out), .sdaOut(local_sda_in), .scl(i2c_scl),
                    //output regs 0-3
                    .myReg0(led_blue_i2c),
                    .myReg1(led_green_i2c),
                    .myReg2(mux_select_i2c),
                    //input regs 4-7
                    .myReg4({sfp_mod_abs, 2'b00}),
                    .myReg5({sfp_rx_los, 2'b00}),
                    .myReg6({sfp_tx_fault, 2'b00})
);

   always @ (posedge clk)
   begin
      if(startup_cnt < 28'd144000000)
        begin
            rst <= 1'b1;
            startup_cnt <= startup_cnt + 1;
            {led_green, led_blue} <= rot;
        end
      else
        begin
            rst <= 1'b0;
//            led_green <= led_green_i2c[5:0];
//            led_blue <= led_blue_i2c[5:0];
            led_blue <= sfp_mod_abs;
            led_green <= sfp_rx_los;
        end
   end

   always @ (posedge clk)
     begin
       if(mux_select_i2c<6)
         begin
           mux_select <=mux_select_i2c;
         end
       else
         begin
           mux_select <=3;
         end
     end

   always @ (posedge clk)
     begin
       sfp_sda_out[mux_select] <= sfp_sda_sel_out;
       sfp_sda_sel_in <= sfp_sda_in[mux_select];
       sfp_scl[mux_select] <= i2c_scl;
     end

   always @ (posedge clk)
     begin
       counter <= counter + 1;
       if(i2c_state_counter>0)
         begin
           i2c_state_counter <= i2c_state_counter-1;
         end
       else if(i2c_state == 0)
         begin
           if(i2c_sda_in==0)
             begin
               i2c_state <= 1;
               sfp_sda_sel_out <=0;
               local_sda_out <=0;
               i2c_state_counter <=10;
             end
           else if(sfp_sda_sel_in==0)
             begin
               i2c_state <= 2;
               i2c_sda_out <=0;
               local_sda_out <=0;
               i2c_state_counter <=10;
             end
           else if(local_sda_in==0)
             begin
               i2c_state <= 3;
               i2c_sda_out <=0;
               sfp_sda_sel_out <=0;
               i2c_state_counter <=10;
             end
           else
             begin
               sfp_sda_sel_out <=1;
               i2c_sda_out <=1;
               local_sda_out <=1;
             end
         end
       else if(i2c_state == 1)
         begin
          if(i2c_sda_in==1)
            begin
              i2c_state <= 0;
              i2c_state_counter <=10;
              sfp_sda_sel_out <= 1;
              local_sda_out <= 1;
            end
         end
       else if(i2c_state == 2)
         begin
          if(sfp_sda_sel_in==1)
            begin
              i2c_state <= 0;
              i2c_state_counter <=10;
              i2c_sda_out <= 1;
              local_sda_out <= 1;
            end
         end
       else if(i2c_state == 3)
         begin
           if(local_sda_in==1)
             begin
               i2c_state <= 0;
               i2c_state_counter <=10;
               i2c_sda_out <=1;
               sfp_sda_sel_out <=1;
             end
         end
     end
endmodule // top
