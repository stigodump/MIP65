TIMERA_COUNT		= 1000
TIMERB_COUNT		= 1000

TIMERA_L			= $dd04
TIMERA_H			= $dd05
TIMERB_L			= $dd06
TIMERB_H			= $dd07
timer_ms			= TIMERB_L


				.section base_page_ram
timer_sec			.fill 2
				.send

				.section rom_code
;**************************************************
;**************************************************
;Initialise MAC address and DMA list
;Command List:
; mac_address
; 
;**************************************************

Initialise			lda #<TIMERA_COUNT
					sta TIMERA_L
					lda #>TIMERA_COUNT
					sta TIMERA_H
					lda #<TIMERB_COUNT
					sta TIMERB_L
					lda #>TIMERB_COUNT
					sta TIMERB_H
					lda #%10010001
					sta $dd0e
					lda #%01010001
					sta $dd0f
					;lda #%00011111
					;sta $dc0d
					;lda #%10000010
					;sta $dc0d
					rts

				.send