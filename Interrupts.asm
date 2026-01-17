KEYBOARD_ROW		= $dc01

ETH_TXIDLE			= %10000000
ETH_RXBLKD			= %01000000
ETH_RXQEN			= %10000000
ETH_TXQEN			= %01000000
ETH_RXQ 			= %00100000
ETH_TXQ 			= %00010000

				.section base_page_ram
				.send
	
				.section rom_code
;**************************************************
;**************************************************
;Initialise system IRQ interrupt vector
;and activate Ethernet TX and RX interrupts
; 
;**************************************************
Initialise			lda #BANK
					sta $d702
					lda #>dma_int_wedge
					sta $d701
					lda #<dma_int_wedge
					sta $d700
					lda $0314
					sta sys_irq_vect
					lda #<IRQInterrupt
					sta $0314
					lda $0315
					sta sys_irq_vect+1
					lda #>IRQInterrupt
					sta $0315
					lda $0318
					sta sys_nmi_vect
					lda #<NMIInterrupt
					sta $0318
					lda $0319
					sta sys_nmi_vect+1
					lda #>NMIInterrupt
					sta $0319
					;Enable RX interrupts
					lda #ETH_RXQEN
					sta $d6e1
					;Take Ethernet controller out of reset
					lda #%00000011
					sta $d6e0
					rts
	
dma_int_wedge 		.byte %00000000 				;command low byte: COPY
					.word size(wedge)				;copy cpount
					.word wedge 	 				;source address
					.byte BANK						;source Bank
					.word WEDGE_CODE				;destination address
					.byte 0 						;destination Bank
					.byte 0							;command hi byte
					.word 0							;modulo

;**************************************************
;**************************************************
;Interrupt entry poit for Ethernet packet received
; 
;**************************************************
					;Rotate Ethernet RX buffer
eth_rx_int			lda #$01
					sta $d6e1
					lda #$03
					sta $d6e1
					;Get received data size low byte
					ldz #Ethernet.ETHER_RX_PKT.packet_info
					lda [Ethernet.ether_buff_ptr],z
					sta Ethernet.pkt_rx_info
					;Total bytes received uodate
					clc
					adc Ethernet.total_rx_bytes
					sta Ethernet.total_rx_bytes
					;Get received data size high byte
					inz
					lda [Ethernet.ether_buff_ptr],z
					sta Ethernet.pkt_rx_info+1
					;Total bytes received update
					and #$0f
					adc Ethernet.total_rx_bytes+1
					sta Ethernet.total_rx_bytes+1
					bcc +
					inw Ethernet.total_rx_bytes+2
+					lda Ethernet.pkt_rx_info+1
					;Check for CRC error
					bmi +	;CRC error
					jmp Ethernet.PacketReceived
	
+					inw Ethernet.pkt_error_cnt
					rts

;**************************************************
;**************************************************
;Interrupt entry point for packet transmitted
; 
;**************************************************
eth_tx_int 			;lda $d6e2
					;clc
					;adc Ethernet.total_tx_bytes
					;sta Ethernet.total_tx_bytes
					;lda $d6e3
					;adc Ethernet.total_tx_bytes+1
					;sta Ethernet.total_tx_bytes+1
					;bcc +
					;inw Ethernet.total_tx_bytes+2
					jsr StMachine.TXEvent
					rts

;**************************************************
;**************************************************
;Entry point for Second timer
; 
;**************************************************
					;Increment second timer 32bit
timer_int			inw Timer.timer_sec
					jsr MIIM.SetConStatus
					jsr StMachine.TimerEvent
					rts
	
;**************************************************
;**************************************************
;Entry point for interrupts to be coppied into
;common RAM
; 
;**************************************************
				;Interupt handler to be copied
wedge			.logical WEDGE_CODE
					;NMI entry point
NMIInterrupt		bit KEYBOARD_ROW
					bmi +
					lda #0
					sta $d6e0
					sta NMIInterrupt+1
+					jmp (sys_nmi_vect)
					;IRQ entry point
IRQInterrupt		lda $dd0d
					and #%00000010
					sta tmr_flags
					bne not_raster
					lda $d019
					bpl not_raster
do_sys_irq			jmp (sys_irq_vect)
					;MAP $4000 to $5fff from bank 4
not_raster			lda #$00
					ldx #$44
					ldy $011e
					ldz $011f
					map
					;Set Base Page pointer
					tba
					pha
					lda #>BASE_PAGE_RAM
					tab
					eom
	
					lda tmr_flags
					beq +
					jsr Interrupts.timer_int
					
					;Check for Ethernet interrupts
+					;bbs StMachine.ST_TX_BUSY,StMachine.state,+
					lda $d6e0
					bpl +
					jsr Interrupts.eth_tx_int
					
+					lda $d6e1
					and #ETH_RXQ
					beq +
					jsr Interrupts.eth_rx_int
					
					lda #ETH_RXQEN | ETH_RXQ
					sta $d6e1
	
					;Restore MAP
+					lda $011c
					ldx $011d
					ldy $011e
					ldz $011f
					map
					pla 
					tab
					eom
					jmp (sys_irq_vect)
	
tmr_flags			.byte 0
sys_irq_vect		.word 0
sys_nmi_vect	 	.word 0
				.here
				.send