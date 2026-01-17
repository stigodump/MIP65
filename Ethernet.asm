;******************************************************************
;
; Ethernet
;
;	Auther: R Welbourn
;	Discord: Stigodump
;	Date: 30/01/2023
;	
;
;******************************************************************

ETHER_HEADER	.struct
dest_mac_addr		.fill 6
source_mac_addr		.fill 6
ether_type			.fill 2
				.endstruct
ETHER_RX_PKT	.struct
packet_info			.fill 2
ethernet_header		.dstruct ETHER_HEADER
				.endstruct
ETHER_HEAD_SIZE		= size(ETHER_HEADER)
ETHER_RX_PKT_SIZE	= size(ETHER_RX_PKT)
MAX_DATA_SIZE		= $600
ETHER_BUFFER_ADDR	= $ffde800
ETHER_MIN_SIZE		= 60	;60 + 4 for CRC = 64

RXDestAddrL			= dma_list_rx.dest_addr_l
RXDestAddrH			= dma_list_rx.dest_addr_h
RXDestBank			= dma_list_rx.dest_bank


				.section base_page_ram
pkt_rx_info			.fill 2		;Received packet info
pkt_error_cnt		.fill 2		;16bit packet error counter
total_rx_bytes		.fill 4 	;32bit total received data bytes
total_tx_bytes		.fill 4 	;32bit total sent data bytes
ether_buff_ptr		.fill 4 	;32bit pointer to Ethernet TX/RX buffer
temp_bp				.fill 1
				.send 
;allocate RAM for Ethernet frame header & DMA list
				.section ram_data
header 				.dstruct ETHER_HEADER
dma_list_tx			.dstruct DataTypes.DMA_LIST_ENHD
dma_list_rx			.dstruct DataTypes.DMA_LIST_ENHD
				.send

				.section rom_code
;**************************************************
;**************************************************
;Initialise MAC address and DMA list
;Command List:
; mac_address
; 
;**************************************************

Initialise		;Hold in reset condition
				lda #$00
				sta $d6e0
				;Only allow Broadcast and MAC packets
				lda #$11
				sta $d6e5
				;initialise MAC address in controller and header
				ldx #size(Command.network_status.mac_address)
				ldz #$ff
-				lda Command.network_status.mac_address-1,x 
				sta header.source_mac_addr-1,x
				stz header.dest_mac_addr-1,x
				sta $d6e9-1,x
				dex
				bne -

				;Clear counters
				stx pkt_error_cnt
				stx pkt_error_cnt+1
				stx total_rx_bytes
				stx total_rx_bytes+1
				stx total_rx_bytes+2
				stx total_rx_bytes+3
				stx total_tx_bytes
				stx total_tx_bytes+1
				stx total_tx_bytes+2
				stx total_tx_bytes+3

				;Set default TX DMA List parameters (these values should not change)
				;Set 32bit Base Page pointer to TX/RX Ethernet buffer
				lda #ETHER_BUFFER_ADDR[0:8]
				sta ether_buff_ptr
				lda #ETHER_BUFFER_ADDR[8:16]
				sta ether_buff_ptr+1
				lda #ETHER_BUFFER_ADDR[16:24]
				sta ether_buff_ptr+2
				lda #ETHER_BUFFER_ADDR[24:32]
				sta ether_buff_ptr+3
				stx dma_list_tx.data1
				stx dma_list_tx.end_opt_list
				stx dma_list_tx.command_l
				stx dma_list_tx.command_h
				stx dma_list_tx.modulo_l
				stx dma_list_tx.modulo_h
				lda #$80
				sta dma_list_tx.option1
				stx dma_list_tx.data1
				lda #$81
				sta dma_list_tx.option2
				lda #ETHER_BUFFER_ADDR[20:28]
				sta dma_list_tx.data2
				lda #ETHER_BUFFER_ADDR[16:20]
				sta dma_list_tx.dest_bank

				;Set default RX DMA List parameters (these values should not change)
				stx dma_list_rx.data1
				stx dma_list_rx.end_opt_list
				stx dma_list_rx.command_l
				stx dma_list_rx.command_h
				stx dma_list_rx.modulo_l
				stx dma_list_rx.modulo_h
				lda #$80
				sta dma_list_rx.option1
				lda #ETHER_BUFFER_ADDR[20:28]
				sta dma_list_rx.data1	
				lda #$81
				sta dma_list_rx.option2
				stx dma_list_rx.data2
				lda #ETHER_BUFFER_ADDR[16:20]
				sta dma_list_rx.source_bank
				rts

;**************************************************
;**************************************************
;Build new Ethernet frame (Max data size $5ff)
;Registers:
; A = > protocol type
; X = < protocol type
; Z = > data size
;Header:
; header.dest_mac_addr
; header.ether_type
;Return TX buffer position for data in A
; C = Clear
; A = next TX buffer position, 0 = error (data size to large)
;
;**************************************************
					;Check data size
new_ether_frame		cpz #>MAX_DATA_SIZE
					bcc +
					lda #0
					rts

					;Set ether type & MAC address
+					sta header.ether_type
					stx header.ether_type+1
					ldx #6-1
-					lda Command.command_list.ether_dest_mac,x
					sta header.dest_mac_addr,x
					dex
					bpl -
					;Set DMA List parameters to copy Ethernet
					;header into TX buffer					
					lda #ETHER_HEAD_SIZE
					sta dma_list_tx.count_l
					lda #0
					sta dma_list_tx.count_h
					lda #<header
					sta dma_list_tx.source_addr_l
					lda #>header
					sta dma_list_tx.source_addr_h
					ldy #BANK
					sty dma_list_tx.source_bank
					lda #ETHER_BUFFER_ADDR[0:8]
					sta dma_list_tx.dest_addr_l
					lda #ETHER_BUFFER_ADDR[8:16]
					sta dma_list_tx.dest_addr_h
					sty $d702
					lda #>dma_list_tx
					sta $d701
					lda #<dma_list_tx
					sta $d705	;Enhanced DMA job
					;Return amount of data copied into TX buffer
					lda #ETHER_HEAD_SIZE
					rts

;**************************************************
;**************************************************
;Send an Ethernet frame with data
;Command List:
; ether_dest_mac
; ether_protocol
; data_size
; data_addr
; data_bank
;Return
; A = next TX buffer position, 0 = error (data size to large)
; 
;**************************************************
					;Set TX timeout
EtherSend			lda #StMachine.ST_TX_BUSY
					jsr StMachine.SetEvent
					;Get Ethernet protacol type
					lda Command.command_list.ether_protocol
					ldx Command.command_list.ether_protocol+1
					;Get data parameters				
					ldz Command.command_list.data_size+1
					jsr new_ether_frame
					beq +
					rts
+					jmp StMachine.ErrorEvent

;**************************************************
;**************************************************
;Create Ethernet header
;Registers:
; A = > protocol type
; X = < protocol type
; Z = > data size
;Command List:
; ether_dest_mac
; data_size
; data_addr
; data_bank
;Return
; A = next TX buffer position
; 
;**************************************************
NewEtherFrame		jsr new_ether_frame
					beq +
					rts
					;Show error message
+					ldz #DataTypes.MESSages.data_to_large
					rts

;**************************************************
;**************************************************
;Add data to TX buffer and send
; A = Buffer start offset
;Command List:
; data_size
; data_addr
; data_bank 
; 
;**************************************************
AddDataSend			tax
					clc
					adc #ETHER_BUFFER_ADDR[0:8]
					sta dma_list_tx.dest_addr_l
					lda #ETHER_BUFFER_ADDR[8:16]
					adc #0
					sta dma_list_tx.dest_addr_h
					lda Command.command_list.data_size
					sta dma_list_tx.count_l
					lda Command.command_list.data_size+1
					sta dma_list_tx.count_h
					lda Command.command_list.data_addr
					sta dma_list_tx.source_addr_l
					lda Command.command_list.data_addr+1
					sta dma_list_tx.source_addr_h
					lda Command.command_list.data_bank
					sta dma_list_tx.source_bank
					lda #BANK
					sty $d702
					lda #>dma_list_tx
					sta $d701
					lda #<dma_list_tx
					sta $d705	;Enhanced DMA job

					;Set data size in TX buffer and send Ethernet Packet
					txa
					clc
					adc Command.command_list.data_size
					tax
					sta $d6e2
					lda Command.command_list.data_size+1
					adc #0
					sta $d6e3
					;check for packet minimum size
					sta temp_bp
					lda #>ETHER_MIN_SIZE
					cmp temp_bp
					bcc +
					txa
					cmp #<ETHER_MIN_SIZE
					bcs +
					lda #<ETHER_MIN_SIZE
					sta $d6e2
					lda #>ETHER_MIN_SIZE
					sta $d6e3
	;TODO Fill padding with $00
+					lda #$01
					sta $d6e4
					rts

;**************************************************
;**************************************************
;Process received Ethernet packet
;Return
; X = Offset to Ethernet packet data in RX buffer
; 
;**************************************************
PacketReceived		ldx #ETHER_RX_PKT_SIZE
					;Get ether type from Ethernet header
					ldz #ETHER_RX_PKT.ethernet_header.ether_type
					lda [ether_buff_ptr],z
					inz
					cmp #$08
					bne ++
					;Ether type $0800
					lda [ether_buff_ptr],z
					bne +
					jmp IPv4.ReceivedPacket
					;ether type $0806
+					cmp #$06
					bne +
					jmp ARP.ReceivedPacket
+					rts

;**************************************************
;**************************************************
;Copy receved data to specified RAM
; A = Offset from begining of packet
; X = Copy count, 0 = copy to end of packet
; RXDestAddrL = Destination address low byte
; RXDestAddrH = Destination address high byte
; RXDestBank = Destination BANK
; 
;**************************************************
CopyRXData			sta temp_bp
					txa
					beq +
					sta dma_list_rx.count_l
					lda #0
					sta dma_list_rx.count_h
					bra ++

+					lda pkt_rx_info
					sec
					sbc temp_bp
					sta dma_list_rx.count_l
					lda pkt_rx_info+1
					and #$0f
					sbc #0
					sta dma_list_rx.count_h

+					lda #ETHER_BUFFER_ADDR[0:8]
					clc
					adc temp_bp
					;adc #2 	;two frame info bytes
					sta dma_list_rx.source_addr_l
					lda #ETHER_BUFFER_ADDR[8:16]
					sta dma_list_rx.source_addr_h
					lda #BANK
					sta $d702
					lda #>dma_list_rx
					sta $d701
					lda #<dma_list_rx
					sta $d705	;Enhanced DMA job
					rts
					
				.send