
CMD_ROUTER_ARP		= (cmd_route_arr-jump_table)>>1

;**************************************************
;**************************************************
;Command status
; 
;**************************************************
		.section base_ram_data
command_list	.dstruct DataTypes.COMMAND_LIST
		.send

		.section ram_data
usr_cmd_list	.dstruct DataTypes.COMMAND_LIST
network_status	.dstruct DataTypes.NETWORK_STATUS
socket1			.dstruct DataTypes.PORT_LISTERN
socket2			.dstruct DataTypes.PORT_LISTERN
socket3			.dstruct DataTypes.PORT_LISTERN
socket4			.dstruct DataTypes.PORT_LISTERN
socket5			.dstruct DataTypes.PORT_LISTERN
socket6			.dstruct DataTypes.PORT_LISTERN
socket7			.dstruct DataTypes.PORT_LISTERN
socket8			.dstruct DataTypes.PORT_LISTERN
init_end
		.send

;**************************************************************
		.section rom_code
				;Is state already busy
Execute			lda $d030
				pha
				;switch CIAs to $DC00
				and #%00000001
				sta $d030
				tba
				pha
				lda #>BASE_DATA_RAM
				tab

				lda usr_cmd_list.command
				beq do_command
				bbr StMachine.ST_CONNECTED_b,StMachine.state,cmd_exit
				asl a 
				cmp #need_net-jump_table
				bcc do_command		;Network not needed
				;Is network IP configured
				bbr StMachine.ST_NETWORK_UP_b,StMachine.state,cmd_exit
				cmp #need_arp-jump_table
				blt do_command		;ARP not needed
				;Get MAC address
				jsr ARP.AddressLookup
				bcs do_command		;Found ARP
				;No match found send ARP request
				jsr ARP.SendARPRequest
				;This will Execute again when ARP has finished
				smb StMachine.ST_RUN_CMD_b,StMachine.state
				bra cmd_exit

				;Copy command list
do_command		lda #BANK
				sta $d702
				lda #>copy_cmd_list
				sta $d701
				lda #<copy_cmd_list
				sta $d700
				;Get command and execute
				lda usr_cmd_list.command
				asl a 
				tax
				jsr (jump_table,x)
cmd_exit		pla 
				tab
				eom
				pla
				sta $d030
				rts

jump_table		.word Initialise.Initialise		;0
				.word DHCP.Run					;1
				;following need network up
need_net		.word Ethernet.EtherSend		;2
				.word ARP.SendARPRequest		;3
cmd_route_arr	.word ARP.RouterARPRequest		;4
				;following functions need ARP
need_arp		.word IPv4.SendIPPacket			;5
				.word UDP.SendUDPPacket			;6

copy_cmd_list	;dma job to copy command list from common ram to here
				.byte %00000000						;command low byte: COPY
				.word size(command_list)			;size of command list
				.word usr_cmd_list					;source address
				.byte BANK							;source Bank
				.byte <command_list,>BASE_DATA_RAM	;destination address
				.byte BANK							;destination Bank
				.byte 0								;command hi byte
				.word 0								;modulo
		.send
