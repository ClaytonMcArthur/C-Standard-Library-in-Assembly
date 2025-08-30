        ;============================================================================
        ; heap.s  – 32-byte-unit buddy allocator for TM4C129 (CSS 422)
        ;============================================================================
        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB

        EXPORT  _kinit
        EXPORT  _kalloc
        EXPORT  _ralloc
        EXPORT  _kfree
        EXPORT  _rfree

; ---- constants ------------------------------------------------------------
HEAP_TOP        EQU     0x20001000
HEAP_BOT        EQU     0x20004FFF
HEAP_SIZE       EQU     0x00004000          ; 16 KiB
MIN_SIZE        EQU     32                  ; bytes per unit
MCB_ENT_SZ      EQU     2                   ; 2 bytes per entry (buddy)
MCB_TOP         EQU     0x20006800          ; MCB at 0x20006800, 2 bytes per block

;============================================================================
; void _kinit(void);
;   – clear all headers in MCB (all free)
;============================================================================
_kinit
        PUSH    {R4,LR}
        LDR     R4, =MCB_TOP
        MOVS    R5, #0
        MOVW    R6, #512          ; 512 blocks for 16K heap @ 32 bytes each
zero_loop
        STRH    R5, [R4], #2
        SUBS    R6, R6, #1
        BNE     zero_loop
        POP     {R4,PC}
        ENDP

;============================================================================
; void * _kalloc(int nBytes);
;   – unchanged (first-fit allocation)
;============================================================================
_kalloc
        PUSH    {R4-R7,LR}
        MOV     R4, R0
        ADDS    R4, #MIN_SIZE-1
        LSRS    R4, #5
        CMP     R4, #1
        BGE     alloc_ok
        MOVS    R4, #1
alloc_ok
        MOV     R5, R4
        LDR     R6, =MCB_TOP
        MOVS    R7, #0
scan_loop
        CMP     R7, #512
        BGE     alloc_fail
        LDRH    R2, [R6, R7, LSL #1]
        CMP     R2, #0
        BEQ     found_free
        ADDS    R7, #1
        B       scan_loop
found_free
        ; mark as used, set size code
        MOV     R1, R5
        LSLS    R1, R1, #4
        ORR     R1, R1, #1
        STRH    R1, [R6, R7, LSL #1]
        ; calculate pointer
        LDR     R0, =HEAP_TOP
        ADD     R0, R0, R7, LSL #5
        POP     {R4-R7,PC}
alloc_fail
        MOVS    R0, #0
        POP     {R4-R7,PC}
        ENDP

;============================================================================
; void * _ralloc(int nBytes);
;   – unchanged (optional, as per template)
;============================================================================
_ralloc
        ; Leave blank or copy kalloc logic if not used in your driver
        BX      LR
        ENDP

;============================================================================
; void _kfree(void *ptr);
;   – Frees a block by clearing used bit and attempting buddy merge
;============================================================================
_kfree
        PUSH    {R4-R7,LR}
        LDR     R1, =HEAP_TOP
        CMP     R0, R1
        BLT     _kf_bad
        LDR     R2, =HEAP_BOT
        CMP     R0, R2
        BGT     _kf_bad

        SUB     R3, R0, R1
        LSRS    R3, R3, #5
        LSLS    R3, R3, #1
        LDR     R2, =MCB_TOP
        ADD     R0, R2, R3
        BL      _rfree

_kf_bad
        POP     {R4-R7,PC}
        ENDP

;============================================================================
; Recursive helper: _rfree( int mcb_addr )
;   – Clears "used" bit, merges with buddy if possible, recurses up.
;============================================================================
_rfree  PROC
        PUSH    {R1-R8, LR}

        ; Load and clear "used" bit, preserve size
        LDRH    R2, [R0]         ; R2 = block header
        BIC     R2, R2, #1       ; clear used bit
        STRH    R2, [R0]

        ; Get block size in MIN_SIZE units (size_code)
        MOV     R3, R2
        LSRS    R3, R3, #4       ; size_code
        MOV     R4, R3
        LSLS    R3, R3, #4       ; block size in bytes

        ; Compute entry index in MCB
        LDR     R5, =MCB_TOP
        SUB     R6, R0, R5
        LSRS    R6, R6, #1       ; R6 = index

        ; Compute buddy index
        EOR     R7, R6, R4       ; R7 = buddy index

        ; Compute buddy address
        LSLS    R8, R7, #1       ; offset in bytes
        ADD     R8, R5, R8       ; R8 = buddy address

        ; Get buddy header and check if it's the same size and free
        LDRH    R1, [R8]
        TST     R1, #1           ; used bit set?
        BNE     _rf_done
        LSRS    R1, R1, #4       ; buddy size_code
        CMP     R1, R4
        BNE     _rf_done

        ; Always merge into the lower address
        CMP     R0, R8
        BLT     _merge_left
        MOV     R0, R8

_merge_left
        ; Double block size, clear buddy
        LDRH    R2, [R0]
        ADD     R2, R2, R2
        BIC     R2, R2, #1
        STRH    R2, [R0]
        MOVS    R1, #0
        STRH    R1, [R8]
        BL      _rfree

_rf_done
        POP     {R1-R8, PC}
        ENDP

        END