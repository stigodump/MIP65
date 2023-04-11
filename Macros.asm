lda32z		.macro
				.byte $ea
				.byte $b2
				.byte \1
			.endmacro

sta32z		.macro
				.byte $ea
				.byte $92
				.byte \1
			.endmacro
eor32z		.macro
				.byte $ea
				.byte $52
				.byte \1
			.endmacro