	NAME	SERIAL

	$INCLUDE (PORTS.INC)

;
; Serial I/O Routines for 87C51 and variants
; ==========================================
;
; Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
;
; This software is licensed under the MIT license (see LICENSE.TXT)
;
; Provides asymmetric buffer routines for asynchronous serial I/O
; (receiver has multi-byte buffer, transmitter has only one byte)
; with hardware RTS/CTS flow control
;
; This is useful for communicating with devices that accept short
; commands but give lengthy responses in quick time
; 
; Note: This version resets bit 7 of all received characters (see @@)
;
; See README.md for information on typical usage

; Stack usage:
;
;	 5 bytes in background (low priority interrupt)
;	 2 bytes in foreground (any function call)
;

; Segments

?DT?SERIAL	SEGMENT	DATA
?ID?SERIAL	SEGMENT	IDATA
?BI?SERIAL	SEGMENT	BIT
?PR?SERIAL	SEGMENT CODE

; Serial port values (choose to suit application)

RL_SIZ		EQU	32			; Size of RX buffer

RL_BUF_LO	EQU	8			; RTS "Low water" mark
RL_BUF_HI	EQU	RL_SIZ-RL_BUF_LO	; RTS "High water" mark

SL_MODE		EQU	01010000B		; 8 data bits, no parity

; Internal variables

		RSEG	?DT?SERIAL

RL_CNT:		DS	1			; Count of chars in RX buffer
RL_WPT:		DS	1			; Write pointer in RX buffer

		RSEG	?ID?SERIAL

RL_BUF:		DS	RL_SIZ			; Allocate RX buffer

RL_END		EQU	RL_BUF+RL_SIZ		; End of buffer marker

		RSEG	?BI?SERIAL

TL_DIR:		DBIT	1			; Transmit direct to UART

RL_DIS:		DBIT	1			; Receive handshake disabled
RL_RDY:		DBIT	1			; Receive buffer ready (not empty)
RL_OVF:		DBIT	1			; Receive buffer overflow

; Externally visible variables

SERIAL_TX_READY		EQU	TL_DIR
SERIAL_RX_READY		EQU	RL_RDY
SERIAL_RX_OVERFLOW	EQU	RL_OVF

		PUBLIC	SERIAL_TX_READY		; For C code main routines
		PUBLIC	SERIAL_RX_READY
		PUBLIC	SERIAL_RX_OVERFLOW


;
; Serial Interrupt Routine
; ------------------------
;
; Purpose:	Handles transmitter and/or receiver interrupts
;
; Mechanism:	1. Save affected registers
;		2. Act on TX and/or RX interrupt
;		3. Restore affected registers
;
;		TX  1. Indicate direct send
;
;		RX  1. If framing error occurred then map char to FE hex
;		RX  2. If buffer is full, ignore new character, ELSE ..
;		RX  3. Increment buffer count
;		RX  4. If RTS enabled and above high water mark, disable RTS
;		RX  5. Get character from UART and put in in buffer
;		RX  6. Increment buffer pointer and indicate ready
;
; Run Time:	54 cycles MAX,  47 cycles TYP,  25 cycles MIN
; Latency:	None for higher priority interrupts
;
; Destroys:	None (!)
;

		CSEG	AT 0023H
						; (2) Interrupt "LCALL"
		LJMP	SER_INT			; (2) Jump to main routine

		RSEG	?PR?SERIAL
		USING	0

SER_INT:	PUSH	PSW			; (2) Save altered regs
		PUSH	ACC			; (2) <-
		PUSH	AR0			; (2) <-
		;
SER_LPT:	JBC	TI,TL_INT		; (2) If transmitter empty
SER_LPR:	JBC	RI,RL_INT		; (2) If receiver activated
		;
		POP	AR0			; (2) Restore regs
		POP	ACC			; (2) <-
		POP	PSW			; (2) <-
		;
		RETI				; (2) Exit
;
;
TL_INT:		SETB	TL_DIR			; (1) Signal direct send
		SJMP	SER_LPR			; (2) All done
;
;
RL_INT:		MOV	A,SBUF			; (1) Get character
		JB	RB8,RL_CHK		; (2) If not valid stop bit ..
		MOV	A,#0FEH			; (1) .. map to framing error
		;
RL_CHK:		XCH	A,RL_CNT		; (1) Swap with buffer count
		CJNE	A,#RL_SIZ,RL_RTS	; (2) If buffer is full ..
		XCH	A,RL_CNT		; (1) .. ignore it
		SETB	RL_OVF			; (1) .. flag error
		SJMP	SER_LPT			; (2) .. done
;
RL_RTS:		INC	A			; (1) Increase buffer count
		JB	RL_DIS,RL_CHR		; (2) Jump if already disabled
		CJNE	A,#RL_BUF_HI,$+3	; (2) Else see if high water
		JC	RL_CHR			; (2) Jump if not
		SETB	RL_DIS			; (1) Indicate disabled
		SETB	N_RTS			; (1) Disable handshake line
		;
RL_CHR:		XCH	A,RL_CNT		; (1) Swap back buffer count
		MOV	R0,RL_WPT		; (2) Get buffer pointer
		MOV	@R0,A			; (1) Put character
		MOV	A,R0			; (1) Increment and wrap
		INC	A			; (1) <-
		CJNE	A,#RL_END,RL_STO	; (2) <-
		MOV	A,#RL_BUF		; (1) <-
		;
RL_STO:		MOV	RL_WPT,A		; (1) Save buffer pointer
		SETB	RL_RDY			; (1) Buffer not empty now
		SJMP	SER_LPT			; (2) Done


;
; Initialise Serial I/O
; ---------------------
;
; Prototype:	void init_serial(unsigned char period);
;
; Purpose:	Initialises serial I/O variables and hardware 
;
; Mechanism:	1. Disable serial interrupts and RTS
;		2. Initialise transmit variables
;		3. Set up UART and baud rate from period
;		4. Initialise receive variables and enable RTS
;		5. Enable serial interrupts
;
; Run Time:	44 cycles always
; Latency:	39 cycles always
;
; Destroys:	ACC, PSW
;

		PUBLIC	_INIT_SERIAL

		RSEG	?PR?SERIAL

_INIT_SERIAL:					; (2) LCALL _INIT_SERIAL
		;
		CLR	EA			; (1) All interrupts OFF
		;
		CLR	ES			; (1) Serial interrupt OFF
		CLR	PS			; (1) .. low priority 
		CLR	ET1			; (1) Timer 1 interrupt OFF
		CLR	PT1			; (1) .. low priority
		CLR	TR1			; (1) Stop Timer 1
		;
		SETB	N_RTS			; (1) Disable RTS output
		;
		SETB	TL_DIR			; (1) Send direct to UART
		;
		MOV	SCON,#SL_MODE		; (2) Set data format
		ANL	TMOD,#00001111B		; (2) Set auto-reload Timer 1
		ORL	TMOD,#00100000B		; (2) <-
		ORL	PCON,#10000000B		; (2) Set SMOD bit
		;
		MOV	A,R7			; (1) Set baud rate
		CPL	A			; (1) <-
		INC	A			; (1) <-
		MOV	TH1,A			; (1) <-
		MOV	TL1,A			; (1) <-
		SETB	TR1			; (1) Start timer 1
		;
		CLR	TI			; (1) Clear pending interrupts
		CLR	RI			; (1) <-
		;
		LCALL	FLUSH_SERIAL_INPUT	;(14) Set up receiver
		;
		SETB	ES			; (1) Serial interrupt ON
		SETB	EA			; (1) All interrupts ON
		;
		RET				; (2) Finished


;
; Flush Serial Input Buffer
; -------------------------
;
; Prototype:	void flush_serial_input(void);
;
; Purpose:	Empties serial input buffer and re-enables RTS (if false)
;
; Mechanism:	1. Disable serial interrupts
;		2. Initialise receive variables and RTS
;		3. Re-enable serial interrupts
;
; Run Time:	14 cycles always
; Latency:	9 cycles always
;
; Destroys:	ACC, PSW
;

		PUBLIC	FLUSH_SERIAL_INPUT

		RSEG	?PR?SERIAL

FLUSH_SERIAL_INPUT:				; (2) LCALL FLUSH_SERIAL_INPUT
		;
		CLR	ES			; (1) Disable serial ints
		;
		MOV	RL_WPT,#RL_BUF		; (2) Set RX buffer pointer
		MOV	RL_CNT,#0		; (2) Clear RX buffer count
		;
		CLR	RL_RDY			; (1) RX buffer is empty
		CLR	RL_OVF			; (1) No receive overflow
		;
		CLR	RL_DIS			; (1) RTS line NOT disabled
		CLR	N_RTS			; (1) Enable RTS output
		;
		SETB	ES			; (1) Re-enable serial ints
		RET				; (2) Finished


;
; Output serial character
; -----------------------
;
; Prototype:	bit put_serial_char(char ch);
;
; Purpose:	Sends character to serial output (directly)
;
; Mechanism:	1. If CTS is false then return failure result (0)
;		2. If UART TX is busy then return failure result (0)
;		3. Otherwise, put character in UART TX register and
;		   return success result (1)
;
; Run Time:	15 cycles MAX, 9 cycles MIN
; Latency:	9 cycles MAX, 3 cycles MIN
;
; Destroys:	ACC, PSW
;

		PUBLIC	_PUT_SERIAL_CHAR

		RSEG	?PR?SERIAL

_PUT_SERIAL_CHAR:				; (2) LCALL _PUT_SERIAL_CHAR
		;
		CLR	C			; (1) Assume failure
		CLR	ES			; (1) Disable serial ints
		;
		JB	N_CTS,TC_DONE		; (2) Fail if CTS is false ..
		JNB	TL_DIR,TC_DONE		; (2) .. or UART TX is busy 
		;
		CLR	TL_DIR			; (1) Clear direct send flag
		;
TC_DIR:		MOV	SBUF,R7			; (2) Send direct to UART
		SETB	C			; (1) Indicate success
		;
TC_DONE:	SETB	ES			; (1) Re-enable serial ints
		RET				; (2) Done


;
; Input serial character
; ----------------------
;
; Prototype:	char get_serial_char(void);
;
; Purpose:	Receives character from serial input (via buffer)
;
; Mechanism:	1. If buffer is empty, return failure result (0), ELSE ..
;		2. Get character and increment buffer pointer
;		3. Decrement buffer count and signal not ready if empty
;		4. If RTS disabled and below low water mark, enable RTS
;
; Run Time:	35 cycles MAX, 31 cycles TYP, 7 cycles MIN
; Latency:	27 cycles MAX, 23 cycles TYP, 0 cycles MIN
;
; Destroys:	ACC, PSW, R0, R7 (return value)
;

		PUBLIC	GET_SERIAL_CHAR

		RSEG	?PR?SERIAL

GET_SERIAL_CHAR:				; (2) LCALL GET_SERIAL_CHAR
		;
		MOV	R7,#0			; (1) Fail if no buffer entry
		JNB	RL_RDY,RC_EXIT		; (2) <-
		;
		CLR	ES			; (1) Disable ser interrupts
		;
		MOV	A,RL_WPT		; (1) Get buffer pointer
		CLR	C			; (1) <-
		SUBB	A,RL_CNT		; (1) <-
		CJNE	A,#RL_BUF,$+3		; (2) Correct wrap-around
		JNC	RC_GET			; (2) <-
		ADD	A,#RL_SIZ		; (1) <-
		;
RC_GET:		MOV	R0,A			; (1) Get character
		MOV	A,@R0			; (1) <-
		CLR	ACC.7			; (1) Remove parity bit (@@)
		MOV	R7,A			; (1) Return value
		;
RC_NUM:		MOV	A,RL_CNT		; (1) Check buffer count
		DEC	A			; (1) Reduce it
		JNZ	RC_RTS			; (2) Jump if any chars left
		CLR	RL_RDY			; (1) Else signal buffer empty
		;
RC_RTS:		JNB	RL_DIS,RC_DONE		; (2) Jump if already enabled
		CJNE	A,#RL_BUF_LO,$+3	; (2) Else see if low water 
		JNC	RC_DONE			; (2) Jump if not
		CLR	RL_DIS			; (1) Indicate enabled
		CLR	N_RTS			; (1) Enable handshake line
		;
RC_DONE:	MOV	RL_CNT,A		; (1) Swap back buffer count
		SETB	ES			; (1) Enable ser interrupts
		;
RC_EXIT:	RET				; (2) Done


		END
