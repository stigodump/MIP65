DHCP_HEADER	.struct 
op 		 			.fill 1
htype 				.fill 1
hlen 				.fill 1
hops 				.fill 1
xid 				.fill 4
second 				.fill 2
flags 				.fill 2
ciaddr 				.fill 4
yiaddr				.fill 4
siaddr				.fill 4
giaddr				.fill 4
chaddr				.fill 16
sname				.fill 64
bname				.fill 128
mcookie				.fill 4
options				.fill 1
			.endstruct

DHCP_DISCHEAD_SIZE 	= size(DHCP_HEADER)+opt_disco_end-opt_discover
DHCP_REQTHEAD_SIZE	= size(DHCP_HEADER)+opt_reqst_end-opt_request
DHCP_DEST_PORT		= 67
DHCP_SOURCE_PORT	= 68
WAITING_NONE		= 0
WAITING_OFFER		= %10000001
WAITING_ACK			= %10000010
DHCP_TIMEOUT		= 5 ;in seconds

		.section base_ram_data
header_tx_pntr		.fill 2
header_rx_pntr		.fill 2
options_pntr		.fill 2
option_pntr			.fill 2
mem_bank			.fill 1
dhcp_status			.fill 1
temp_bp				.fill 1
		.send 

		.section rom_code
magic_cookie		.byte $63,$82,$53,$63
					;discover and request options
opt_discover		.byte $35,$01,$01 			;DHCP discover
					.byte $37,$03,$01,$03,$06	;Request subnet, gateway & DNS
opt_disco_end		.byte $ff
opt_request			.byte $35,$01,$03			;DHCP request
opt_req_ip			.byte $32,$04,$00,$00,$00,$00
opt_srv_ip			.byte $36,$04,$00,$00,$00,$00
opt_reqst_end		.byte $ff

;**************************************************
;**************************************************
;Initialise DHCP parameters
; 
;**************************************************
Initialise			lda #WAITING_NONE
					sta dhcp_status
					rts

;**************************************************
;**************************************************
;Run DHCP request
;Command List:
; mac_address $ff,$ff,$ff,$ff,$ff,$ff
; dest_ip_addr 0.0.0.0
; 
;**************************************************
	 				;Set timeout event callback
Run					lda #StMachine.ST_TX_BUSY|StMachine.ST_RX_BUSY
					ldx #<timeout
					ldy #>timeout
					ldz #DHCP_TIMEOUT			
					jsr StMachine.SetEvent
					bne +
					;State is busy
					rts
					;Clear memory pointers for free mem
					lda #$ff
+					sta header_tx_pntr+1
					sta header_rx_pntr+1
					;Allocate memory for DHCP header
					;and fill with $00					
					lda #2 		;request 512bytes
					ldx #$00	;fill with 0
					ldy #1 		;fill yes
					jsr Memory.AllocMemory
					bmi memory_err
					stz header_tx_pntr
					sty header_tx_pntr+1
					stx mem_bank

					;Configure DHCP header
					;Set operation type
					ldy #DHCP_HEADER.op
					lda #$01
					sta (header_tx_pntr),y
					;Set hardwarew type
					ldy #DHCP_HEADER.htype
					sta (header_tx_pntr),y
					;Set hardware address length
					ldy #DHCP_HEADER.hlen
					lda #$06
					sta (header_tx_pntr),y
					;Set transaction ID
					ldy #DHCP_HEADER.xid
					lda Timer.timer_sec
					sta (header_tx_pntr),y
					iny
					lda Timer.TIMERB_L
					sta (header_tx_pntr),y
					iny
					lda Timer.TIMERA_H
					sta (header_tx_pntr),y
					iny
					lda Timer.TIMERA_L
					sta (header_tx_pntr),y
					;Copy magic cookie & options
					lda header_tx_pntr+1
					sta options_pntr+1
					lda #DHCP_HEADER.mcookie
					sta options_pntr
					ldy #0
-					lda magic_cookie,y
					sta (options_pntr),y
					iny
					cpy #opt_disco_end-magic_cookie+1
					bne -
					;Set header MAC address &
					;broadcast destination MAC address
					ldy #DHCP_HEADER.chaddr+5
					ldx #6
					ldz #$ff
-					lda Command.network_status.mac_address-1,x
					sta (header_tx_pntr),y
					stz Command.command_list.ether_dest_mac-1,x
					dey
					dex
					bne -
					;Configure UPD parameters
					;Set destination IP address to broadcast
					stz Command.command_list.ip_dest_addr
					stz Command.command_list.ip_dest_addr+1
					stz Command.command_list.ip_dest_addr+2
					stz Command.command_list.ip_dest_addr+3
					;Set destination and source ports
					lda #DHCP_DEST_PORT
					sta Command.command_list.dest_port_num+1
					stx Command.command_list.dest_port_num
					lda #DHCP_SOURCE_PORT
					sta Command.command_list.source_port_num+1
					stx Command.command_list.source_port_num
					;Set DHCP packet size
					lda #<DHCP_DISCHEAD_SIZE
					sta Command.command_list.data_size
					lda #>DHCP_DISCHEAD_SIZE
					sta Command.command_list.data_size+1
					;Set DHCP packet address
					lda header_tx_pntr
					sta Command.command_list.data_addr
					lda header_tx_pntr+1
					sta Command.command_list.data_addr+1
					;Set DHCP packet BANK
					lda mem_bank
					sta Command.command_list.data_bank
					;Send DHCP packet over UDP
					jsr UDP.CreateUDPPacket
					beq error_exit
					lda #WAITING_OFFER
					sta dhcp_status
					rts

;**************************************************
;**************************************************
;Get DHCP offer/acknoledgement packet and check XID
; A = Offset to UDP packet data
; 
;**************************************************
ReceivedPacket		ldx dhcp_status
					bmi get_packet
					;Not waiting for packet
xid_mismatch		rts

get_packet			sta temp_bp
					cpx #WAITING_OFFER
					beq +
					lda header_rx_pntr
					taz 		;Because LDZ Reg does not have BP addressing
					ldy header_rx_pntr+1
					ldx mem_bank
					bra get_dhcp_pkt

					;Allocate memory for DHCP offer
+					sec
					lda Ethernet.pkt_rx_info
					sbc temp_bp
					lda Ethernet.pkt_rx_info+1
					sbc #0
					inc a
					and #$0f
					ldy #0		;no fill
					jsr Memory.AllocMemory
					bmi memory_err
					stz header_rx_pntr
					sty header_rx_pntr+1
					stx mem_bank

					;Copy DHCP packet from RX buffer
get_dhcp_pkt		lda temp_bp		;offset to begining of data
					stz Ethernet.RXDestAddrL
					sty Ethernet.RXDestAddrH
					stx Ethernet.RXDestBank
					ldx #0 	;copy all remaining data
					jsr Ethernet.CopyRXData

					;Check XID
					ldx #4
					ldy #DHCP_HEADER.xid
-					lda (header_tx_pntr),y
					eor (header_rx_pntr),y
					bne xid_mismatch
					iny
					dex
					bne -

					lda dhcp_status
					cmp #WAITING_ACK
					beq ack_pkt

;**************************************************
;**************************************************
;Process DHCP offer & send request
; 
;**************************************************
					;Check its an offer
					lda header_rx_pntr
					ldx header_rx_pntr+1
					jsr find_options
					beq packet_err
					lda #53
					jsr find_option
					beq packet_err
					ldy #1
					lda (option_pntr),y
					cmp #2
					bne packet_err
					;Copy default options
					ldx #0
					ldy #DHCP_HEADER.options
-					lda opt_request,x
					sta (header_tx_pntr),y
					inx
					iny
					cpx #opt_reqst_end-opt_request+1
					bne -
					;Copy server IP address
					lda #3
					jsr find_option
					beq +
					ldz #4
					ldy #DHCP_HEADER.options+((opt_srv_ip+2)-opt_request)+3
-					lda (option_pntr),z
					sta (header_tx_pntr),y
					dey
					dez
					bne -
					;Copy request IP address
+					ldx #0
					ldy #DHCP_HEADER.yiaddr
					ldz #DHCP_HEADER.options+((opt_req_ip+2)-opt_request)
-					lda (header_rx_pntr),y
					sta (header_tx_pntr),z
					iny
					inz
					inx
					cpx #4
					bne -
					;Set DHCP packet size
					lda #<DHCP_REQTHEAD_SIZE
					sta Command.command_list.data_size
					lda #>DHCP_REQTHEAD_SIZE
					sta Command.command_list.data_size+1
					;Send DHCP packet over UDP
					jsr UDP.CreateUDPPacket
					beq error_exit
					lda #WAITING_ACK
					sta dhcp_status
					rts

;**************************************************
;**************************************************
;Process DHCP acknoledgement 
; 
;**************************************************
ack_pkt				lda header_rx_pntr
					ldx header_rx_pntr+1
					jsr find_options
					beq packet_err
					lda #53
					jsr find_option
					beq packet_err
					ldy #1
					lda (option_pntr),y
					cmp #5
					bne packet_err
					;Get DNS addresses
					lda #6
					jsr find_option
					beq ++
					ldy #0 	;Get option data length
					lda (option_pntr),y
					cmp #3*4+1
					bcc +
					lda #3*4
+					taz
					inw option_pntr
-					lda (option_pntr),y
					sta Command.network_status.dns1,y
					iny
					dez
					bne -
					;Get Subnet Mask
+					lda #1
					jsr find_option
					beq +
					ldy #0
					ldz #4
					inw option_pntr
-					lda (option_pntr),y
					sta Command.network_status.subnet_mask,y
					iny
					dez
					bne -
					;Get Gateway address
+					lda #3 ;Option router address
					jsr find_option
					beq +
					ldy #0
					ldz #4
					inw option_pntr
-					lda (option_pntr),y
					sta Command.network_status.gateway_addr,y
					sta command.usr_cmd_list.ip_dest_addr,y
					iny
					dez
					bne -
					;Get offered IP address &
					;set network address
+					ldy #DHCP_HEADER.yiaddr
					ldx #0
-					lda (header_rx_pntr),y
					sta Command.network_status.ip_address,x
					and Command.network_status.subnet_mask,x
					sta Command.network_status.network_addr,x
					inx
					iny
					cpy #DHCP_HEADER.siaddr
					bne -
					;Set state machine, DHCP state, Success
					jsr de_alloc_mem
					lda #WAITING_NONE
					sta dhcp_status
					;Do a router ARP for gateway mac address
					lda #Command.CMD_ROUTER_ARP
					sta Command.usr_cmd_list.command
					smb StMachine.ST_RUN_CMD_b,StMachine.state
					;Finish DHCP command
					lda #StMachine.ST_DHCP_STATIC|StMachine.ST_NETWORK_UP
					ldx #0
					jmp StMachine.FinishEvent

					;Deallocate memory
packet_err			ldz #DataTypes.MESSAGES.dhcp_packet_err
					bra error_exit 

;**************************************************
;**************************************************
;Not enough memory error
; 
;**************************************************					
memory_err			ldz #DataTypes.MESSAGES.dhcp_no_memory

;**************************************************
;**************************************************
;Report error and release memory
; 
;**************************************************					
error_exit			jsr de_alloc_mem
					lda #WAITING_NONE
					sta dhcp_status
					jmp StMachine.ErrorEvent

;**************************************************
;**************************************************
;Free any memory used
; 
;**************************************************					
de_alloc_mem		lda header_rx_pntr+1
					cmp #$ff
					beq +
					jsr Memory.FreeMemory
+					lda header_tx_pntr+1
					cmp #$ff
					beq +
					jsr Memory.FreeMemory
+					rts

;**************************************************
;**************************************************
;Report error and release memory
; 
;**************************************************					
timeout 			bne error_exit
					ldz #DataTypes.MESSAGES.dhcp_timeout
					bra error_exit 

;**************************************************
;**************************************************
;Find magic cookie in rx packet\
; A = <header_pntr
; X = >header_pntr
;Return
; options_pointer = pointer to begining of options
; Z = CLR cookie found
; Z = SET cookie not found
;**************************************************
find_options		clc
					adc #DHCP_HEADER.mcookie
					sta options_pntr
					txa
					adc #0
					sta options_pntr+1
					ldx #0
					ldy #0
f_loop				lda (options_pntr),y
					cmp magic_cookie,x
					bne +
					inx
					cpx #4
					beq found_cookie
-					iny
					bne f_loop
					rts 

+					ldx #0
					bra -

found_cookie		tya
					sec 
					adc options_pntr
					sta options_pntr
					bcc +
					inc options_pntr+1
+					lda #1
					rts 


;**************************************************
;**************************************************
;Find option
; A = option number
;Return
; option_pntr = pointer to option length
; X = 0 End of options not found, checked 64 bytes
; Z = CLR found option
; Z = SET not found
;**************************************************
find_option 		sta temp_bp
					lda options_pntr
					sta option_pntr
					lda options_pntr+1
					sta option_pntr+1
					ldx #64				;Max length of options
					ldy #0
-					lda (option_pntr),y ;Get option number
					beq +				;Skip $00 padding
					cmp temp_bp
					beq found_exit		;Option found
					cmp #$ff
					beq exit			;$ff end of options
					inw option_pntr
					lda (option_pntr),y ;Get option length
					adc option_pntr
					sta option_pntr
					bcc +
					inc option_pntr+1
+					inw option_pntr
					dex
					bne -
exit				rts
found_exit			inw option_pntr 	;point to option length
					ldx #1
					rts

		.send









