	NAME	TIMERS

	$INCLUDE (PORTS.INC)

;
; Timer 2 Based Routines for 87C52, AT89S53 and AT89S8253
; =======================================================
;
; Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
;
; This software is licensed under the MIT license (see LICENSE.TXT)
;
; Harnesses Timer 2 to provide:
;
; 1. (Optional) Enabling and regular feeding of built-in watchdog
;    on 89S53 and 89S8253 variants
; 2. Main 16-bit timeout timer clocked at Timer 2 reload rate
; 3. Auxiliary 16-bit timeout timer clocked at Timer 2 reload rate
; 4. I2C bus inactivity timeout timer (for I2C_51.A51 module)
; 5. Control of status LED L1 (on, off or flashing at specified rate)
;
; See README.md for information on typical usage
;
; Stack usage:
;
;	 5 bytes in background (low priority interrupt)
;	 2 bytes in foreground (any function call)
;


; -- CONSTANTS --

; Segment definitions

?DT?TIMERS	SEGMENT	DATA
?BI?TIMERS	SEGMENT	BIT
?PR?TIMERS	SEGMENT CODE


; Switches for device-specific watchdog code generation

WD_89S53	EQU	0	; Set non-zero for 89S53 watchdog code
WD_89S8253	EQU	0	; Set non-zero for 89S8253 watchdog code


; 8052 register definitions
; ** REMOVE THESE IF ALREADY DEFINED BY ASSEMBLER **

T2CON		EQU	0C8H		; Timer 2 control register
RCAP2L		EQU	0CAH		; Timer 2 reload low byte
RCAP2H		EQU	0CBH		; Timer 2 reload high byte
TL2		EQU	0CCH		; Timer 2 low byte
TH2		EQU	0CDH		; Timer 2 high byte

TF2		EQU	T2CON.7		; Timer 2 overflow flag
EXF2		EQU	T2CON.6		; Timer 2 external flag
RCLK		EQU	T2CON.5		; Timer 2 receive clock flag
TCLK		EQU	T2CON.4		; Timer 2 transmit clock flag
EXEN2		EQU	T2CON.3		; Timer 2 external enable flag
TR2		EQU	T2CON.2		; Timer 2 run flag
CT2		EQU	T2CON.1		; Timer 2 timer/counter select
CPRL2		EQU	T2CON.0		; Timer 2 capture/reload flag

ET2		EQU	IE.5		; Timer 2 interrupt enable
PT2		EQU	IP.5		; Timer 2 interrupt priority

; 8052 register constants

T2_MODE		EQU	00000000B	; 16-bit auto-reload


	IF WD_89S53

; AT89S53 specific SFR and constants

WCON		EQU	096H		; Watchdog control register
WDOG_MODE	EQU	11100011B	; 2.048 second timeout
WDOG_RESET_MSK	EQU	00000010B	; Watchdog reset bit mask

	ENDIF

	IF WD_89S8253

; AT89S8253 specific SFR and constants

WDTCON		EQU	0A7H		; Watchdog timer control register
WDOG_MODE	EQU	11101011B	; 2.048 second timeout
WDOG_RESET_MSK	EQU	00000010B	; Watchdog reset bit mask

	ENDIF


; -- VARIABLES --

		RSEG	?DT?TIMERS

MAIN_TOUT_HI:	DS	1		; Main event timer
MAIN_TOUT_LO:	DS	1		; <-

AUX_TOUT_HI:	DS	1		; Auxiliary event timer
AUX_TOUT_LO:	DS	1		; <-

I2C_TIMER:	DS	1		; I2C watchdog timer

FLASH_CTR:	DS	1		; LED L1 flash tick counter
FLASH_REL:	DS	1		; LED L1 flash tick reload value


		RSEG	?BI?TIMERS

MAIN_TIMEOUT:	DBIT	1		; Main event timeout flag
AUX_TIMEOUT:	DBIT	1		; Auxiliary event timeout flag

I2C_TOUT:	DBIT	1		; I2C timeout flag

FLASH_ENABLE:	DBIT	1		; Enables LED L1 flashing when set
NOT_L1_STATE:	DBIT	1		; Current LED L1 state (active-low)


; Externally visible variables

		PUBLIC	MAIN_TIMEOUT		; For C code main routines
		PUBLIC	AUX_TIMEOUT		; <-

		PUBLIC	I2C_TOUT		; For I2C assembly routines


;
; Timer 2 Interrupt Routine
; -------------------------
;
; Purpose:	Performs various periodic tasks
;
; Mechanism:	1.  Resets AT89S53 watchdog timer
;		2.  Updates event timers (if running)
;		3.  Counts down I2C watchdog timer (if running)
;		4.  Flashes LED at specified rate if flashing is enabled
;
; Run Time:	52 cycles MAX, 33 cycles TYP (21.5 us @ 18.432 MHz)
; Latency:	Equal to run time (low priority interrupt)
;
; Destroys:	None (!)
;

		CSEG	AT 002BH
						; (2) Interrupt "LCALL"
		LJMP	T2_INT			; (2) Jump to main routine

		RSEG	?PR?TIMERS
		USING	0

T2_INT:		PUSH	PSW			; (2) Save vitals
		PUSH	ACC			; (2) <-
		PUSH	AR0			; (2) <-
		;
		CLR	TF2			; (1) Clear interrupt flag
		;
		CLR	N_TMR_ISR		; (1) Assert diagnostic output
		;
	IF WD_89S53
		ORL	WCON,#WDOG_RESET_MSK	; (2) Reset watchdog timer
	ENDIF
	IF WD_89S8253
		ORL	WDTCON,#WDOG_RESET_MSK	; (2) Reset watchdog timer
	ENDIF
		;
T2_MTIM:	JB	MAIN_TIMEOUT,T2_ATIM	; (2) Skip if timer expired
		DJNZ	MAIN_TOUT_LO,T2_ATIM	; (2) Decrement timer ..
		DJNZ	MAIN_TOUT_HI,T2_ATIM	; (2) .. as 16 bit value
		;
		SETB	MAIN_TIMEOUT		; (1) Indicate timeout
		;
T2_ATIM:	JB	AUX_TIMEOUT,T2_I2C	; (2) Skip if timer expired
		DJNZ	AUX_TOUT_LO,T2_I2C	; (2) Decrement timer ..
		DJNZ	AUX_TOUT_HI,T2_I2C	; (2) .. as 16 bit value
		;
		SETB	AUX_TIMEOUT		; (1) Indicate timeout
		;
T2_I2C:		JB	I2C_TOUT,T2_LED		; (2) Skip if timer expired
		DJNZ	I2C_TIMER,T2_LED	; (2) Decrement timer
		;
		SETB	I2C_TOUT		; (1) Indicate timeout
		;
T2_LED:		JNB	FLASH_ENABLE,T2_DONE	; (2) Skip if not flashing
		DJNZ	FLASH_CTR,T2_DONE	; (2) Count down to zero
		;
		MOV	FLASH_CTR,FLASH_REL	; (2) Re-load flash counter
		;
		CPL	NOT_L1_STATE		; (1) Flip stored LED L1 state 
		MOV	C,NOT_L1_STATE		; (1) Copy stored state ..
		MOV	N_LED_L1,C		; (2) .. to LED L1 output
		;
T2_DONE:	SETB	N_TMR_ISR		; (1) Release diagnostic output
		;
		POP	AR0			; (2) Restore vitals
		POP	ACC			; (2) <-
		POP	PSW			; (2) <-
		;
		RETI				; (2) All done


;
; Initialise Timers
; -----------------
;
; Prototype:	void init_timers(word period);
;
; Purpose:	Initialise Timer 2 and variables 
;		Also enables AT89S53 watchdog timer
;
; Mechanism:	Brute-force initialisation
;
; Run Time:	31 cycles always
; Latency:	26 cycles always
;

		PUBLIC	_INIT_TIMERS

		RSEG	?PR?TIMERS

_INIT_TIMERS:					; (2) LCALL _INIT_TIMERS
		;
		CLR	ET2			; (1) Stop timer + interrupt
		CLR	TR2			; (1) <-
		;
		MOV	T2CON,#T2_MODE		; (2) Set auto-reload mode
		CLR	PT2			; (1) Low priority interrupt
		;
		CLR	A			; (1) Set up timer + reload
		CLR	C			; (1) <-
		SUBB	A,R7			; (1) <-
		MOV	TL2,A			; (1) <-
		MOV	RCAP2L,A		; (1) <-
		CLR	A			; (1) <-
		SUBB	A,R6			; (1) <-
		MOV	TH2,A			; (1) <-
		MOV	RCAP2H,A		; (1) <-
		;
		SETB	TR2			; (1) Start Timer 2 running
		;
		SETB	MAIN_TIMEOUT		; (1) Assume timeout initially
		SETB	AUX_TIMEOUT		; (1) <-
		SETB	I2C_TOUT		; (1) <-
		;
		CLR	FLASH_ENABLE		; (1) Disable flashing of LED L1
		SETB	NOT_L1_STATE		; (1) LED L1 is switched off
		SETB	N_LED_L1		; (1) Reflect on LED L1 output
		;
		CLR	A			; (1) Zero flash values
		MOV	FLASH_CTR,A		; (1) <-
		MOV	FLASH_REL,A		; (1) <-
		;
	IF WD_89S53
		MOV	WCON,#WDOG_MODE		; (2) Enable watchdog timer
	ENDIF
	IF WD_89S8253
		MOV	WDTCON,#WDOG_MODE	; (2) Enable watchdog timer
	ENDIF
		;
		SETB	ET2			; (1) Enable Timer 2 ints
		;
		RET				; (2) All done


;
; Set main timeout timer
; ---------------------
;
; Prototype:	void set_main_timeout(word ticks);
;
; Purpose:	Set the main timeout timer to number of Timer 2 periods
;		("ticks" - 16 bit value) and start it running
;
; Mechanism:	1. Stop timeout timer
;		2. Adjust count bytes to base 1 (0 == 256)
;		3. Load timeout timer with count
;		4. Start timeout timer
;
; Run Time:	12 cycles always
; Latency:	None
;
; Assumptions:	Timer 2 interrupts are enabled
;

		PUBLIC	_SET_MAIN_TIMEOUT

		RSEG	?PR?TIMERS

_SET_MAIN_TIMEOUT:				; (2) LCALL _SET_MAIN_TIMEOUT
		;
		SETB	MAIN_TIMEOUT		; (1) Stop timeout timer
		;
		INC	R6			; (1) Adjust count bytes
		INC	R7			; (1) <-
		;
		MOV	MAIN_TOUT_HI,R6		; (2) Load timeout timer
		MOV	MAIN_TOUT_LO,R7		; (2) <-
		;
		CLR	MAIN_TIMEOUT		; (1) Start timeout timer
		;
		RET				; (2) All done


;
; Set auxiliary timeout timer
; ---------------------------
;
; Prototype:	void set_aux_timeout(word ticks);
;
; Purpose:	Set the auxiliary timeout timer to number of Timer 2 periods
;		("ticks" - 16 bit value) and start it running
;
; Mechanism:	1. Stop timeout timer
;		2. Adjust count bytes to base 1 (0 == 256)
;		3. Load timeout timer with count
;		4. Start timeout timer
;
; Run Time:	12 cycles always
; Latency:	None
;
; Assumptions:	Timer 2 interrupts are enabled
;

		PUBLIC	_SET_AUX_TIMEOUT

		RSEG	?PR?TIMERS

_SET_AUX_TIMEOUT:				; (2) LCALL _SET_AUX_TIMEOUT
		;
		SETB	AUX_TIMEOUT		; (1) Stop timeout timer
		;
		INC	R6			; (1) Adjust count bytes
		INC	R7			; (1) <-
		;
		MOV	AUX_TOUT_HI,R6		; (2) Load timeout timer
		MOV	AUX_TOUT_LO,R7		; (2) <-
		;
		CLR	AUX_TIMEOUT		; (1) Start timeout timer
		;
		RET				; (2) All done


;
; Set I2C bus watchdog timer
; --------------------------
;
; Prototype:	void set_i2c_watchdog(void);
;
; Purpose:	Set the I2C watchdog timer to 256 * Timer 2 periods
;		and start it running
;
; Mechanism:	1. Stop watchdog timer
;		2. Load watchdog timer with count
;		3. Start watchdog timer
;
; Run Time:	8 cycles always
; Latency:	None
;
; Assumptions:	Timer 2 interrupts are enabled
;

		PUBLIC	SET_I2C_WATCHDOG

		RSEG	?PR?TIMERS

SET_I2C_WATCHDOG:				; (2) LCALL SET_I2C_WATCHDOG
		;
		SETB	I2C_TOUT		; (1) Stop watchdog timer
		MOV	I2C_TIMER,#0		; (2) Load timer with 256
		CLR	I2C_TOUT		; (1) Start watchdog timer
		RET				; (2) All done


;
; Set LED L1 state
; ----------------
;
; Prototypes:	void set_L1_on(void);
;		void set_L1_off(void);
;		void set_L1_flash(byte period);
;
; Purpose:	Sets LED L1 output to be continuously on or off,
;		or to flash with the specified period
;
; Mechanism:	Brute-force initialisation
;
; Run Time:	7 cycles always (except set_L1_flash() - 10 cycles)
; Latency:	None
;

		PUBLIC	SET_L1_ON
		PUBLIC	SET_L1_OFF
		PUBLIC	_SET_L1_FLASH

		RSEG	?PR?TIMERS

SET_L1_ON:					; (2) LCALL SET_L1_ON
		CLR	FLASH_ENABLE		; (1) Disable flashing
		CLR	NOT_L1_STATE		; (1) LED L1 is switched on
		CLR	N_LED_L1		; (1) Reflect on LED L1 output
		RET				; (2) Done

SET_L1_OFF:					; (2) LCALL SET_L1_OFF
		CLR	FLASH_ENABLE		; (1) Disable flashing
		SETB	NOT_L1_STATE		; (1) LED L1 is switched off
		SETB	N_LED_L1		; (1) Reflect on LED L1 output
		RET				; (2) Done
		
_SET_L1_FLASH:					; (2) LCALL _SET_L1_FLASH
		CLR	FLASH_ENABLE		; (1) Suspend flashing
		MOV	FLASH_REL,R7		; (2) Store flashing period
		MOV	FLASH_CTR,#1		; (2) Force change next int
		SETB	FLASH_ENABLE		; (1) Enable flashing
		RET				; (2) Done


		END
