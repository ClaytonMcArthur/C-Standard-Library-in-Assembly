		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Timer Definition
STCTRL		EQU		0xE000E010		; SysTick Control and Status Register
STRELOAD	EQU		0xE000E014		; SysTick Reload Value Register
STCURRENT	EQU		0xE000E018		; SysTick Current Value Register
	
STCTRL_STOP	EQU		0x00000004		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 0, Bit 0 (ENABLE) = 0
STCTRL_GO	EQU		0x00000007		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 1, Bit 0 (ENABLE) = 1
STRELOAD_MX	EQU		0x00FFFFFF		; MAX Value = 1/16MHz * 16M = 1 second
STCURR_CLR	EQU		0x00000000		; Clear STCURRENT and STCTRL.COUNT	
SIGALRM		EQU		14			; sig alarm

; System Variables
SECOND_LEFT		EQU		0x20007B80		; Secounds left for alarm( )
USR_HANDLER     EQU		0x20007B84		; Address of a user-given signal handler function	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer initialization
; void timer_init( )
        EXPORT  _timer_init
_timer_init
        ; disable SysTick
        LDR     R0, =STCTRL
        MOV     R1, #STCTRL_STOP
        STR     R1, [R0]

        ; clear current count
        LDR     R0, =STCURRENT
        MOV     R1, #0
        STR     R1, [R0]

        ; clear SECOND_LEFT
        LDR     R0, =SECOND_LEFT
        MOV     R1, #0
        STR     R1, [R0]

        ; clear USR_HANDLER
        LDR     R0, =USR_HANDLER
        MOV     R1, #0
        STR     R1, [R0]

        BX      LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer start
; int timer_start( int seconds )
        EXPORT  _timer_start
_timer_start
        ; r0 = requested seconds
        MOV     R2, R0               ; save new value in R2

        ; read old countdown
        LDR     R1, =SECOND_LEFT
        LDR     R0, [R1]

        ; store new countdown
        STR     R2, [R1]

        ; clear current reload counter
        LDR     R1, =STCURRENT
        MOV     R2, #0
        STR     R2, [R1]

        ; load maximum reload
        LDR     R1, =STRELOAD
        LDR     R2, =STRELOAD_MX
        STR     R2, [R1]

        ; enable SysTick with interrupt
        LDR     R1, =STCTRL
        MOV     R2, #STCTRL_GO
        STR     R2, [R1]

        ; return old countdown in R0
        BX      LR


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void timer_update( )
        EXPORT  _timer_update
_timer_update
        ; load current countdown
        LDR     R0, =SECOND_LEFT
        LDR     R1, [R0]
        CMP     R1, #0
        BEQ     _tu_done            ; nothing to do if zero

        ; decrement
        SUBS    R1, R1, #1
        STR     R1, [R0]
        CMP     R1, #0
        BNE     _tu_done            ; still counting

        ; countdown hit zero ? disable SysTick
        LDR     R0, =STCTRL
        MOV     R1, #STCTRL_STOP
        STR     R1, [R0]

        ; call the user’s handler: USR_HANDLER(SIGALRM)
        LDR     R0, =USR_HANDLER
        LDR     R0, [R0]            ; fetch handler pointer
        MOV     R1, #SIGALRM
        BLX     R0                  ; invoke handler(signum)

_tu_done
        BX      LR


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void* signal_handler( int signum, void* handler )
        EXPORT  _signal_handler
_signal_handler
        ; r0 = signum (ignored except for SIGALRM)
        ; r1 = new handler pointer
        LDR     R2, =USR_HANDLER
        LDR     R0, [R2]            ; old handler in R0
        STR     R1, [R2]            ; store new handler
        BX      LR

        END