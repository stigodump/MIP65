
		.section base_page_ram
conn_status			.fill 1
conn_tmr			.fill 1
		.send

;**************************************************************
		.section rom_code

;**************************************************
;**************************************************
;Initialise MIIM
; 
;**************************************************
Initialise			lda #0
					sta conn_status
					lda #3
					sta conn_tmr
					rts 

;**************************************************
;**************************************************
;Check connection status and call event if it changes
; 
;**************************************************
					;Read Basic Status register
SetConStatus		lda #1
					tsb $d6e6
					;Get connection State
					lda $d6e7
					and #%00100000
					tax
					eor conn_status
					bne +
					lda #3
					sta conn_tmr
					rts
					;Changed
+					dec conn_tmr
					beq +
					rts
+					stx conn_status
					;Connection status changed
					bbr 5,conn_status,StMachine.DisConnEvent
					jmp StMachine.ConnectionEvent
					
		.send