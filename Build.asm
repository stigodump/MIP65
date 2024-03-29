;******************************************************************
;
; Ethernet test
;
;	Auther: R Welbourn
;	Discord: Stigodump
;	Date: 30/01/2023
;	Assembler: 64TAS Must be at least build 2625
;	64tass-1.56.2625\64tass.exe -a Build.asm -o Build.prg --tab-size=4
;	Platform: MEGA65 R3 
;
;******************************************************************

;Target CPU
	.cpu "4510"
ZERO_PAGE			= $fb
BASIC_CODE			= $2001

;Code for interrupt and code entery points in common ram
WEDGE_CODE			= $1600

;Working BANK for code and data below
BANK				= 4

;8K block for data and code
MAIN_DATA_RAM		= $4000
BASE_DATA_RAM		= $4200	
BASE_PAGE_RAM		= $4300	
MAIN_CODE_ROM		= $4400
MEM_END				= $5fff

;8K block for TX/RX network packet buffer
RX_BUFFER_RAM		= $4000
RX_BUFFER_SIZE		= $2000
RX_BUFFER_BANK		= 5

* = ZERO_PAGE
	.dsection zero_page
	.cerror * > $fe, "Not enough space"

* = BASIC_CODE
	.dsection basic_code
	.cerror * > $7fff, "Not enough space"

	.section basic_code
		.word (+), 10
		.byte $fe,$02,$30,$00        			;10 BANK0
+		.word (+), 20
		.text $9e, format("%4d", start), $00	;20 SYS start
+		.word 0									;end of BASIC
	
				;Set DMAgic to F018B
start			lda #%00000001
				tsb $d703
				;Copy MAIN_CODE to $44000 which will be mapped to $04000
				lda #0
				sta $d702
				lda #>dma_copy
				sta $d701
				lda #<dma_copy
				sta $d700
				lda #0
				sta WEDGE_CODE+1
				rts

				;DMA job to copy rom_code
dma_copy 		.byte %00000000 				;command low byte: COPY
				.word size(copy_code)			;copy count
				.word copy_code 				;source address
				.byte 0							;source Bank
				.word MAIN_CODE_ROM				;destination address
				.byte BANK						;destination Bank
				.byte 0							;command hi byte
				.word 0							;modulo

;**************************************************************
			.include "Macros.asm"

			;Code and Data
			.virtual MAIN_DATA_RAM
			.dsection ram_data
			.cerror * > BASE_DATA_RAM - 1, "RAM error"
			.endv

			.virtual <BASE_DATA_RAM
			.dsection base_data_ram
			.cerror * > BASE_PAGE_RAM - 1, "Base data RAM error"
			.endv

			.virtual <BASE_PAGE_RAM
			.dsection base_page_ram
			.cerror * > MAIN_CODE_ROM - 1, "Base page RAM error"
			.endv

copy_code	.logical MAIN_CODE_ROM
			.dsection rom_code
			.cerror * > MEM_END, "ROM error"
			.here
		
DataTypes	.binclude "DataTypes.asm"
Command 	.binclude "Command.asm"
Initialise	.binclude "Initialise.asm"
Network     .binclude "Network.asm"
MIIM		.binclude "MIIM.asm"
StMachine	.binclude "StateMachine.asm"
Memory		.binclude "Memory.asm"
Timer 		.binclude "Timer.asm"
Interrupts	.binclude "Interrupts.asm"
Ethernet	.binclude "Ethernet.asm"
IPv4		.binclude "IPv4.asm"
UDP			.binclude "UDP.asm"
ARP			.binclude "ARP.asm"
DHCP		.binclude "DHCP.asm"

	.send


