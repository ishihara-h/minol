;Original MINOL(CPMUG017)
;
;Modified the source program to run on CP/M
;Hiroshi Ishihara 2021/3/14
;
PROGST	EQU	0A00H
MEMEND	EQU	2FFFH
;
;--CP/M interface---------------
OS	EQU	0
BDOS	EQU	5
LF	EQU	10
CR	EQU	13
ORIGIN	EQU	100H
;
	ORG	ORIGIN
	JMP	MINOL
;
INPUT:
CIN:	PUSH	H
	PUSH	D
	PUSH	B
	MVI	C,1
	CALL	BDOS
	POP	B
	POP	D
	POP	H
	RET
;
CRLF:	MVI	A,CR
	CALL	COUT
	MVI	A,LF
COUT:	PUSH	H
	PUSH	D
	PUSH	B
	PUSH	PSW
	MOV	E,A
	MVI	C,2
	CALL	BDOS
	POP	PSW
	POP	B
	POP	D
	POP	H
	RET
;
SENSE:	PUSH	H
	PUSH	D
	PUSH	B
	MVI	C,6
	MVI	E,0FFH
	CALL	BDOS
	POP	B
	POP	D
	POP	H
	RET
;
FCB:	EQU	05CH
DMA:	EQU	080H
OPENF:	EQU	15
CLOSEF:	EQU	16
DELF:	EQU	19
READF:	EQU	20
WRITEF:	EQU	21
MAKEF:	EQU	22
SETDMA:	EQU	26
;
INITFCB:PUSH	H
	LXI	H,FCB
	MVI	M,0
	INX	H
	MVI	C,11
	MVI	A,' '
INITFC1:MOV	M,A
	INX	H
	DCR	C
	JNZ	INITFC1
	MVI	C,24
	XRA	A
INITFC2:MOV	M,A
	INX	H
	DCR	C
	JNZ	INITFC2
	POP	H
	RET
;
SETPARA:PUSH	D
	PUSH	B
	INX	H
	INX	H
	INX	H
SETP1:	MOV	A,M
	CPI	' '
	JNZ	SETP2
	INX	H
	JMP	SETP1
SETP2:	CALL	INITFCB
	MVI	C,8
	LXI	D,FCB+1
	MOV	A,M
SETP3:	ANI	07FH
	INX	H
	STAX	D
	INX	D
	DCR	C
	JZ	ERR3
	MOV	A,M
	CPI	' '
	JZ	SETP4
	CPI	CR
	JNZ	SETP3
SETP4:	LXI	D,FCB+9
	MVI	A,'B'
	STAX	D
	INX	D
	MVI	A,'A'
	STAX	D
	INX	D
	MVI	A,'S'
	STAX	D
	POP	B
	POP	D
	RET
;
LOAD:	CALL	SETPARA
	PUSH	H
	PUSH	D
	PUSH	B
	LXI	D,FCB
	MVI	C,OPENF		;open file
	CALL	BDOS
	INR	A
	JZ	ERR3
	LXI	D,PROGST
READ:	MVI	C,SETDMA	;set DMA
	CALL	BDOS
	PUSH	D
	LXI	D,FCB
	MVI	C,READF		;read sequential
	CALL	BDOS
	POP	D
	ANA	A
	JNZ	READEND
	PUSH	H
	LXI	H,080H
	DAD	D
	XCHG
	POP	H
	JMP	READ
;
READEND:LXI	D,FCB
	MVI	C,CLOSEF
	CALL	BDOS
	POP	B
	POP	D
	POP	H
	RET
;
SAVE:	INX	H
	CALL	SETPARA
	PUSH	H
	PUSH	D
	PUSH	B
	LXI	D,FCB
SAVE0:	MVI	C,OPENF		;open file
	CALL	BDOS
	INR	A
	JZ	SAVE1
	LXI	D,FCB
	MVI	C,DELF
	CALL	BDOS
	INR	A
	JZ	ERR3
	LXI	D,FCB
SAVE1:	MVI	C,MAKEF
	CALL	BDOS
	INR	A
	JZ	ERR3
SAVE2:	LXI	D,PROGST
	PUSH	D
	LXI	B,0
SAVE3:	LDAX	D
	INX	D
	INX	B
	INR	A
	JNZ	SAVE3
	CMP	C
	JZ	SAVE4
	INR	B
	MVI	A,01AH		;EOF
	STAX	D
SAVE4:	POP	D
WRITE:	PUSH	B
	MVI	C,SETDMA	;set DMA
	CALL	BDOS
	PUSH	D
	LXI	D,FCB
	MVI	C,WRITEF	;write sequential
	CALL	BDOS
	POP	D
	POP	B
	ANA	A
	JNZ	ERR3
	DCR	B
	JZ	WRITE2
	PUSH	H
	LXI	H,080H
	DAD	D
	XCHG
	POP	H
	JMP	WRITE
;
WRITE2:	MVI	C,CLOSEF
	CALL	BDOS
	POP	B
	POP	D
	POP	H
	RET
;--CP/M interface---------------
; 
MINOL:	MVI	A,']'	;OUTPUT PROMPT
	CALL	COUT
	CALL	INPTXT	;GET INPUT LINE
	LXI	H,TXT	;POINT TO INPUT TEXT WITH HL
	MOV	A,M
	CALL	CHEKN	;CHECK FOR LABEL
	JNC	DIRECT	;IF NO LABEL, GO EXECUTE COMMAND
FND:	INX	H	;POINT TO FIRST NON-NUMERIC CHAR
	MOV	A,M
	CALL	CHEKN
	JC	FND
	CALL	MKBIN	;CONVERT ASCII LABEL TO BINARY
	LXI	D,PROG	;THIS SECTION EDITS LINES OF THE PROGRAM
ZIP:	LDAX	D
	CPI	CR
	INX	D
	JNZ	ZIP
	LDAX	D	;LOOK AT LINE NUMBER
	CPI	0FFH
	JZ	INSRT
	STC
	CMC
	CMP	B
	JC	ZIP	;POINT TO LINE NUMBER GREATER THAN OR
INSRT:	MOV	A,M	;OR EQUAL TO ENTERED LABEL
	CPI	CR
	JZ	EKIL	;IF LABEL ALONE, DELETE LINE
	MVI	C,2
IHR:	INX	H	;COUNT LENGTH OF LINE AND ADD 2
	MOV	A,M
	INR	C
	CPI	CR
	JNZ	IHR
OHIO:	LDAX	D	;IF LINE ENTERED ALREADY EXISTS, FIRST
	CMP	B	;DELETE THE OLD ONE, THEN INSERT NEW 
	JNZ	IBYH
PZIY:	PUSH	D
	CALL	KILLINE
	POP	D
IBYH:	MOV	H,D	;HL POINTS TO FIRST LOCATION WHERE NEW
	MOV	L,E	;LINE WILL BE PLACED
	PUSH	D	;SAVE POSITION IN STACK
EHR:	INX	D
	LDAX	D
	CPI	0FFH
	JNZ	EHR	;CONTINUE UNTIL DE POINTS TO END OF FILE
	MOV	A,C	;LENGTH OF NEW LINE IN A
	MOV	B,D
	MOV	C,E
HBY:	INX	D
	INX	H
	PUSH	PSW
	MOV	A,E
	CPI	MEMEND AND 0FFH	;MEMORY LIMIT
	JNZ	HII
	MOV	A,D
	CPI	MEMEND SHR 8
	JZ	ERR6	;OUT OF MEMORY ERROR
HII:	POP	PSW
	DCR	A
	JNZ	HBY	;INCREMENT UNTIL DE POINTS TO NEW 
UPDT:	LDAX	B	;END-OF-FILE POSITION, AND HL POINTS
	STAX	D	;TO WHERE FILE UPDATING BEGINS
	MOV	A,E	;BC POINTS TO END-OF-FILE
	CMP	L
	JNZ	NHR
	MOV	A,D
	CMP	H
	JZ	NET
NHR:	DCX	B
	DCX	D
	JMP	UPDT	;RELOCATE FILE LEAVING SPACE FOR NEW LINE
NET:	POP	D	;RETRIEVE POINTER
	LXI	H,TXT
IFD:	INX	H
	MOV	A,M
	CALL	CHEKN
	JC	IFD	;POINT TO FIRST NON-NUMERIC CHARACTER
	LDA	BIN	;PUT LINE NUMBER IN A
	STAX	D	;STORE LINE NUMBER IN FILE
NTAT:	INX	D	;STORE LINE TEXT IN FILE
	MOV	A,M
	STAX	D
	INX	H
	CPI	CR
	JNZ	NTAT
	CALL	CRLF
	JMP	MINOL	;GO BACK TO MONITOR SECTION
EKIL:	CALL	KILLINE	;DELETE LINE
	CALL	CRLF
	JMP	MINOL
KILLINE: LDAX D	;DELETE A LINE
	CMP	B
	RNZ	;IF DELETING A LINE THAT DOES NOT EXIST,RETURN
	MOV	H,D
	MOV	L,E
BBL:	INX	H
	MOV	A,M
	CPI	CR
	JNZ	BBL	;POINT TO NEXT LINE
ARK:	INX	H	;RELOCATE FILE, DELETING LINE
	MOV	A,M
	STAX	D
	CPI	0FFH
	RZ
	INX	D
	JMP	ARK
DIRECT: CALL	CRLF	;DIRECT EXECUTION OF A STATEMENT
	XRA	A
	STA	LNE	;SET LNE (CURRENT LINE NO.) = 0
	JMP	EXEC	;EXECUTE STATEMENT
RUN:	LXI	H,PROG	;RUN STATEMENT: START FROM BEGINNING OF 
LPUB:	MOV	A,M	;PROGRAM. GET NEXT STATEMENT
	CPI	':'
	INX	H
	JZ	EXEC	;IF NOT A NEW LINE, GO EXECUTE STATEMENT
	CPI	CR
	JNZ	LPUB
BIB:	MOV	A,M
	CPI	0FFH
	JZ	MINOL	;IF STATEMENT NO. = 377 (END OF PROGRAM),
	STA	LNE	; GO BACK TO MONITOR
	INX	H	;IF NOT 377, STORE CURRENT LINE NO. AT LNE
EXEC:	CALL	INT	;CHECK FOR KEYBOARD INTERRUPT
	INX	H
	MOV	A,M
	CPI	'='	;CHECK FOR = IN SECOND COLUMN (ASSIGNMENT)
	JZ	LET
	DCX	H
	MOV	A,M
	CPI	'('	;IF ( IN FIRST COLUMN (MEMORY LOCATION
	JZ	LET	; ASSIGNMENT) GO TO LET
	CPI	'C'	;CHECK FOR 'C'
	JNZ	GSM	;IF NOT, GO ON
	INX	H
	MOV	A,M
	CPI	'A'
	JZ	CALLST	;CALL STATEMENT
	CPI	'L'
	JZ	CLR	;CLEAR STATEMENT
	JMP	ERR3	;IF NEITHER, REPORT ERROR
GSM:	CPI	'E'	;CHECK FOR 'E' AS IN END
	JZ	MINOL
	CPI	'G'
	JZ	GOTO
	CPI	'"'	;CHECK FOR " INDICATING REM STATEMENT
	JZ	LPUB
	CPI	'N'
	JZ	NEW
	CPI	'P'
	JZ	PR
	CPI	'O'
	JZ	OS	;ADDRESS OF USER'S MONITOR
	CPI	'R'
	JZ	RUN
	CPI	'I'
	JNZ	LS
	INX	H
	MOV	A,M
	CPI	'N'
	JZ	INST
	CPI	'F'
	JZ	IFST
	JMP	ERR3
LS:	CPI	'L'
	JZ	LDLET
	CPI	'S'
	JNZ	ERR3
	CALL	SAVE
	JMP	LPUB
LDLET:	INX	H
	MOV	A,M
	CPI	'O'
	JNZ	LDLET1
	CALL	LOAD
	JMP	LPUB
LDLET1:	CPI	'E'
	JZ	LET
	CPI	'I'
	JZ	LIST
	JMP	ERR3
LET:	MOV	A,M	;LET STATEMENT EXECUTOR
	CALL	TERM	;FIND '='
	JC	ERR5	;REPORT ERROR IF NO '=' BEFORE CR OR ':'
	CPI	'='
	INX	H
	JNZ	LET
	LXI	D,EXPR	;TRANSFER EXPRESSION TEXT TO 
MRENX:	MOV	A,M	;EXPRESSION BUFFER
	STAX	D
	CALL	TERM
	INX	H
	INX	D
	JNC	MRENX
	CALL	EXPRS
SERCH:	MOV	A,M	;GO BACK BEFORE '='
	CPI	'='
	DCX	H
	JNZ	SERCH
	MOV	A,M
	CALL	CHEKLTR
	JNC	INLET	;IF NOT VARIABLE, GET MEMORY ADDRESS
	CALL	GETADR
	MOV	A,C
	STAX	D	;STORE IN VARIABLE
	JMP	LPUB	;NEXT STATEMENT
INLET:	CPI	')'
	JNZ	ERR4
JHR:	DCX	H
	MOV	A,M
	CPI	'('
	JNZ	JHR
	MOV	A,C
	PUSH	PSW
	CALL	VAL	;GET MEMORY LOCATION IN BC
	POP	PSW
	STAX	B
	JMP	LPUB
PR:	INX	H	;PR STATEMENT EXECUTOR
	INX	H	;SKIP ASSUMED CHARACTERS
	MOV	A,M
	CALL	TERM	;IF BLANK PRINT, GO TO CR
	JC	DCR0
NXTE:	CPI	'"'	;CHECK FOR LITERAL
	JNZ	VAR	;IF NOT, GO ON
HR:	INX	H	;PRINT TEXT UNTIL " FOUND
	MOV	A,M
	CPI	'"'
	JZ	MRENO
	CALL	TERM	;IF TERMINATOR BEFORE CLOSING QUOTE, ERROR
	JC	ERR5
	CALL	COUT
	JMP	HR
MRENO:	INX	H
	MOV	A,M
	CALL	TERM	;IF END OF STATEMENT WITHOUT SEMICOLON, DO CR
	JC	DCR0
	CPI	';'
	JNZ	ERR5
	INX	H
	MOV	A,M
	CALL	TERM	;IF TERM AFTER SEMICOLON, DO NOT PRINT CR
	JC	NCR
	JMP	NXTE
DCR0:	CALL	CRLF
NCR:	JMP	LPUB
VAR:	CPI	'$'
	JZ	STR	;CHECK IF STRING
	LXI	D,EXPR
	MVI	A,' '	;OUTPUT LEADING SPACE
	CALL	COUT
ER:	MOV	A,M	;TRANSFER EXPRESSION TEXT FROM PROGRAM TEXT
	STAX	D	; TO EXPRESSION BUFFER
	INX	H
	INX	D
	CALL	TERM
	JC	HRX
	CPI	';'
	JNZ	ER
HRX:	DCX	H
	DCX	D
	MVI	A,CR
	STAX	D
	CALL	EXPRS
	MOV	B,C
	CALL	PBINBCD	;PRINT EXPRESSION'S VALUE
	MVI	A,' '
	CALL	COUT
	JMP	MRENO+1
STR:	INX	H
	CALL	VAL	;GET START ADDRESS OF STRING IN BC AND PRINT
MRE:	LDAX	B
	CALL	COUT
	CPI	0FFH
	INX	B
	JNZ	MRE
	INX	H
	JMP	MRENO+1
INST:	INX	H	;INPUT STATEMENT
	CALL	CIN
	CPI	0	;IF SENSE SWITCHES DOWN, PRINT '?'
	JNZ	EAHR
	MVI	A,'?'
	CALL	COUT
	MVI	A,' '
	CALL	COUT
EAHR:	MOV	A,M
	CALL	CHEKLTR	;CHECK FOR VARIABLE
	JC	LVB
	CPI	'$'	;CHECK FOR INPUT STRING
	JZ	STRIN
	CPI	'('	;CHECK FOR SINGLE MEMORY LOCATION
	JNZ	ERR4
	CALL	VALDE	;GET LOCATION IN DE
	PUSH	H
	JMP	HS
LVB:	PUSH	H
	CALL	GETADR	;GET ADDRESS OF LETTER VARIABLE
HS:	PUSH	D
IHERE:	CALL	INPTXT	;INPUT A LINE
	CALL	CRLF
	LXI	H,TXT
	MOV	A,M
	CALL	CHEKN	;CHECK FOR A NUMBER
	JNC	LETR
FD:	INX	H
	MOV	A,M
	CALL	CHEKN
	JC	FD	;POINT TO FIRST NON-NUMERIC CHAR
	PUSH	B
	CALL	MKBIN	;CONVERT ASCII INPUT DATA TO BINARY
	POP	B
LETR:	POP	D
	STAX	D	;PUT A IN VARIABLE
CHK:	POP	H
	INX	H
	MOV	A,M
	CPI	','	;CHECK FOR MORE INPUT VARIABLES
	JZ	IN
	CALL	TERM
	JC	LPUB
	JMP	ERR5
STRIN:	INX	H	;INPUT STRING
	CALL	VAL	;GET FIRST MEMORY LOCATION IN BC
	PUSH	H
	PUSH	B
	CALL	INPXT
	POP	B
	CALL	CRLF
	LXI	H,TXT
LD:	MOV	A,M	;STORE TEXT BEGINNING AT SPECIFIED LOC
	CPI	CR
	JZ	TE
	STAX	B
	INX	B
	INX	H
	JMP	LD
TE:	MVI	A,0FFH	;STORE 377 AT END OF STRING
	STAX	B
	JMP	CHK
CLR:	LXI	D,VARSTOR	;CLEAR EXECUTOR	VAR STORAGE
LCR:	XRA	A
	STAX	D
	INX	D
	MOV	A,E
	CPI	VAREND AND 0FFH	;LAST VARIABLE LOCATION
	JNZ	LCR
	JMP	LPUB
CALLST:	NOP	;SKIP ASSUMED CHARACTERS
	INX	H
	INX	H
	INX	H
	CALL	VAL	;GET ADDRESS IN BC
	PUSH	H
	PUSH	D
	LXI	D,RETAD	;LOAD DE WITH RETURN ADDRESS
	PUSH	D	;PUSH RETURN ADDRESS ONTO STACK
	MOV	H,B
	MOV	L,C
	PCHL	;JUMP TO USER'S SUBROUTINE
RETAD:	POP	D
	POP	H
	JMP	LPUB
NEW:	LXI	D,PROG	;'NEW' PROCESSOR
	MVI	A,CR	;INITIALIZE PROGRAM AREA
	STAX	D
	INX	D
	MVI	A,0FFH
	STAX	D
	JMP	MINOL
INT:	PUSH	PSW	;THIS ROUTINE CHECKS FOR CONTROL C
	CALL	SENSE
	CPI	3	;CONTROL C
	JZ	BREAK
	POP	PSW
	RET
BREAK:	POP	D
	POP	D
	POP	D
	POP	D
	CALL	CRLF
	LXI	D,BRKMSG
	CALL	PRNTXT
	JMP	ATX
GOTO:	INX	H	;GOTO EXECUTOR
	INX	H	;SKIP ASSUMED CHARACTERS
	INX	H
	INX	H
	LXI	D,EXPR	;CALCULATE VALUE OF EXPRESSION
RME:	MOV	A,M
	STAX	D
	CALL	TERM
	INX	H
	INX	D
	JNC	RME
	CALL	EXPRS
	MOV	B,C
	MOV	A,C
	CPI	0
	JNZ	JUMP
	LXI	H,TXT
	JMP	DIRECT
JUMP:	LXI	H,PROG	;GOTO EXPRESSION
DUP:	MOV	A,M
	CPI	CR
	INX	H
	JNZ	DUP
	MOV	A,M
	CPI	0FFH
	JZ	ERR1
	CMP	B
	JNZ	DUP
	JMP	BIB
ERRMSG: DB	'!ERR ',0FFH
AT:	DB	' AT ',0FFH
BRKMSG: DB	'BREAK',0FFH
BIN:	DB	0
LNE:	DW	0	;CURRENT LINE NUMBER
ACT:	PUSH	B	;GETS THE VALUE OF A MEMORY LOCATION
	XCHG
	CALL	VAL	;PART OF THE EXPRS SUBROUTINE TO FOLLOW
	XCHG
	LDAX	B
	POP	B
	MOV	B,A
NXGT:	INX	D
	JMP	GETNET
NOTEQ:	MOV	A,E	;IF TWO EXPRESSIONS ARE NOT EQUAL, EXECUTE
	CMP	C	;STATEMENT (PART OF IF STATEMENT EXECUTOR
	JNZ	EXEC	;TO FOLLOW)
	JMP	LPUB
VALDE:	CALL	VAL
	MOV	D,B
	MOV	E,C
	RET
EXPRS:	PUSH	H	;CALCULATES THE VALUE OF AN EXPRESSION
	LXI	D,EXPR-1	;STORED IN MEMORY
	MVI	C,0	;DE IS THE CURSOR
RETPT:	LDAX	D
	CALL	TERM	;CHECK FOR END OF EXPRESSION
	JNC	GOMOR
	POP	H
	RET
GOMOR:	PUSH	PSW	;SAVE OPERATION ON STACK
	INX	D	;GET TERM/FACTOR
	LDAX	D
	CPI	47Q	;SINGLE CHARACTER VALUE
	JZ	ASC
	CPI	'('	;MEMORY LOCATION
	JZ	ACT
	CPI	'!'	;RANDOM NUMBER
	JZ	RND
	CALL	CHEKN
	JC	CONSTANT	;CONSTANT (NUMBER)
	CALL	CHEKLTR
	JNC	ERR5
	INX	D
IVAR:	PUSH	D	;VARIABLE
	CALL	GETADR
	LDAX	D
	MOV	B,A
	POP	D
GETNET: POP	PSW	;RETRIEVE OPERATION
	CPI	'+'
	JZ	ADD0
	CPI	'-'
	JZ	SUB0
	CPI	'*'
	JZ	MULT
	CPI	'/'
	JZ	DIV
	JMP	ERR5
ADD0:	MOV	A,C	;ADD C=C+B
	ADD	B
	MOV	C,A
	JMP	RETPT
SUB0:	MOV	A,C	;C=C-B
	SUB	B
	MOV	C,A
	JMP	RETPT
MULT:	MOV	A,C	;C=C*B
	DCR	B
GBK:	ADD	C
	DCR	B
	JNZ	GBK
	MOV	C,A
	JMP	RETPT
DIV:	MOV	A,C	;C=C/B
	MVI	C,0
CTUE:	INR	C	
	SUB	B
	JZ	ZER
	JC	MIN
	JMP	CTUE
MIN:	DCR	C
ZER:	JMP	RETPT
CONSTANT: INX D
	LDAX	D
	CALL	CHEKN
	JC	CONSTANT
	XCHG
	CALL	SURE
	XCHG
	MOV	B,A
	JMP	GETNET
ASC:	INX	D
	LDAX	D
	MOV	B,A
	INX	D
	JMP	NXGT
RND:	LXI	H,SH+3
	MVI	B,8
	MOV	A,M
RTOP:	RLC
	RLC
	RLC
	XRA	M
	RAL
	RAL
	DCR	L
	DCR	L
	DCR	L
	MOV	A,M
	RAL
	MOV	M,A
	INR	L
	MOV	A,M
	RAL
	MOV	M,A
	INR	L
	MOV	A,M
	RAL	
	MOV	M,A
	INR	L
	MOV	A,M
	RAL
	MOV	M,A
	INR	B
	JNZ	RTOP
	MOV	B,A
	JMP	NXGT
SH:	DB	21Q,231Q,132Q,351Q	;SEED
INPTXT: MVI	C,0	;INPUT A LINE OF 72 CHARACTERS
INPXT:	LXI	H,TXT-1
INO:	CALL	INPUT
HRER:	MOV	B,A
	MOV	A,C
	CPI	0
	MOV	A,B
	JNZ	MID
	CPI	' '
	JZ	INO	;DO NOT ACCEPT SPACE IF OUTSIDE QUOTES
MID:	CPI	'"'
	JNZ	GOON
	MOV	A,C
	CPI	0
	JZ	MRF
	MVI	C,0
	JMP	GOON
MRF:	MVI	C,3
GOON:	CPI	14Q	;IF CONTROL L REDO LINE
	JNZ	HRD
	MVI	A,'\'
	CALL	COUT
	CALL	CRLF
	JMP	INPTXT
HRD:	CPI	CR
	JNZ	CHM
	JMP	HELP
CHM:	CPI	23Q	;IF CONTROL S GO BACK A CHARACTER
	JNZ	CTN
	MVI	A,'_'
	CALL	COUT
	DCX	H
	JMP	INO
CTN:	MOV	A,L
	CPI	TXTEND AND 0FFH
	JZ	ERR2	;IF OVER 72 CHARACTERS REPORT ERROR
	INX	H
STOR:	MOV	M,B
	JMP	INO
ERR1:	MVI	B,'1'
	JMP	ERR
ERR2:	MVI	B,'2'
	JMP	ERR
ERR3:	MVI	B,'3'
	JMP	ERR
ERR4:	MVI	B,'4'
	JMP	ERR
ERR5:	MVI	B,'5'
	JMP	ERR
ERR6:	MVI	B,'6'
ERR:	CALL	CRLF	;PRINT 'ERR' MESSAGE
	LXI	D,ERRMSG
	CALL	PRNTXT
	MOV	A,B
	CALL	COUT
ATX:	LXI	D,AT
	CALL	PRNTXT
	LDA	LNE
	MOV	B,A
	CALL	PBINBCD
	CALL	CRLF
	JMP	MINOL
MKBIN:	PUSH	D	;GET VALUE OF ASCII NUMBERS
	DCX	H
	MOV	A,M
	SUI	'0'
	MOV	B,A
	DCX	H
	MOV	A,M
	CALL	CHEKN
	JC	STOC
	MVI	C,0
	MVI	E,0
	JMP	INK2
STOC:	SUI	'0'
	MOV	C,A
ENT:	DCX	H
	MOV	A,M
	CALL	CHEKN
	JC	STOE
	MVI	E,0
	JMP	INK3
STOE:	MOV	A,M
	SUI	'0'
	MOV	E,A
INK3:	INX	H
INK2:	INX	H
	INX	H
	CALL	BCDBIN
	MOV	A,B
	STA	BIN
	POP	D
	RET
GETADR: PUSH	H	;GET ADDRESS OF VARIABLE
	LXI	D,VARSTOR
	SUI	'A'
	MVI	H,0
	MOV	L,A
	DAD	D
	XCHG
	POP	H
	RET
PRNTXT: LDAX	D	;PRINT TEXT POINTED BY DE
	CPI	0FFH
	RZ
	CALL	COUT
	INX	D
	JMP	PRNTXT
CHEKLTR:	STC	;CHECK IF CHAR IS A LETTER
	CMC
	CPI	'A'
	JC	NOTAP
	STC
	CPI	'Z'+1
	RET
NOTAP:	CMC
	RET
VARSTOR: DS	27	;VARIABLE STORAGE
VAREND: DS	1
TERM:	CPI	CR	;CHECK FOR STATEMENT TERMINATOR
	JZ	YES
	CPI	':'
	JZ	YES
	STC
	CMC
	RET
YES:	STC
	RET
CHEKN:	STC
	CMC
	CPI	'0'
	JC	NOTA
	STC
	CPI	'9'+1
	RET
NOTA:	CMC
	RET
BCDBIN: MVI	A,10	;BCD TO BINARY ROUTINE
	ADD	B
	MOV	B,A
	DCR	C
	JNZ	BCDBIN
SEC:	MOV	C,E
	MOV	A,E
	CPI	0FFH
THI:	RZ
	MVI	A,100
	ADD	B
	MOV	B,A
	DCR	C
	JMP	THI
LIST:	LXI	D,PROG+1	;LIST COMMAND
NEXN:	LDAX	D
	CPI	0FFH
	JZ	LPUB
	MOV	B,A
	CALL	PBINBCD
	MVI	A,' '
	CALL	COUT
	INX	D
	LDAX	D
OU:	CALL	COUT
	CPI	CR
	JNZ	MREN
	INX	D
	CALL	CRLF
	JMP	NEXN
MREN:	INX	D
	LDAX	D
	JMP	OU
PBINBCD: PUSH B	;PRINT BINARY NUMBER
	PUSH	D
	MVI	D,0
	MOV	C,D
	MOV	A,B
IFIR:	SUI	100
	JC	ISEC
	INR	C
	JMP	IFIR
ISEC:	MVI	B,100
	ADD	B
	MOV	B,A
	MVI	A,'0'
	ADD	C
	CPI	'0'
	JZ	NP
	CALL	COUT
COM:	MVI	C,0
	MOV	A,B
ITHR:	SUI	10
	JC	FOR
	INR	C
	JMP	ITHR
FOR:	MVI	B,10
	ADD	B
	MOV	B,A
	MVI	A,'0'
	ADD	C
	CPI	'0'
	JZ	INU
IPR:	CALL	COUT
DPR:	MVI	A,'0'
	ADD	B
	CALL	COUT
	POP	D
	POP	B
	RET
NP:	MVI	D,1
	JMP	COM
INU:	MOV	C,A
	XRA	A
	CMP	D
	MOV	A,C
	JNZ	DPR
	JMP	IPR
SURE:	PUSH	B	;SAVES BC AND CALLS MKBIN
	CALL	MKBIN
	POP	B
	RET
HELP:	INX	H	;ADDS 377 TERMINATOR AT END OF INPUT TEXT
	MOV	M,B
	INX	H
	MVI	M,0FFH
	RET
IFST:	LXI	D,EXPR	;IF STATEMENT
NGO:	INX	H	;FIRST EXPRESSION
	MOV	A,M
	CPI	43Q	;# SIGN
	JZ	COMP
	CPI	'='
	JZ	COMP
	CPI	'<'
	JZ	COMP
	CALL	TERM
	JC	ERR5
	STAX	D
	INX	D
	JMP	NGO
COMP:	PUSH	PSW
	MVI	A,CR
	STAX	D
	CALL	EXPRS
	PUSH	B
	LXI	D,EXPR
NXTVR:	INX	H	;SECOND EXPRESSION
	MOV	A,M
	CPI	';'
	JZ	PHI
	CALL	TERM
	JC	ERR5
	STAX	D
	INX	D
	JMP	NXTVR
PHI:	INX	H
	MVI	A,CR
	STAX	D
	CALL	EXPRS
	POP	D
	POP	PSW
	CPI	43Q	;CHECK RELATIONAL OPERATOR	(# SIGN HERE)
	JZ	NOTEQ
	CPI	'<'
	JZ	LESSTH
EQU0:	MOV	A,E	;CHECK IF =
	CMP	C
	JZ	EXEC
	JMP	LPUB
LESSTH: MOV	A,E	;CHECK IF <
	CMP	C
	JNC	LPUB
	JMP	EXEC
VAL:	PUSH	D	;GET ADDRESS OF MEMORY LOCATION
	LXI	D,EXPR
SHME:	INX	H
	MOV	A,M
	STAX	D
	CALL	TERM
	INX	D
	JC	ERR5
	CPI	','
	JNZ	SHME
	DCX	D
	MVI	A,CR
	STAX	D
	CALL	EXPRS
	PUSH	B
	LXI	D,EXPR
MIG:	INX	H
	MOV	A,M
	STAX	D
	CALL	TERM
	INX	D
	JC	ERR5
	CPI	')'
	JNZ	MIG
	DCX	D
	MVI	A,CR
	STAX	D
	CALL	EXPRS
	MOV	A,C
	POP	B
	MOV	B,C
	MOV	C,A
	POP	D
	RET
	DB	'+'
EXPR:	DS	31	;EXPRESSION BUFFER
TXT:	DS	72	;LINE BUFFER (INPUT TEXT)
TXTEND: DS	1
; 
	ORG	PROGST
PROG:	DB	CR,0FFH
; 
	END	MINOL
