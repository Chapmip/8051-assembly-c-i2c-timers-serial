; Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
;
; This software is licensed under the MIT license (see LICENSE.TXT)
;
; See README.md for information on typical usage
;
; A51 include file with I/O port definitions
; Used by assembly routines (definitions for C51 files are in PORTS.H)


N_TXD		EQU	P3.0		; Serial data output
N_RXD		EQU	P3.1		; Serial data input
N_RTS		EQU	P0.3		; Serial handshake output
N_CTS		EQU	P2.7		; Serial handshake input

I2C_SCL		EQU	P0.0		; I2C serial clock line
I2C_SDA		EQU	P0.1		; I2C serial data line 

N_LED_L1	EQU	P1.7		; LED L1 output (active low)

; Diagnostic outputs

N_TMR_ISR	EQU	P0.6		; Timer interrupt active
