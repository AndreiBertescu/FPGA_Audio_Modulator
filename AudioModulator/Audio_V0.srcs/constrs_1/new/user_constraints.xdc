# Clock Signal
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} [get_ports clk_i]
#create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk_i]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins bclk_10x_generator/inst/mmcm_adv_inst/CLKOUT0]] -group [get_clocks [list [get_clocks -of_objects [get_pins eth_txck_generator/inst/mmcm_adv_inst/CLKOUT0]] [get_clocks -of_objects [get_pins mclk_generator/inst/mmcm_adv_inst/CLKFBOUT]]]]

# Buttons
set_property -dict {PACKAGE_PIN B22 IOSTANDARD LVCMOS12} [get_ports btnc]
#set_property -dict { PACKAGE_PIN D22 IOSTANDARD LVCMOS12 } [get_ports { btnd }]; #IO_L22N_T3_16 Sch=btnd
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS12} [get_ports btnl]
#set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS12 } [get_ports { btnr }]; #IO_L6P_T0_16 Sch=btnr
#set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS12 } [get_ports { btnu }]; #IO_0_16 Sch=btnu
#set_property -dict { PACKAGE_PIN G4  IOSTANDARD LVCMOS15 } [get_ports { cpu_resetn }]; #IO_L12N_T1_MRCC_35 Sch=cpu_resetn

# Switches
#set_property -dict { PACKAGE_PIN E22  IOSTANDARD LVCMOS12 } [get_ports { sw }]; #IO_L22P_T3_16 Sch=sw[0]
#set_property -dict { PACKAGE_PIN F21  IOSTANDARD LVCMOS12 } [get_ports { sw[1] }]; #IO_25_16 Sch=sw[1]
#set_property -dict { PACKAGE_PIN G21  IOSTANDARD LVCMOS12 } [get_ports { sw[2] }]; #IO_L24P_T3_16 Sch=sw[2]
#set_property -dict { PACKAGE_PIN G22  IOSTANDARD LVCMOS12 } [get_ports { sw[3] }]; #IO_L24N_T3_16 Sch=sw[3]
#set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS12 } [get_ports { sw[4] }]; #IO_L6P_T0_15 Sch=sw[4]
#set_property -dict { PACKAGE_PIN J16  IOSTANDARD LVCMOS12 } [get_ports { sw[5] }]; #IO_0_15 Sch=sw[5]
#set_property -dict { PACKAGE_PIN K13  IOSTANDARD LVCMOS12 } [get_ports { sw[6] }]; #IO_L19P_T3_A22_15 Sch=sw[6]
#set_property -dict { PACKAGE_PIN M17  IOSTANDARD LVCMOS12 } [get_ports { sw[7] }]; #IO_25_15 Sch=sw[7]

# I2C
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports scl]
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports sda]

# Audio Codec
set_property -dict {PACKAGE_PIN T4 IOSTANDARD LVCMOS33} [get_ports ac_adc_sdata]
set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33} [get_ports ac_bclk]
set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS33} [get_ports ac_dac_sdata]
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports ac_lrclk]
set_property -dict {PACKAGE_PIN U6 IOSTANDARD LVCMOS33} [get_ports ac_mclk]

# Ethernet
set_property -dict {PACKAGE_PIN AA16 IOSTANDARD LVCMOS25} [get_ports eth_mdc]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS25} [get_ports eth_mdio]

#set_property -dict { PACKAGE_PIN Y14   IOSTANDARD LVCMOS25 } [get_ports { eth_int_b }]; #IO_L6N_T0_VREF_13 Sch=eth_int_b
#set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS25 } [get_ports { eth_pme_b }]; #IO_L6P_T0_13 Sch=eth_pme_b
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports eth_rst_b]

set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS25} [get_ports eth_rxck]
create_clock -period 40.000 -name eth_rxck [get_ports eth_rxck]
set_property -dict {PACKAGE_PIN W10 IOSTANDARD LVCMOS25} [get_ports eth_rxctl]
set_property -dict {PACKAGE_PIN AB16 IOSTANDARD LVCMOS25} [get_ports {eth_rxd[0]}]
set_property -dict {PACKAGE_PIN AA15 IOSTANDARD LVCMOS25} [get_ports {eth_rxd[1]}]
set_property -dict {PACKAGE_PIN AB15 IOSTANDARD LVCMOS25} [get_ports {eth_rxd[2]}]
set_property -dict {PACKAGE_PIN AB11 IOSTANDARD LVCMOS25} [get_ports {eth_rxd[3]}]

set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVCMOS25} [get_ports eth_txck]
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS25} [get_ports eth_txctl]
set_property -dict {PACKAGE_PIN Y12 IOSTANDARD LVCMOS25} [get_ports {eth_txd[0]}]
set_property -dict {PACKAGE_PIN W12 IOSTANDARD LVCMOS25} [get_ports {eth_txd[1]}]
set_property -dict {PACKAGE_PIN W11 IOSTANDARD LVCMOS25} [get_ports {eth_txd[2]}]
set_property -dict {PACKAGE_PIN Y11 IOSTANDARD LVCMOS25} [get_ports {eth_txd[3]}]


set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 12 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
