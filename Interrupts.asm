EXIT_IRQ			= $f9b4
SYS_IRQ 			= $f95c
EXIT_NMI			= $f9bb
SYS_NMI				= $f925
KEYBOARD_ROW		= $dc01

		.section zero_page
int_flags	.fill 1
		.send

		.section rom_code
;**************************************************
;**************************************************
;Initialise system IRQ interrupt vector
;and activate Ethernet TX and RX interrupts
; 
;**************************************************
Initialise		lda #BANK
				sta $d702
				lda #>dma_int_wedge
				sta $d701
				lda #<dma_int_wedge
				sta $d700
				lda #<IRQInterrupt
				sta $0314
				lda #>IRQInterrupt
				sta $0315
				lda #<NMIInterrupt
				sta $0318
				lda #>NMIInterrupt
				sta $0319

				lda #%11000000
				sta $d6e1
				lda #%00000011
				sta $d6e0
				rts

dma_int_wedge 	.byte %00000000 				;command low byte: COPY
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
eth_rx_int		lda #$01
				sta $d6e1
				lda #$03
				sta $d6e1
				;Get received data size low byte
				ldz #Ethernet.ETHER_RX_PKT.packet_info
				#lda32z Ethernet.ether_buff_ptr
				sta Ethernet.pkt_rx_info
				;Total bytes received uodate
				clc
				adc Ethernet.total_rx_bytes
				sta Ethernet.total_rx_bytes
				;Get received data size high byte
				inz
				#lda32z Ethernet.ether_buff_ptr
				sta Ethernet.pkt_rx_info+1
				;Total bytes received update
				and #$0f
				adc Ethernet.total_rx_bytes+1
				sta Ethernet.total_rx_bytes+1
				bcc +
				inw Ethernet.total_rx_bytes+2
+				lda Ethernet.pkt_rx_info+1
				;Check for CRC error
				bmi +	;CRC error
				jmp Ethernet.PacketReceived

+				inw Ethernet.pkt_error_cnt
				rts

;**************************************************
;**************************************************
;Interrupt entry point for packet transmitted
; 
;**************************************************
eth_tx_int 		lda $d6e2
				clc
				adc Ethernet.total_tx_bytes
				sta Ethernet.total_tx_bytes
				lda $d6e3
				adc Ethernet.total_tx_bytes+1
				sta Ethernet.total_tx_bytes+1
				bcc +
				inw Ethernet.total_tx_bytes+2
+				jsr StMachine.TXEvent
				rts

;**************************************************
;**************************************************
;Entry point for Second timer
; 
;**************************************************
				;Increment second timer 32bit
timer_int		inw Timer.timer_sec
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
wedge		.logical WEDGE_CODE
				;NMI entry point
NMIInterrupt	bit KEYBOARD_ROW
				bmi +
				lda #0
				sta $d6e0
				sta NMIInterrupt+1
+				jmp SYS_NMI
				;IRQ entry point
IRQInterrupt	lda $dd0d
				and #%00000010
				sta int_flags
				bne not_raster
				lda $d019
				bpl not_raster
do_sys_irq		jmp SYS_IRQ
				;MAP $4000 to $7fff from bank 4
not_raster		lda #$00
				ldx #$c4
				ldy $011e
				ldz $011f
				map
				;Set Base Page pointer
				tba
				pha
				lda #>BASE_PAGE_RAM
				tab
				eom

				bbr 1,int_flags,+
				jsr Interrupts.timer_int
				
				;Check for Ethernet interrupts
+				lda $d6e1
				bpl ++
				sta int_flags
				bbr 5,int_flags,+
				jsr Interrupts.eth_rx_int
+				bbr 4,int_flags,+
				jsr Interrupts.eth_tx_int
+				lda int_flags
				and #$f0 
				sta $d6e1

				;Restore MAP
				lda $011c
				ldx $011d
				ldy $011e
				ldz $011f
				map
				pla 
				tab
				eom
				jmp EXIT_IRQ
			.here
		.send