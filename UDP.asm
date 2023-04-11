UDP_HEADER	.struct
source_port_num		.fill 2
dest_port_num		.fill 2
total_length		.fill 2
checksum			.fill 2
			.endstruct
UDP_HEAD_SIZE		= size(UDP_HEADER)

SourcePort 			= header.source_port_num
DestPort 			= header.dest_port_num
DestIP 				= IPv4.header.dest_ip

		.section base_page_ram
skt_pntr			.fill 2
udp_rx_count		.fill 2
temp_bp				.fill 1
rx_udp_offset		.fill 1
rx_dest_port		.fill 2
rx_data_len			.fill 2
		.send 

		.section ram_data
header 				.dstruct UDP_HEADER
		.send

		.section rom_code
;**************************************************
;**************************************************
;Initialise UDP parameters
;
;**************************************************
Initialise			lda #0
					sta udp_rx_count
					sta udp_rx_count+1
					rts

;**************************************************
;**************************************************
;Build UDP header and add to TX buffer
; X = < data size
; Y = > data size
; SourcePort = Source port number
; DestPort = destination port number
;Return:
; A = next TX buffer position, 0 = Error
;
;**************************************************

					;Set header parameters
add_udp_header		ldz #0
					stz header.checksum
					stz header.checksum+1
					txa
					clc
					adc #UDP_HEAD_SIZE
					bcc +
					iny
+					sty header.total_length
					sta header.total_length+1
					tax

					;Create IP header
					lda #$00
					ldz #$11	;UDP
					jsr IPv4.add_ip_header
					beq +
					;Copy UDP header to TX buffer
					tax
					adc #Ethernet.ETHER_BUFFER_ADDR[0:8]
					sta Ethernet.dma_list_tx.dest_addr_l
					lda #Ethernet.ETHER_BUFFER_ADDR[8:16]
					adc #0
					sta Ethernet.dma_list_tx.dest_addr_h
					lda #UDP_HEAD_SIZE
					sta Ethernet.dma_list_tx.count_l
					lda #0
					sta Ethernet.dma_list_tx.count_h
					lda #<header
					sta Ethernet.dma_list_tx.source_addr_l
					lda #>header
					sta Ethernet.dma_list_tx.source_addr_h
					lda #BANK
					sta Ethernet.dma_list_tx.source_bank
					sta $d702
					lda #>Ethernet.dma_list_tx
					sta $d701
					lda #<Ethernet.dma_list_tx
					sta $d705				;Enhanced DMA job
					txa
					;Offset to start of data in TX buffer
					clc	
					adc #UDP_HEAD_SIZE
+					rts

;**************************************************
;**************************************************
;Send a UDP frame with data
;Command List:
; ip_dest_addr
; dest_port
; source_port
; data_size
; data_addr
; data_bank
;Return:
; A = offset to end of UDP packet header, 0 = Error
; 
;**************************************************
					;Set TX timeout event
SendUDPPacket		lda #StMachine.ST_TX_BUSY
					jsr StMachine.SetEvent
					;Create UDP header in TX buffer
					jsr CreateUDPPacket
					beq +
					rts
+					ldz #DataTypes.MESSAGES.UDP_pkt_err
					jmp StMachine.ErrorEvent					

;**************************************************
;**************************************************
;Send a UDP frame with data
;Command List:
; ip_dest_addr
; dest_port
; source_port
; data_size
; data_addr
; data_bank
;Return:
; A = offset to end of UDP packet header, 0 = Error
; 
;**************************************************
					;Set required parameters
CreateUDPPacket		ldx Command.command_list.data_size
					ldy Command.command_list.data_size+1
					lda Command.command_list.source_port_num
					sta header.source_port_num 
					lda Command.command_list.source_port_num+1
					sta header.source_port_num+1 
					lda Command.command_list.dest_port_num
					sta header.dest_port_num 
					lda Command.command_list.dest_port_num+1
					sta header.dest_port_num+1
					;Create UDP header
					jsr add_udp_header	
					beq +
					;Add data to packet and send
					jmp Ethernet.AddDataSend
					;Error
+					rts	

;**************************************************
;**************************************************
;Process UDP packet
; A = Offset to start of UDP header in RX buffer
;Return
; A = Offset to UDP data in RX buffer
; 
;**************************************************
ReceivedPacket		inw udp_rx_count
					sta rx_udp_offset
					clc
					;Get destination port from UDP header
					adc #UDP_HEADER.dest_port_num
					taz
					#lda32z Ethernet.ether_buff_ptr
					sta rx_dest_port
					inz
					#lda32z Ethernet.ether_buff_ptr
					sta rx_dest_port+1
					;Get data length UDP header
					inz
					inz
					#lda32z Ethernet.ether_buff_ptr
					sec
					sbc #UDP_HEAD_SIZE
					sta rx_data_len
					dez
					#lda32z Ethernet.ether_buff_ptr
					sbc #0
					sta rx_data_len+1

					;check active socket port number
					ldx #size(ch_lo_bytes)-1
-					dex
					;Checked all sockets
					bmi system_ports
					jsr set_ch_pntr
					;Is status open
					ldy #DataTypes.PORT_LISTERN.status
					lda (skt_pntr),y
					bmi +
					;Status closed, check if memory to free
					ldy #DataTypes.PORT_LISTERN.packet_pntr+1
					lda (skt_pntr),y
					beq -
					;Free the memory
					jsr Memory.FreeMemory
					;Set high byte to zero, no mem to free
					lda #0
					ldy #DataTypes.PORT_LISTERN.packet_pntr+1
					sta (skt_pntr),y
					bra -
					;Is port number listening port
+					ldy #DataTypes.PORT_LISTERN.port_number
					lda (skt_pntr),y
					cmp rx_dest_port
					bne -
					iny
					lda (skt_pntr),y
					cmp rx_dest_port+1
					beq udp_listern_recvd
					bra -
					;User port listening not found

					;Is port number < 256
system_ports		ldx rx_dest_port
					bne unknown_port
					lda rx_udp_offset
					clc
					adc #UDP_HEAD_SIZE
					ldx rx_dest_port+1
					;Is port number DHCP 68
					cpx #68
					bne +
					jmp DHCP.ReceivedPacket
					;Is port number HTTP 80
+					cpx #80
					bne unknown_port
					;Jump to HTTP handler
					rts

					;Not known port number
unknown_port		rts

;**************************************************
;**************************************************
;Set Base Page pointer to 1-8 RX chaenl
; X = channel number 0-7
;
;**************************************************
					;Free memory for old packet
udp_listern_recvd	ldz #DataTypes.PORT_LISTERN.packet_pntr+1
					lda (skt_pntr),z
					beq +
					jsr Memory.FreeMemory
					
					;Allocate memory for new packet
+					lda Ethernet.pkt_rx_info
					and #$0f
					inc a 
					jsr Memory.AllocMemory
					cpz #0
					bne +
					;Increment status byte to indicate new packet available
					ldz #DataTypes.PORT_LISTERN.status
					lda (skt_pntr),z
					inc a
					ora #%10000000
					sta (skt_pntr),z
					;Set new data pointer
					;Calculate data offset
					lda rx_udp_offset
					clc
					adc #UDP_HEAD_SIZE
					ldz #DataTypes.PORT_LISTERN.data_pntr
					sta (skt_pntr),z
					lda #0
					ldz #DataTypes.PORT_LISTERN.packet_pntr
					sta (skt_pntr),z
					sta Ethernet.RXDestAddrL
					tya
					ldz #DataTypes.PORT_LISTERN.data_pntr+1
					sta (skt_pntr),z
					ldz #DataTypes.PORT_LISTERN.packet_pntr+1
					sta (skt_pntr),z
					sta Ethernet.RXDestAddrH
					;Set bank where data is stored
					txa
					ldz #DataTypes.PORT_LISTERN.data_bank
					sta (skt_pntr),z
					sta Ethernet.RXDestBank
					;Set data length
					ldz #DataTypes.PORT_LISTERN.data_len
					lda rx_data_len
					sta (skt_pntr),z
					inz
					lda rx_data_len+1
					sta (skt_pntr),z
					;Copy data from RX buffer to memory
					lda #0
					ldx #0
					jsr Ethernet.CopyRXData
					;Error not enough memory
+					rts

;**************************************************
;**************************************************
;Set Base Page pointer to 1-8 RX chaenl
; X = channel number 0-7
;
;**************************************************
set_ch_pntr			lda ch_lo_bytes,x
					sta skt_pntr
					lda ch_hi_bytes,x
					sta skt_pntr+1
					rts

channels	:=(Command.socket1,Command.socket2)
ch_lo_bytes			.byte <channels
ch_hi_bytes			.byte >channels

	.send
