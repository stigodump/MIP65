				.section base_data_ram
page_alloc			.fill 256
				.send

				.section ram_data
start_page			.fill 1
last_page			.fill 1
max_available		.fill 1
block_key			.fill 1
mem_bank			.fill 1
need_blocks			.fill 1
dma_fill			.dstruct DataTypes.DMA_LIST_B
				.send 

				.section rom_code
;**************************************************
;**************************************************
;Initialise memory to manage up to 64K (256 pages)
; A = Start page of memory block (inclusive)
; X = Last page of memory block (inclusive)
; Y = Which bank memory is in
; 
;**************************************************
Initialise			sta start_page
					stx last_page
					sty mem_bank

					;Set dama_fill default parameters
					ldx #size(dma_fill)
-						lda dma_clr,x
					sta dma_fill,x 
					dex
					bpl -

					;Clear page allocation table
					lda #BANK
					sta $d702
					lda #>dma_clr
					sta $d701
					lda #<dma_clr
					sta $d700
					ldx #1
					stx BASE_DATA_RAM+1
					lda start_page

;**************************************************
;**************************************************
;Free memory for reuse
; A = page pointer to first page in block
; 
;**************************************************
FreeMemory			cmp start_page
					bmi no_mem		;< start
					cmp last_page
					bmi +			;< last
					bne no_mem		;> last
+					tax

					;Set Base Page to page allocation table
					tba
					pha
					lda #>BASE_DATA_RAM
					tab

					;Free memory block starting at page in X
					ldy #0
					lda page_alloc,x
					bpl +
-					sty page_alloc,x
					inx
					cmp page_alloc,x
					beq -
					
					;Mark all free pages in page allocation table
					;Calculate largest continues block of memory
+					sty max_available
					ldx last_page
					bra +

-					sty page_alloc,x						
					iny
					bpl chk_end
					sty max_available
					dey
chk_end				cpx start_page
					beq exit_bp
					dex
					cpy max_available
					bcc +
					sty max_available
+					lda page_alloc,x
					bpl -
					ldy #0
					bra chk_end
exit_bp				pla 
					tab
no_mem 				rts

;**************************************************
;**************************************************
;Allocate continues block of memory up to 32KB
;in 256B pages
; A = Amount of pages requested, $20 = 8192bytes
; X = Memory fill value
; Y 1 = fill, 0 = no fill
;Return
; Z 0 = OK, -1 = error not enough memory
; Y Pointer to first page of allocated memory block
; X Memory bank of allocated memory
; 
;**************************************************
AllocMemory			ldz #$ff			;return error value
					stx dma_fill.source_addr_h
					sta need_blocks
					lda max_available
					cmp need_blocks
					bmi no_mem			;Asking for more than available

					;Set Base Page to page allocation table
					tba
					pha
					lda #>BASE_DATA_RAM
					tab

					;Find first page of requested memory
					ldx start_page
					dex
-					inx
					lda page_alloc,x
					bmi -
					inc a
					cmp need_blocks
					bmi	-
					phy
					txa
					tay

					;Allocate requested amount of pages
					ldz need_blocks
					lda block_key
					ora #%10000000
-					sta page_alloc,x
					inx
					dez
					bne -
					inc block_key

					;Calculate largest continues block of memory
					stz max_available
					bra +
-					inx
					beq	end_find_max
+					lda page_alloc,x
					bmi -
					cmp max_available
					bcc -
					sta max_available
					bra -
end_find_max		inc max_available
					ldx mem_bank
					;Does memory need to be filled
					pla
					beq exit_bp
					lda need_blocks
					sta dma_fill.count_h
					sty dma_fill.dest_addr_h
					lda #0
					sta dma_fill.source_addr_l
					sta dma_fill.count_l
					sta dma_fill.dest_addr_l
					stx dma_fill.dest_bank
					lda #BANK
					sta $d702
					lda #>dma_fill
					sta $d701
					lda #<dma_fill
					sta $d700
					;Restore Base Page
					pla 
					tab
					ldz #0
					rts

;DMA job to clear page allocation table
dma_clr				.byte %00000011			;command low byte: FILL
					.word size(page_alloc)	;1 page 256 bytes
					.word 0					;fill value
					.byte 0					;source Bank
					.word BASE_DATA_RAM		;destination address
					.byte BANK				;destination Bank
					.byte 0					;command hi byte
					.word 0					;modulo
		
				.send 
