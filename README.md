InHouse-RDMA
============
Prototype that captures ethernet frames on virtex5 netfpga-10g

Since the pcie endpoint signals not ready from time to time, it is necessary to have a larger internal buffer in the FPGA. The problem is that it takes a lot of time to implement the hardware and it does not meet timing easily. Another buffer scheme must be followed.

This is the other scheme and it doesn't work. I putted one buffer after the other and it does meet timing but the code gets awful and it doesn´t make sence. I give up with this situation. Sorry virtex5 and my current pcie network
