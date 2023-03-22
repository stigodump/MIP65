# MIP65
## Network stack for MEGA65
A project to get the MEGA65 talking to other computers around the world.

The project integrates Ethernet, IPV4, UDP, DHCP, ARP into a stand-alone package that runs on the MEGA65. All networking features can easily be utilised through BASIC or assembly.

## Usage

Download the network.d81 file from https://files.mega65.org/html/main.php or from this repository.

The disk contains the network package NETWORK.PRG and a BASIC program UDPTEST.PRG which connects to a network and allows UDP packets to be sent and received. The basic program contains REMARKS detailing how it works.

Load and run the NETWORK.PRG file.

Then load the UDPTEST.PRG and modify for specific requirements.

Line 100 to set the machine MAC address.

For receiving:
Line 180 specifies the listening port number 16448

For sending:
Line 530 specifies the destination IP address and line 540 specifies the destination Port number 16449

To send the message on line 120: Press the S key when running

There are many UDP Sender/Receiver applications available on Android, IOS, MAC, and Linux for testing with the MEGA65.

