ARP_PACKET		.struct
hardware_type		.fill 2
protocol_type		.fill 2
hardware_len		.fill 1
protocol_len		.fill 1
operation			.fill 2
sender_ha			.fill 6
sender_pa			.fill 4
target_ha			.fill 6
target_pa			.fill 4
				.endstruct
ARP_ENTRY		.struct
mac_address			.fill 6
ip_address			.fill 4
				.endstruct

ARP_PACKET_SIZE		= size(ARP_PACKET)
ARP_ENTRY_SIZE		= size(ARP_ENTRY)	;Enrty in address lookup table
ARP_ENTY_COUNT		= 10 				;Set lookup table length in entries

TP_NO_REQUEST		= 0
TP_ROUTER_REQ		= 1
TP_ARP_REQUEST		= 2

		.section ram_data
arp_table				.fill ARP_ENTRY_SIZE * ARP_ENTY_COUNT
		.send

		.section base_ram_data
arp_pkt					.dstruct ARP_PACKET
arp_error_cnt			.fill 2
arp_recvd_cnt			.fill 2
arp_table_pntr			.fill 2
arp_type				.fill 1
		.send 

		.section rom_code
;**************************************************
;**************************************************
;Initialise ARP counters
; 
;**************************************************
Initialise				lda #0
						sta arp_error_cnt
						sta arp_error_cnt+1
						sta arp_recvd_cnt
						sta arp_recvd_cnt+1
						rts

;**************************************************
;**************************************************
;Received ARP packet entry point
;Check packet header and 
; 
;**************************************************
						;Copy ARP packet to RAM
ReceivedPacket			lda #<arp_pkt
						sta Ethernet.RXDestAddrL
						lda #>BASE_DATA_RAM
						sta Ethernet.RXDestAddrH
						lda #BANK
						sta Ethernet.RXDestBank
						txa
						ldx #ARP_PACKET_SIZE
						jsr Ethernet.CopyRXData

						;Check ARP header details
						ldx #6
-						lda arp_pkt,x
						cmp header_check,x
						bne arp_error
						dex
						bpl -
						
						;Determine ARP packet request or responce
						ldx #ARP_PACKET.operation+1
						lda arp_pkt,x
						dec a
						beq rx_arp_request
						dec a
						beq rx_arp_responce

						;ARP header error increment error counter
arp_error				inw arp_error_cnt
						rts

						;Expected ARP header
header_check			.byte $00,$01,$08,$00,$06,$04,$00,$01

;**************************************************
;**************************************************
;Deal with ARP request
;Is it APR request, ARP probe or ARP announcement
; 
;**************************************************
						;Prepare ARP responce
rx_arp_request			inw arp_recvd_cnt
						jsr is_tip_me
						beq +
						rts
+						jsr is_sip_zero
						beq respond_probe

;**************************************************
;**************************************************
;Prepare APR responce for ARP request
; 
;**************************************************
respond_arp				ldx #10-1
-						lda arp_pkt.sender_ha,x
						sta arp_pkt.target_ha,x
						sta Command.command_list.ether_dest_mac,x;
						lda Command.network_status.mac_address,x
						sta arp_pkt.sender_ha,x
						dex
						bpl -
						lda #2
						sta arp_pkt.operation+1

;**************************************************
;**************************************************
;Send the prepared ARP respnce
; 
;**************************************************
						;Sent the ARP packet
send_arp_packet			lda #<arp_pkt
						sta Command.command_list.data_addr
						lda #>BASE_DATA_RAM
						sta Command.command_list.data_addr+1
						lda #BANK
						sta Command.command_list.data_bank
						lda #ARP_PACKET_SIZE
						sta Command.command_list.data_size
						ldz #0
						stz Command.command_list.data_size+1
						lda #$08
						ldx #$06
						jsr Ethernet.NewEtherFrame
						bne Ethernet.AddDataSend
						rts

;**************************************************
;**************************************************
;Prepare APR responce for ARP probe
; 
;**************************************************
respond_probe			rts

;**************************************************
;**************************************************
;Add ARP announce to local ARP list
; 
;**************************************************
rx_arp_announce			rts

;**************************************************
;**************************************************
;Add ARP responce to local ARP list
; 
;**************************************************
rx_arp_responce			inw arp_recvd_cnt
						;Insert ARP responce into ARP table
						lda #BANK
						sta $d702
						lda #>dma_arp_insert
						sta $d701
						lda #<dma_arp_insert
						sta $d700

						lda arp_type
						cmp #TP_ROUTER_REQ
						bne +
						;Copy router mac address to network_status
						lda #>dma_router_mac
						sta $d701
						lda #<dma_router_mac
						sta $d700

+						lda #TP_NO_REQUEST
						sta arp_type
						lda #0
						ldx #0
						jmp StMachine.FinishEvent
						rts

;**************************************************
;**************************************************
;Add ARP responce to table
; 
;**************************************************
						;DMA job to shift ARP table down one
dma_arp_insert			.byte %00000100 									;command low byte: COPY+CHAIN
						.word ARP_ENTRY_SIZE*(ARP_ENTY_COUNT-1)				;copy count
						.word arp_table+ARP_ENTRY_SIZE						;source address
						.byte BANK ;| %01000000								;source Bank
						.word arp_table										;destination address
						.byte BANK ;| %01000000								;destination Bank
						.byte 0												;command hi byte
						.word 0												;modulo
						;DMA job to insert new ARP entery					
						.byte %00000000										;command low byte: COPY
						.word ARP_ENTRY_SIZE								;copy count
						.byte <arp_pkt.sender_ha,>BASE_DATA_RAM				;source address
						.byte BANK 											;source Bank Direction down
						.word arp_table+(ARP_ENTRY_SIZE*(ARP_ENTY_COUNT-1))	;destination address
						.byte BANK 											;destination Bank
						.byte 0												;command hi byte
						.word 0												;modulo
						;DMA job to insert new ARP entery					
dma_router_mac			.byte %00000000										;command low byte: COPY
						.word size(arp_pkt.sender_ha)						;copy count
						.byte <arp_pkt.sender_ha,>BASE_DATA_RAM				;source address
						.byte BANK 											;source Bank Direction down
						.word Command.network_status.gateway_mac			;destination address
						.byte BANK 											;destination Bank
						.byte 0												;command hi byte
						.word 0												;modulo

;**************************************************
;**************************************************
;Address lookup. Checks local list for IP->MAC
;Command list:
; command_list.ip_dest_addr
;Return:
; C = CLR no match found
; C = SET MAC set
; 
;**************************************************
						;Is IP address part of local network
AddressLookup			ldx #4-1
-						lda Command.usr_cmd_list.ip_dest_addr,x
						and Command.network_status.subnet_mask,x
						cmp Command.network_status.network_addr,x
						bne not_local_address
						dex
						bpl -
						;Check local ARP table for matching IP address
						jsr search_lookup_table
						bcs match_found
						rts 	;No match found
						
						;Address outside of loacl network
						;Set arp_table_pntr to gateway MAC address
not_local_address		lda #<Command.network_status.gateway_mac
						sta arp_table_pntr
						lda #<Command.network_status.gateway_mac
						sta arp_table_pntr+1

						;Copy MAC address to command list
match_found				ldy #6-1
-						lda (arp_table_pntr),y
						sta Command.usr_cmd_list.ether_dest_mac,y
						dey
						bpl -
						
						sec
						rts

;**************************************************
;**************************************************
;Send ARP request, adds ARP responce to ARP table
;Command list:
; usr_cmd_list.ip_dest_addr
; 
;**************************************************
RouterARPRequest		lda #TP_ROUTER_REQ
						bra +

;**************************************************
;**************************************************
;Send ARP request, adds ARP responce to ARP table
;Command list:
; usr_cmd_list.ip_dest_addr
; 
;**************************************************
SendARPRequest			lda #TP_ARP_REQUEST
+						sta arp_type
						lda #StMachine.ST_TX_BUSY|StMachine.ST_RX_BUSY
						ldx #<arp_timer
						ldy #>arp_timer
						ldz #4
						jsr StMachine.SetEvent
						bne +
						;State is busy
						rts
						
+						ldx #0
						ldz #0
						ldy #$ff
-						sty Command.command_list.ether_dest_mac,x
						lda Command.usr_cmd_list.ip_dest_addr-2,x
						sta arp_pkt.target_pa-2,x
						stz arp_pkt.target_ha,x
						inx
						cpx #6
						bne -

						ldx #10-1
-						lda header_check,x
						sta arp_pkt,x
						lda Command.network_status.mac_address,x
						sta arp_pkt.sender_ha,x
						dex
						bpl -
						
						jsr	send_arp_packet
						beq StMachine.ErrorEvent
						rts

;**************************************************
;**************************************************
;Timeout call back
; 
;**************************************************
arp_timer				ldz #DataTypes.MESSAGES.arp_timeout
						lda arp_type
						cmp #TP_ROUTER_REQ
						bne +
						ldz #DataTypes.MESSAGES.gw_arp_timeout
+						lda #TP_NO_REQUEST
						sta arp_type
						jmp StMachine.ErrorEvent

;**************************************************
;**************************************************
;Search address lookup table for IP entry
;Command list:
; ip_dest_address
;Return
; arp_table_pntr = pointer to MAC address
; C Set = match, Clr = no match
; 
;**************************************************
search_lookup_table		lda #<arp_table+(ARP_ENTRY_SIZE*ARP_ENTY_COUNT)
						sta arp_table_pntr
						lda #>arp_table+(ARP_ENTRY_SIZE*ARP_ENTY_COUNT)
						sta arp_table_pntr+1
						ldz #ARP_ENTY_COUNT

-						ldx #3
						ldy #ARP_ENTRY.ip_address+3
						lda arp_table_pntr
						sec
						sbc #ARP_ENTRY_SIZE
						sta arp_table_pntr
						bcs ip_test
						dec arp_table_pntr+1
ip_test					lda Command.usr_cmd_list.ip_dest_addr,x
						cmp (arp_table_pntr),y
						bne next_entery
						dey
						dex 
						bpl ip_test
						rts
next_entery				dez
						bne -
						clc 
						rts

;**************************************************
;**************************************************
;Check sender protocol address is zero
;Return
; Z = Clr = addr is zero
; Z = Set = addr is not zero
; 
;**************************************************
is_sip_zero				lda arp_pkt.sender_pa
						ora arp_pkt.sender_pa+1
						ora arp_pkt.sender_pa+2
						ora arp_pkt.target_pa+3
						rts

;**************************************************
;**************************************************
;Check taget IP address matches system IP address.
;Max 24 bit block (10.xxx.xxx.xxx/8).
;Class A, B and C private network ranges.
;Return
; Z = Clr = addr matches
; Z = Set = addr does not match
;
;**************************************************
is_tip_me				lda arp_pkt.target_pa+3
						cmp Command.network_status.ip_address+3
						beq +
						rts
+						lda arp_pkt.target_pa+2
						cmp Command.network_status.ip_address+2
						beq +
						rts
+						lda arp_pkt.target_pa+1
						cmp Command.network_status.ip_address+1
						rts
									
		.send