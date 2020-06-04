	NAME	LED_BITS

;
; Bit manipulation routines for PCA9551 LED controller (for 87C51 and variants)
; =============================================================================
;
; Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
;
; This software is licensed under the MIT license (see LICENSE.TXT)
;
; Useful assembly routines for converting "on" and "flash"
; bitmaps into interleaved bits in pair of bytes for PCA9551
;
; See README.md for information on typical usage
;
; Stack usage:
;
;	 4 bytes in foreground (any function call)
;

; Segments

?PR?LED_BITS	SEGMENT CODE


; SUBROUTINES
; -----------

;
; Calculate LED bits
; ------------------
;
; Prototype:	void led_bits_calc(byte bmap_on, byte bmap_flash, byte idata *pair);
;
; Purpose:	Calculates bits in pair of bytes from input bitmaps and returns the
;               result in locations pointed to by 'pair'
;
; Mechanism:	1. Process low nibble of "on" bitmap
;		2. Process low nibble of "flash" bitmap and interleave result
;		3. Process high nibble of "on" bitmap
;		4. Process high nibble of "flash" bitmap and interleave result
;
; Run Time:	79 cycles always
; Latency:	None
;

		PUBLIC	_LED_BITS_CALC

		RSEG	?PR?LED_BITS

_LED_BITS_CALC:					; (2) LCALL _LED_BITS_CALC
		MOV	A,R3			; (1) Move pointer to R0
		MOV	R0,A			; (1) <-
		;
		MOV	A,R7			; (1) Get inverted ON bitmap
		CPL	A			; (1) <-
		LCALL	SPLIT_LO		; (x) Process low nibble
		MOV	@R0,A			; (1) Save result
		;
		MOV	A,R5			; (1) Get FLASH bitmap
		LCALL	SPLIT_LO		; (x) Process low nibble
		RL	A			; (1) Interleave new bits
		ORL	A,@R0			; (1) <-
		MOV	@R0,A			; (1) Save result
		;
		INC	R0			; (1) Point to second byte
		;
		MOV	A,R7			; (1) Get inverted ON bitmap
		CPL	A			; (1) <-
		LCALL	SPLIT_HI		; (x) Process high nibble
		MOV	@R0,A			; (1) Save result
		;
		MOV	A,R5			; (1) Get FLASH bitmap
		LCALL	SPLIT_HI		; (x) Process high nibble
		RL	A			; (1) Interleave new bits
		ORL	A,@R0			; (1) <-
		MOV	@R0,A			; (1) Save result
		;
		RET				; (2) All done


;
; Split nibble into alternate bits
; --------------------------------
;
; Prototype:	None (local routines only)
;
; Purpose:	Enter with ACC = xxxDCBA (SPLIT_LO) or DCBAxxxx (SPLIT_HI)
;		Exits with ACC = DxCxBxAx
;
; Mechanism:	Brute-force bit manipulations
;
; Run Time:	14 cycles always (SPLIT_LO) or 15 cycles always (SPLIT_HI)
; Latency:	None
;

		RSEG	?PR?LED_BITS

SPLIT_HI:					; (2) LCALL SPLIT_HI
		SWAP	A			; (1) Move high nibble to low
						;(-2) -- Fall through --
SPLIT_LO:					; (2) LCALL SPLIT_LO
		MOV	C,ACC.3			; (1) Copy bit 3 to bit 6
		MOV	ACC.6,C			; (1) <-
		;
		MOV	C,ACC.2			; (1) Copy bit 2 to bit 4
		MOV	ACC.4,C			; (1) <-
		;
		MOV	C,ACC.1			; (1) Copy bit 1 to bit 2
		MOV	ACC.2,C			; (1) <-
		;
		ANL	A,#01010101B		; (1) Clear unwanted bits
		;
		RET				; (2) All done


		END
