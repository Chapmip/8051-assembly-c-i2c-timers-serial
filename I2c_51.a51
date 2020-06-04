	NAME	I2C_51

	$INCLUDE (PORTS.INC)

;
; I2C Bus Routines for 87C51 and variants 
; =======================================
;
; Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
;
; This software is licensed under the MIT license (see LICENSE.TXT)
;
; Provides poll, read, write and compare operations for I2C slaves
; using: (a) no sub-addressing (simple peripherals such as PCF8574)
;        (b) 8-bit sub-addressing (more complex peripherals)
;    or  (c) 16-bit sub-addressing (larger memory devices)
;
; Supports "clock stretching" by I2C slaves and inactivity timeout
; (via hooks to external timer routine) to abort operation if bus
; remains inactive for too long
;
; Uses state machine approach to integrate all operations into one
; main routine with behaviour based on state variable (B register)
;
; See README.md for information on typical usage
;
; Stack usage:
;
;	6 bytes in foreground (for any top-level function call)
;

; Bit mask definitions for B register

B_LNG		EQU	B.6
B_LNG_TMP	EQU	B.5	; Always set together with B_LNG
B_POLL		EQU	B.4
B_COMP		EQU	B.3
B_READ		EQU	B.2
B_SUB		EQU	B.1
B_RD_DIR	EQU	B.0

		;	-LTPCRSD  (state bits)
I2C_PL_DIR	EQU	00010000B
I2C_PL_SUB	EQU	00010010B
I2C_WR_DIR	EQU	00000000B
I2C_WR_SUB	EQU	00000010B
I2C_WR_LNG	EQU	01100010B
I2C_RD_DIR	EQU	00000101B
I2C_RD_SUB	EQU	00000110B
I2C_RD_LNG	EQU	01100110B
I2C_CM_DIR	EQU	00001101B
I2C_CM_SUB	EQU	00001110B
I2C_CM_LNG	EQU	01101110B


; Segment definitions

?DT?I2C51	SEGMENT DATA
?BI?I2C51	SEGMENT	BIT
?PR?I2C_51?ALL	SEGMENT CODE INBLOCK


; Variables

		RSEG	?DT?I2C51

LNG_BUS_ADDR:	DS	1			; I2C bus address for actions
						; with long sub-addresses

		RSEG	?BI?I2C51

I2C_TOUT_ERR:	DBIT	1			; I2C timeout flag


; Externally visible variables

		PUBLIC	I2C_TOUT_ERR		; For C code main routines


; External dependencies

		EXTRN	BIT (I2C_TOUT)		; From "timers.a51"
		EXTRN	CODE (SET_I2C_WATCHDOG)	; From "timers.a51"


;
; I2C Bus Delay Macro
; -------------------
;
; Required delays for clock frequencies of 11.0592 MHz [A] and 18.432 MHz [B]
; are included as comments in the following source code in the format "[A/B]"
; ('*' suffix indicates that 1 extra cycle has been added to ensure that the
; SCL clock rate remains below the I2C maximum of 100 kHz).
;
; Actual clock rates/periods are: [A] <= 92 kHz or >= 10 cycles (4 high/6 low)
;				  [B] <= 96 kHz or >= 16 cycles (8 high/8 low)
;

DELAY		MACRO	N
		IF	N LE 3		;; If delay <= 3 then use in-line NOPs
		REPT	N
		NOP				; (1) Padding
		ENDM
		ELSE			;; Else use subroutine call
		ACALL	DELAY_&N		; (&N) Delay routine
		ENDIF
		ENDM


;
; Delay Subroutines
; -----------------
;

		RSEG	?PR?I2C_51?ALL

DELAY_7:	NOP				; (1) Padding
DELAY_6:	NOP				; (1) <-
DELAY_5:	NOP				; (1) <-
DELAY_4:	RET				; (2) Done


;
; I2C Bus Initialisation
; ----------------------
;
; Prototype:	bit init_i2c (void);
;
; Purpose:	Attempts to initialise the I2C bus
;		(returns 1 if successful, or 0 if the bus is jammed)
;
; Mechanism:	Special sequence to free bus of any "locked up" slaves
;
; Latency:	None
;
; Destroys:	ACC, PSW
;
; Assumptions:	Timer 0 is running and interrupt is enabled
;

		PUBLIC	INIT_I2C

		RSEG	?PR?I2C_51?ALL

INIT_I2C:					; (2) LCALL INIT_I2C
		LCALL	SET_I2C_WATCHDOG	; (x) Set up watchdog timeout
		CLR	I2C_TOUT_ERR		; (1) Clear timeout error flag
		;
		ACALL	SEND_START		; (x) Start I2C bus
		JNC	INIT_I2C_STOP		; (2) Abort if timeout
		DELAY	0		; [0/0]	; (G) > 4.7us - (G+9) cycles
		;
		MOV	R1,#9			; (1) Special bit count
		ACALL	RCVE_BYTE_LP		; (x) Clock in bits
		JNC	INIT_I2C_STOP		; (2) Abort if timeout
		;
		ACALL	SEND_START		; (x) Re-start I2C bus
		DELAY	0		; [0/0]	; (G) > 4.7us - (G+8) cycles
		;
INIT_I2C_STOP:	ACALL	SEND_STOP		; (x) Stop I2C bus
		RET				; (2) Done


;
; Set I2C Bus Address for actions with long Sub-Address
; -----------------------------------------------------
;
; Prototype:	void set_i2c_lng (byte address);
;
; Purpose:	Sets I2C bus address for actions which require a long
;		(2-byte) sub-address (i.e. functions with "_lng" suffix)
;
; Mechanism:	Stores 8-bit bus address in module variable for later use
;

		PUBLIC	_SET_I2C_LNG

		RSEG	?PR?I2C_51?ALL

_SET_I2C_LNG:					; (2) LCALL _SET_I2C_LNG
		MOV	LNG_BUS_ADDR,R7		; (2) Store bus address
		RET				; (2) Done


;
; I2C Bus Poll (no Sub-Address)
; -----------------------------
;
; Prototype:	bit poll_i2c (byte address);
;
; Purpose:	The I2C slave addressed by 'address' is polled to see
;		whether it is present.
;
;		The return value is 1 if the slave is present,
;		otherwise it is 0.
;

		PUBLIC	_POLL_I2C

		RSEG	?PR?I2C_51?ALL

_POLL_I2C:					; (2) LCALL _POLL_I2C
		MOV	B,#I2C_PL_DIR		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Poll with Sub-Address
; -----------------------------
;
; Prototype:	bit poll_i2c_sub (word address);
;
; Purpose:	The I2C slave addressed by 'address' is polled to see
;		whether it is present.  Can also be used to send a
;		command (as sub-address) to devices such as PCF8573.
;
;		The return value is 1 if the slave is present,
;		otherwise it is 0.
;

		PUBLIC	_POLL_I2C_SUB

		RSEG	?PR?I2C_51?ALL

_POLL_I2C_SUB:					; (2) LCALL _POLL_I2C_SUB
		MOV	B,#I2C_PL_SUB		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Write (no Sub-Address)
; ------------------------------
;
; Prototype:	bit write_i2c (byte address, byte idata *ptr, byte count);
;
; Purpose:	'count' data bytes pointed to by 'ptr' are sent to the
;		I2C slave addressed by 'address'.
;
;		The return value is 1 if the transfer is successful,
;		otherwise it is 0 (indicates an error).
;

		PUBLIC	_WRITE_I2C

		RSEG	?PR?I2C_51?ALL

_WRITE_I2C:					; (2) LCALL _WRITE_I2C
		MOV	B,#I2C_WR_DIR		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Write with Sub-Address
; ------------------------------
;
; Prototype:	bit write_i2c_sub (word address, byte idata *ptr, byte count);
;
; Purpose:	'count' data bytes pointed to by 'ptr' are sent to the
;		I2C slave addressed by 'address' (MSB is main address,
;		LSB is sub-address).
;
;		The return value is 1 if the transfer is successful,
;		otherwise it is 0 (indicates an error).
;

		PUBLIC	_WRITE_I2C_SUB

		RSEG	?PR?I2C_51?ALL

_WRITE_I2C_SUB:					; (2) LCALL _WRITE_I2C_SUB
		MOV	B,#I2C_WR_SUB		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Write with Long Sub-Address
; -----------------------------------
;
; Prototype:	bit write_i2c_lng (word subaddr, byte idata *ptr, byte count);
;
; Purpose:	'count' data bytes pointed to by 'ptr' are sent to the I2C
;		slave addressed by the stored I2C bus address and 'subaddr'.
;
;		The return value is 1 if the transfer is successful,
;		otherwise it is 0 (indicates an error).
;

		PUBLIC	_WRITE_I2C_LNG

		RSEG	?PR?I2C_51?ALL

_WRITE_I2C_LNG:					; (2) LCALL _WRITE_I2C_LNG
		MOV	B,#I2C_WR_LNG		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Read (no Sub-Address)
; -----------------------------
;
; Prototype:	bit read_i2c (byte address, byte idata *ptr, byte count);
;
; Purpose:	'count' data bytes pointed to by 'ptr' are received from the
;		I2C slave addressed by 'address'.
;
;		The return value is 1 if the transfer is successful,
;		otherwise it is 0 (indicates an error).
;

		PUBLIC	_READ_I2C

		RSEG	?PR?I2C_51?ALL

_READ_I2C:					; (2) LCALL _READ_I2C
		MOV	B,#I2C_RD_DIR		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Read with Sub-Address
; -----------------------------
;
; Prototype:	bit read_i2c_sub (word address, byte idata *ptr, byte count);
;
; Purpose:	'count' data bytes pointed to by 'ptr' are received from the
;		I2C slave addressed by 'address' (MSB is main address,
;		LSB is sub-address).
;
;		The return value is 1 if the transfer is successful,
;		otherwise it is 0 (indicates an error).
;

		PUBLIC	_READ_I2C_SUB

		RSEG	?PR?I2C_51?ALL

_READ_I2C_SUB:					; (2) LCALL _READ_I2C_SUB
		MOV	B,#I2C_RD_SUB		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Read with Long Sub-Address
; ----------------------------------
;
; Prototype:	bit read_i2c_lng (word aubaddr, byte idata *ptr, byte count);
;
; Purpose:	'count' data bytes pointed to by 'ptr' are received from the
;		I2C slave addressed by the stored I2C bus address and 'subaddr'.
;
;		The return value is 1 if the transfer is successful,
;		otherwise it is 0 (indicates an error).
;

		PUBLIC	_READ_I2C_LNG

		RSEG	?PR?I2C_51?ALL

_READ_I2C_LNG:					; (2) LCALL _READ_I2C_LNG
		MOV	B,#I2C_RD_LNG		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Compare (no Sub-Address)
; --------------------------------
;
; Prototype:	bit comp_i2c (byte address, byte idata *ptr, byte count);
;
; Purpose:	'count' data bytes pointed to by 'ptr' are compared with
;		those in the I2C slave addressed by 'address'.
;
;		The return value is 1 if an exact match is found,
;		otherwise it is 0 (indicates I2C error or no match).
;

		PUBLIC	_COMP_I2C

		RSEG	?PR?I2C_51?ALL

_COMP_I2C:					; (2) LCALL _COMP_I2C
		MOV	B,#I2C_CM_DIR		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Compare with Sub-Address
; --------------------------------
;
; Prototype:	bit comp_i2c_sub (word address, byte idata *ptr, byte count);
;
; Purpose:	'count' data bytes pointed to by 'ptr' are compared with
;		those in the I2C slave addressed by 'address'
;		(MSB is main address, LSB is sub-address).
;
;		The return value is 1 if an exact match is found,
;		otherwise it is 0 (indicates I2C error or no match).
;

		PUBLIC	_COMP_I2C_SUB

		RSEG	?PR?I2C_51?ALL

_COMP_I2C_SUB:					; (2) LCALL _COMP_I2C_SUB
		MOV	B,#I2C_CM_SUB		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; I2C Bus Compare with Long Sub-Address
; -------------------------------------
;
; Prototype:	bit comp_i2c_lng (word subaddr, byte idata *ptr, byte count);
;
; Purpose:	'count' data bytes pointed to by 'ptr' are compared with
;		those in the I2C slave addressed by the stored I2C bus address
;		and 'subaddr'.
;
;		The return value is 1 if an exact match is found,
;		otherwise it is 0 (indicates I2C error or no match).
;

		PUBLIC	_COMP_I2C_LNG

		RSEG	?PR?I2C_51?ALL

_COMP_I2C_LNG:					; (2) LCALL _COMP_I2C_LNG
		MOV	B,#I2C_CM_LNG		; (2) Set up bit mask
		SJMP	I2C_ALL			; (2) Perform actions


;
; Perform all I2C actions
; -----------------------
;
; Mechanism:	1. I2C bus is seized and a start condition applied
;		2. Slave address is sent and acknowledgement checked 
;		3. If just an I2C poll, result is returned
;		4. If required, sub-address is sent and ack checked
;		5. If read operation, I2C bus is re-started and slave
;		   address is re-sent with a "read" indication
;		6. Data bytes are either sent or received and acked
;		   (except for last byte of read operation)
;		7. Stop condition is applied and I2C bus is released
;
; Latency:	None
;
; Destroys:	ACC, C, R0, R1, R3
;

		RSEG	?PR?I2C_51?ALL

I2C_ALL:	LCALL	SET_I2C_WATCHDOG	; (x) Set up watchdog timeout
		CLR	I2C_TOUT_ERR		; (1) Clear timeout error flag
		;
		MOV	A,R5			; (1) Set start of buffer
		MOV	R0,A			; (1) <-
		;
		ACALL	SEND_START		; (x) Start I2C bus
		JNC	I2C_STOP		; (2) Abort if timeout
		;
I2C_LNG:	JNB	B_LNG,I2C_ADDR		; (2) If long sub-address ..
		MOV	A,LNG_BUS_ADDR		; (1) .. load stored address
		SJMP	I2C_ADDR_2		; (2) .. and use it
;
I2C_ADDR:	MOV	A,R7			; (1) Get slave address ..
		JNB	B_SUB,I2C_ADDR_2	; (2) .. MSB first if sub-
		MOV	A,R6			; (1) .. address supplied
		;
I2C_ADDR_2:	CLR	ACC.0			; (1) Set to write mode ..
		JNB	B_RD_DIR,I2C_ADDR_3	; (2) .. unless read without
		SETB	ACC.0			; (1) .. sub-address
		;
I2C_ADDR_3:	ACALL	SEND_BYTE_ACK		; (x) Send slave address
		JNC	I2C_STOP		; (2) Abort if no ACK
		;
		JNB	B_SUB,I2C_DATA		; (2) Skip if no sub-address
		;
		JNB	B_LNG_TMP,I2C_SUB	; (2) If long sub-address ..
		CLR	B_LNG_TMP		; (1) .. (first pass only)
		MOV	A,R6			; (1) Get MSB of sub-address
		SJMP	I2C_ADDR_3		; (2) Go back and send it
;
I2C_SUB:	MOV	A,R7			; (1) Get slave sub-address
		ACALL	SEND_BYTE_ACK		; (x) Send it
		JNC	I2C_STOP		; (2) Abort if no ACK
		;
		JB	B_POLL,I2C_STOP		; (2) Exit if just a poll
		JNB	B_READ,I2C_WR_DATA	; (2) Jump if write operation
		;
		ACALL	SEND_START		; (x) Re-start I2C bus
		JNC	I2C_STOP		; (2) Abort if timeout
		;
		MOV	A,R6			; (1) Get slave address ..
		JNB	B_LNG,I2C_SUB_2		; (2) If long sub-address ..
		MOV	A,LNG_BUS_ADDR		; (1) .. use stored address
		;
I2C_SUB_2:	SETB	ACC.0			; (1) .. in read mode
		ACALL	SEND_BYTE_ACK		; (x) Send it
		JNC	I2C_STOP		; (2) Abort if no ACK
		;
		SJMP	I2C_RD_DATA		; (2) Continue with read
;
I2C_DATA:	JB	B_POLL,I2C_STOP		; (2) Exit if just a poll
		JNB	B_READ,I2C_WR_DATA	; (2) Jump if write operation
		;
I2C_RD_DATA:	ACALL	RCVE_BYTE		; (x) Read byte from slave
		JNC	I2C_STOP		; (2) Abort if timeout
		XCH	A,@R0			; (1) Swap with RAM value
		JNB	B_COMP,I2C_RD_DAT2	; (2) Skip ahead if read
		;
I2C_COMP:	XCH	A,@R0			; (1) Restore RAM value
		XRL	A,@R0			; (1) Compare both values
		JZ	I2C_RD_DAT2		; (2) Skip ahead if match
		;
		ACALL	NEG_ACK			; (x) Send NAK (ignore result)
		CLR	C			; (1) Force failure result
		SJMP	I2C_STOP		; (2) Exit with STOP condition
;		
I2C_RD_DAT2:	INC	R0			; (1) Bump pointer
		DJNZ	R3,I2C_RD_NEXT		; (2) Loop if not last
		;
I2C_RD_LAST:	ACALL	NEG_ACK			; (x) Send NAK (retain result)
		SJMP	I2C_STOP		; (2) Finish off
;
I2C_RD_NEXT:	ACALL	SEND_ACK		; (x) Send ACK (retain result)
		JNC	I2C_STOP		; (2) Abort if timeout
		SJMP	I2C_RD_DATA		; (2) Loop back
;
I2C_WR_DATA:	MOV	A,@R0			; (1) Get write data from RAM
		INC	R0			; (1) Bump pointer 
		ACALL	SEND_BYTE_ACK		; (x) Send it to slave
		JNC	I2C_STOP		; (2) Abort if no ACK
		;
		DJNZ	R3,I2C_WR_DATA		; (2) Repeat until last byte
		;
I2C_STOP:	ACALL	SEND_STOP		; (x) Stop I2C bus
		RET				; (2) Done


;
; From I2C Specification
; ----------------------
;
; The following minimum times (in uS) must be
; met for each possible I2C bus transition:
;
;	    |	SCL	SCL	SDA	SDA
;	    |	low	high	low	high
;	    |
; --------------------------------------------
;	    |
; SCL low   | 	---	4.7	0.0	0.0
;	    |
; SCL high  |	4.0	---	4.7	4.0
;	    |
; SDA low   |	4.0	0.25	---	N/A
;	    |
; SDA high  |	N/A	0.25	4.7	---
;	    |
;


;
; "Clock Stretching" Loop Macro
; -----------------------------
;
; Attempts to set SCL output high and waits for it to go high
; Aborts to "BUS_ERROR" if I2C timeout occurs

SET_SCL_HIGH	MACRO
		LOCAL	LOOP
LOOP:		SETB	I2C_SCL			; (1) Try to drive SCL high
		JB	I2C_TOUT,BUS_ERROR	; (2) Abort if timeout
		JNB	I2C_SCL,LOOP		; (2) Loop until SCL high
		ENDM


;
; I2C SUBROUTINES
; ---------------
;
; These routines affect only ACC, R1 and C
; ACC is used to pass byte data back and forth
;
; All routines set C on success or clear C on failure
; (except SEND_STOP which leaves C unchanged on success)
;

		RSEG	?PR?I2C_51?ALL

SEND_START:					; (2) ACALL SEND_START
		SETB	I2C_SDA			; (1) Set-up time
		SET_SCL_HIGH			; (5) Clock high
		DELAY	3		; [0/3]	; (G) > 4.7us - 5 cycles
		CLR	I2C_SDA			; (1) Start condition
		DELAY	7		; [3/7*]; (G) > 4.0us - 1 cycle
		CLR	I2C_SCL			; (1) Clock low
		DELAY	0		; [0/0]	; (G) > 4.7us - 11 cycles
		SETB	C			; (1) Indicate success
		RET				; (2) Done

SEND_BYTE_ACK:					; (2) ACALL SEND_BYTE_ACK
		MOV	R1,#8			; (1) Bit count
SEND_BYTE_LP:	RLC	A			; (1) Get bit
		MOV	I2C_SDA,C		; (2) Send it
		NOP				; (1) Allow SDA to settle
		SET_SCL_HIGH			; (5) Clock high
		DELAY	3		; [0/3*]; (G) > 4.0us - 5 cycles
		CLR	I2C_SCL			; (1) Clock low
		DELAY	2		; [0/2]	; (G) > 4.7us - 6 cycles
		DJNZ	R1,SEND_BYTE_LP		; (2) Loop round
		DELAY	2			; (2) Pad for 2 cycles
		;
RCVE_ACK:	SETB	I2C_SDA			; (1) Release ACK
		SET_SCL_HIGH			; (5) Clock high
		DELAY	1		; [0/1*]; (G) > 4.0us - 7 cycles
		MOV	C,I2C_SDA		; (1) Read ACK
		CPL	C			; (1) Invert it (1 = ACK)
		CLR	I2C_SCL			; (1) Clock low
		DELAY	0		; [0/0]	; (G) > 4.7us - 8 cycles
		RET				; (2) Done

BUS_ERROR:					; (0) SET_SCL_HIGH timeout
		SETB	I2C_TOUT_ERR		; (1) Set timeout error flag
		CLR	C			; (1) Return error
		RET				; (2) Done

RCVE_BYTE:					; (2) ACALL RCVE_BYTE
		MOV	R1,#8			; (1) Bit count
RCVE_BYTE_LP:	SETB	I2C_SDA			; (1) Release data
		SET_SCL_HIGH			; (5) Clock high
		DELAY	2		; [0/2*]; (G) > 4.0us - 6 cycles
		MOV	C,I2C_SDA		; (1) Read data
		CLR	I2C_SCL			; (1) Clock low
		DELAY	3		; [0/3]	; (G) > 4.7us - 5 cycles
		RLC	A			; (1) <-
		DJNZ	R1,RCVE_BYTE_LP		; (2) Loop round
		SETB	C			; (1) Indicate success
		RET				; (2) Done

SEND_ACK:					; (2) ACALL SEND_ACK
		CLR	I2C_SDA			; (1) ACK condition
		SET_SCL_HIGH			; (5) Clock high
		DELAY	3		; [0/3*]; (G) > 4.0us - 5 cycles
		CLR	I2C_SCL			; (1) Clock low
		SETB	I2C_SDA			; (1) Release ACK
		DELAY	0		; [0/0]	; (G) > 4.7us - 10 cycles
		SETB	C			; (1) Indicate success
		RET				; (2) Done

NEG_ACK:					; (2) ACALL NEG_ACK
		SETB	I2C_SDA			; (1) Negative ACK
		SET_SCL_HIGH			; (5) Clock high
		DELAY	3		; [0/3*]; (G) > 4.0us - 5 cycles
		CLR	I2C_SCL			; (1) Clock low
		DELAY	0		; [0/0]	; (G) > 4.7us - 9 cycles
		SETB	C			; (1) Indicate success
		RET				; (2) Done

SEND_STOP:					; (2) ACALL SEND_STOP
		CLR	I2C_SDA			; (1) Set-up time
		SET_SCL_HIGH			; (5) Clock high
		DELAY	3		; [0/3]	; (G) > 4.7us - 5 cycles
		SETB	I2C_SDA			; (1) Stop condition
		RET				; (2) Done


		END
