		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;; Import all functions 
        IMPORT  _kalloc
        IMPORT  _kfree
        IMPORT  _timer_start
        IMPORT  _signal_handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table
SYSTEMCALLTBL	EQU		0x20007B00 ; originally 0x20007500
SYS_EXIT		EQU		0x0		; address 20007B00
SYS_ALARM		EQU		0x1		; address 20007B04
SYS_SIGNAL		EQU		0x2		; address 20007B08
SYS_MEMCPY		EQU		0x3		; address 20007B0C
SYS_MALLOC		EQU		0x4		; address 20007B10
SYS_FREE		EQU		0x5		; address 20007B14

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table Initialization
        EXPORT  _syscall_table_init
_syscall_table_init   PROC
        LDR     R0, =SYSTEMCALLTBL
        MOV     R1, #0              ; entry 0 = exit (unused)
        STR     R1, [R0, #0]

        LDR     R1, =_kalloc        ; entry 1 = malloc
        STR     R1, [R0, #4]
        LDR     R1, =_kfree         ; entry 2 = free
        STR     R1, [R0, #8]
        LDR     R1, =_timer_start   ; entry 3 = alarm
        STR     R1, [R0, #12]
        LDR     R1, =_signal_handler; entry 4 = signal
        STR     R1, [R0, #16]
        BX      LR
        ENDP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table Jump Routine
        EXPORT  _systemcall_table_jump
_systemcall_table_jump PROC
        ; R0 = stacked frame pointer
        PUSH    {R4-R6, LR}

        MOV     R4, R0              ; save sp
        LDR     R0, [R4, #0]        ; arg0
        LDR     R1, [R4, #4]        ; arg1
        LDR     R2, [R4, #8]        ; arg2
        LDR     R3, [R4, #12]       ; arg3

        ; pull imm8 from the SVC instruction
        LDR     R5, [R4, #24]       ; stacked PC
        SUBS    R5, R5, #2          ; point at SVC opcode
        LDRH    R6, [R5]            ; 0xDFxx
        AND     R6, R6, #0xFF       ; low 8 bits = svc number

        LDR     R5, =SYSTEMCALLTBL
        LSLS    R6, R6, #2          ; index*4
        ADD     R5, R5, R6
        LDR     R5, [R5]            ; handler address

        BLX     R5                  ; call it
        STR     R0, [R4, #0]        ; write return value back

        POP     {R4-R6, PC}         ; return from exception
        ENDP

        END