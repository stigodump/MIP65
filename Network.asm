NETWORK_DISCONNECTED	= 0
NETWORK_DHCP			= 1
NETWORK_STATIC			= 2

				.section rom_code
;**************************************************
;**************************************************
;Initialise Network parameters
;
;**************************************************
Initialise			lda #BANK
					sta $d702
					lda #>dma_ip_fill
					sta $d701
					lda #<dma_ip_fill
					sta $d700
					rts

;**************************************************
;**************************************************
;Set network status IP addresses to 0.0.0.0
; 
;**************************************************
						;DMA job to clear network status
dma_ip_fill			.byte %00000011				;command low byte: FILL
					.word Command.network_status.status-Command.network_status.ip_address+1	;fill count
					.word 0						;source address
					.byte 0						;source Bank
					.word Command.network_status.ip_address	;destination address
					.byte BANK					;destination Bank
					.byte 0						;command hi byte
					.word 0						;modulo

				.send