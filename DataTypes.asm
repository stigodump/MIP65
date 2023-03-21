DMA_LIST_B		.struct
command_l		.fill 1
count_l			.fill 1
count_h			.fill 1
source_addr_l	.fill 1
source_addr_h	.fill 1
source_bank		.fill 1
dest_addr_l		.fill 1
dest_addr_h		.fill 1
dest_bank		.fill 1
command_h		.fill 1
modulo_l		.fill 1
modulo_h		.fill 1
	.endstruct

DMA_LIST_ENHD	.struct 
option1			.fill 1
data1			.fill 1
option2			.fill 1
data2			.fill 1
end_opt_list	.fill 1
command_l		.fill 1
count_l			.fill 1
count_h			.fill 1
source_addr_l	.fill 1
source_addr_h	.fill 1
source_bank		.fill 1
dest_addr_l		.fill 1
dest_addr_h		.fill 1
dest_bank		.fill 1
command_h		.fill 1
modulo_l		.fill 1
modulo_h		.fill 1
	.endstruct

COMMAND_LIST	.struct
command 		.fill 1
ether_protocol	.fill 2
ether_dest_mac	.fill 6
ip_dest_addr	.fill 4
ip_protocol		.fill 1
ip_DSCP			.fill 1
dest_port_num	.fill 2
source_port_num	.fill 2
data_addr		.fill 2
data_bank		.fill 1
data_size		.fill 2
result			.fill 1
	.endstruct

PORT_LISTERN	.struct 
port_number		.fill 2
status 			.fill 1
packet_pntr		.fill 2
data_pntr		.fill 2
data_bank		.fill 1
data_len		.fill 2
call_back		.fill 2
	.endstruct

NETWORK_STATUS	.struct 
mac_address		.fill 6
ip_address		.fill 4
subnet_mask		.fill 4
gateway_mac		.fill 6
gateway_addr	.fill 4
network_addr	.fill 4
dns1			.fill 4
dns2			.fill 4
dns3			.fill 4
status 			.fill 1
	.endstruct

MESSAGES		.struct
status_busy		.fill 1 ;0
cmd_complete	.fill 1 ;1
dhcp_no_memory	.fill 1 ;2
cable_discon	.fill 1 ;3
net_offline		.fill 1 ;4
send_failed		.fill 1 ;5
arp_timeout		.fill 1 ;6
dhcp_packet_err	.fill 1 ;7
dhcp_timeout	.fill 1 ;8
cable_connected	.fill 1 ;9
data_to_large	.fill 1 ;a
arp_pkt_err		.fill 1 ;b
UDP_pkt_err		.fill 1 ;c
gw_arp_timeout 	.fill 1 ;d
	.endstruct
