
CMD_ROUTER_ARP		= (cmd_route_arr-jump_table)>>1

;**************************************************
;**************************************************
;Command status
; 
;**************************************************
				.section base_page_ram
command_list		.dstruct DataTypes.COMMAND_LIST
				.send

				.section ram_data
usr_cmd_list		.dstruct DataTypes.COMMAND_LIST
network_status		.dstruct DataTypes.NETWORK_STATUS
socket1				.dstruct DataTypes.PORT_LISTERN
socket2				.dstruct DataTypes.PORT_LISTERN
init_end
				.send

;**************************************************************
				.section rom_code
					;BASIC entry point (SYS44400)
Execute				lda $d030
					pha
					;switch CIAs to $DC00
					and #%00000001
					sta $d030
					tba
					pha
					lda #>BASE_PAGE_RAM
					tab
	
					;Is command Initialise
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
do_command			lda #BANK
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
					;Restore Base Page and $d030
cmd_exit			pla 
					tab
					pla
					sta $d030
	
					rts
	
jump_table			.word Initialise.Initialise		;0
					.word DHCP.Run					;1
					.word STMachine.SetConnected	;2
					;following need network up
need_net			.word Ethernet.EtherSend		;3
					.word ARP.SendARPRequest		;4
cmd_route_arr		.word ARP.RouterARPRequest		;5
					;following functions need ARP
need_arp			.word IPv4.SendIPPacket			;6
					.word UDP.SendUDPPacket			;7
	
copy_cmd_list		;dma job to copy user command list to command list
					.byte %00000000						;command low byte: COPY
					.word size(command_list)			;size of command list
					.word usr_cmd_list					;source address
					.byte BANK							;source Bank
					.byte <command_list,>BASE_PAGE_RAM	;destination address
					.byte BANK							;destination Bank
					.byte 0								;command hi byte
					.word 0								;modulo
				.send
