
		.section rom_code

;**************************************************
;**************************************************
;Initialise all modules if not already initialised. 
; 
;**************************************************
Initialise		sei
				;Is already initialised
				lda Interrupts.NMIInterrupt+1
				cmp #<Interrupts.KEYBOARD_ROW
				bne +
				lda Interrupts.NMIInterrupt+2
				cmp #>Interrupts.KEYBOARD_ROW
				bne +
				rts
				;Full initialisation
				;Config RX packet buffer
+				lda #>RX_BUFFER_RAM
				ldx #>(RX_BUFFER_RAM+RX_BUFFER_SIZE-$100)
				ldy #RX_BUFFER_BANK
				jsr Memory.Initialise
				;Configure stack modules
				jsr ARP.Initialise
				jsr Ethernet.Initialise
				jsr IPv4.Initialise
				jsr UDP.Initialise
				jsr DHCP.Initialise
				jsr MIIM.Initialise
				jsr Network.Initialise
				jsr StMachine.Initialise
				jsr Timer.Initialise
				jsr Interrupts.Initialise
				;Take Ethernet controller out of reset
				
				;cli
				rts

		.send