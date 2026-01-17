IPV4_HEADER		.struct
Ver_IHL 			.fill 1
DSCP_ENC			.fill 1
total_length		.fill 2
identification		.fill 2
fragment			.fill 2
time_to_live		.fill 1
protocol			.fill 1
h_checksum			.fill 2
source_ip			.fill 4
dest_ip				.fill 4
				.endstruct
IPv4_HEAD_SIZE		= size(IPV4_HEADER)

				.section base_page_ram
checksum			.fill 2
ipv4_rx_count		.fill 2
				.send 

				.section ram_data
header 				.dstruct IPV4_HEADER
				.send

				.section rom_code

;**************************************************
;**************************************************
;Initialise IP header and DMA list parameters
;
;**************************************************
Initialise			lda #BANK
					sta $d702
					lda #>dflt_param_dma
					sta $d701
					lda #<dflt_param_dma
					sta $d700
					lda #0
					sta ipv4_rx_count
					sta ipv4_rx_count+1		
					rts

					;IP header default values to be copied to RAM
default_params	.block
					.byte $45					;Version 4, IHL 5 x 4 = 20 octets
					.byte $00 					;DSCP, ENC 
					.byte $00,$00 				;Entire packet size
					.byte $12,$34				;Unique packet identifier
					.byte $40,$00 				;Flags (Do Not Fragment), Fragment Offset
					.byte $30					;Time To Live (TTL) (48 seconds/hops)
					.byte $00 					;Protocol
					.byte $00,$00 				;Header checksum
					.byte 0,0,0,0 				;Source IP adress
					.byte 0,0,0,0 				;Destination IP address
				.bend

dflt_param_dma		.byte %00000000				;command low byte: COPY
					.word size(default_params)	;header size (14 octets)
					.word default_params		;source addressm (default parameters ROM)
					.byte BANK					;source Bank
					.word header				;destination address (IPv4 header in RAM)
					.byte BANK					;destination Bank
					.byte 0						;command hi byte
					.word 0						;modulo

;**************************************************
;**************************************************
;Build IP header and add to TX buffer
; A = DSCP
; X = < data size
; Y = > data size
; Z = protocol
; network_status.source_ip
; command_list.dest_ip
;Return:
; A =  next TX buffer position, 0 = Error
; C = clear
;
;**************************************************
			
					;Set IP header parameters
add_ip_header		stz header.protocol
					asl a
					asl a
					sta header.DSCP_ENC
					txa
					clc
					adc #IPv4_HEAD_SIZE
					sta header.total_length+1
					tya 
					adc #0
					sta header.total_length
					inc header.identification
					;Copy source and destination IP addresses
					ldx #4-1
-					lda Command.command_list.ip_dest_addr,x
					sta header.dest_ip,x
					lda Command.network_status.ip_address,x
					sta header.source_ip,x
					dex
					bpl -
					;Calculate and set header checksum
					lda #0
					sta header.h_checksum
					sta header.h_checksum+1
					sta checksum
					sta checksum+1
					ldx #IPv4_HEAD_SIZE-1
					clc
-					lda checksum+1
					adc header,x
					sta checksum+1
					lda checksum
					dex
					adc header,x
					sta checksum
					dex
					bpl -
					eor #$ff
					sta header.h_checksum
					lda checksum+1
					adc #0
					eor #$ff
					sta header.h_checksum+1

					;Create a new Ethernet IPv4 packet
					lda #$08
					ldx #$00
					ldz header.total_length
					jsr Ethernet.NewEtherFrame
					beq +	;Error
					;Copy IP header to TX buffer
					tax
					adc #Ethernet.ETHER_BUFFER_ADDR[0:8]
					sta Ethernet.dma_list_tx.dest_addr_l
					lda #Ethernet.ETHER_BUFFER_ADDR[8:16]
					adc #0
					sta Ethernet.dma_list_tx.dest_addr_h
					lda #IPv4_HEAD_SIZE
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
					sta $d705	;Enhanced DMA job
					txa
					;Calculate data in TX buffer
					clc	
					adc #IPv4_HEAD_SIZE
+					rts

;**************************************************
;**************************************************
;Send an IP frame with data
;Command List:
; ip_dest_addr
; ip_protocol
; ip_DSCP
; data_size
; data_addr
; data_bank
; 
;**************************************************
					;Set TX timeout event
SendIPPacket		lda #StMachine.ST_TX_BUSY
					jsr StMachine.SetEvent
					;Get IP layer parameters
					lda Command.command_list.ip_DSCP
					ldx Command.command_list.data_size
					ldy Command.command_list.data_size+1
					ldz Command.command_list.ip_protocol
					jsr add_ip_header
					jmp Ethernet.AddDataSend

;**************************************************
;**************************************************
;Process received IP packet
; X = Offset to start of IP header in RX buffer
;Return
; A = Offset to IP data in RX buffer
; 
;**************************************************

ReceivedPacket		inw ipv4_rx_count
					txa
					clc
					adc #IPV4_HEADER.protocol
					taz
					;Get IPv4 protocol
					#lda32z Ethernet.ether_buff_ptr
					cmp #$11	;UDP
					bne +
					txa
					clc
					adc #IPv4_HEAD_SIZE
					jmp UDP.ReceivedPacket
+					rts

				.send