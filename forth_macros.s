; program: forth_macros
; The core macros of the forth interpreter.
;
; This file is a translation of jonesforth 
; (http://www.annexia.org/_file/jonesforth.s.txt) for being compiled with nasm.

; License: GPL
; José Dinuncio <jdinunci@uc.edu.ve>, 12/2009.
; This file is based on Bran's kernel development tutorial file start.asm

; Topic: Forth macros
;
; This file and *forth_core.s* are the base of the forth system. 
; Here are defined the most basic macros of the forth kernel.

; Bug in defcode macro corrected . august0815 14.12.2009
; autodoc with NaturalDocs 19.12.2009

[BITS 32]
; word flags
            FF_IMMED    equ  0x80    ; Word is inmediate
            FF_HIDDEN   equ  0x20    ; Word is hidden
            FF_LENMASK  equ  0x1f    ;
            %define LINK 0           ; Address of the last header word


; macro: NEXT
; Execute the next forth word.
;
; Every defcode (a forth word coded in assembly) must end with this macro.
; It loads in eax the dword which address is in esi and increments esi.
; Then, it jumps to the address in eax. In this way, esi always contains the
; address of the next word to execute.
%macro NEXT 0
            lodsd                   ; eax <- mem[esi], esi <- esi+4
            jmp [eax]
%endmacro

; macro: PUSHRSP
; Push the return stack
%macro PUSHRSP 1
            lea ebp, [ebp-4]
            mov [ebp], %1
%endmacro

; macro: POPRSP
; Pop the return stack
%macro POPRSP 1
            mov %1, [ebp]
            lea ebp, [ebp+4]
%endmacro

; macro: defword
; Define a forth word.
;
; A forth word is a serie of pointers to the codewords that implement it. It
; must end with the EXIT word.
;
; Parameters:
; name - The forth name of the word.
; label - The assembly name of the word.
; flags - Forth flags of the word.
%macro defword 3
    section .rodata                 ; Define this word in the rodata
            align 4                 ;   section, aligned and with a 
            GLOBAL label_%2         ;   global name
            %defstr name %1         ; Set the name and length of this
            %strlen name_len name   ;   word
            %undef OLDLINK          ; Updates OLDLINK and LINK to
            %xdefine OLDLINK LINK   ;   link this word with the
            %undef LINK             ;   previous one
            %xdefine LINK name_%2   ;
    name_%2:
            dd  OLDLINK             ; LINK to the previous word
            db %3 + name_len        ; Flags + len(name)
            db name                 ; Name of the word

            align 4                 ; Start the definition in a 4 bytes
            GLOBAL %2               ;   boundary
    %2:
            dd DOCOL                ; codeword of this word
%endmacro

; macro: defcode
; Define a forth code word, a forth word implemented in assembler.
;
; The body of a code word is an assebler routine. The routine must end
; with the NEXT macro to make the forth interpreter execute the next
; operation.
;
; Parameters:
; name - The forth name of the word.
; label - The assembly name of the word.
; flags - Forth flags of the word.
%macro defcode 3
   section .rodata                  ; Define this word in the rodata
            align 4                 ;   section, aligned and with a 
            GLOBAL label_%2         ;   global name
            %defstr name %1         ; Set the name and length of this
            %strlen name_len name   ;   word
            %undef OLDLINK          ; Updates OLDLINK and LINK to
            %xdefine OLDLINK LINK   ;   link this word with the
            %undef LINK             ;   previous one
            %xdefine LINK name_%2   ;
    name_%2:
            dd  OLDLINK             ; Links to the previous word
            db %3 + name_len        ; Flags + len(name)
            db name                 ; Name of the word

            align 4                 ; Start the definition in a 4 bytes
            GLOBAL %2               ;   boundary
    %2:
            dd code_%2              ; codeword of this word
    section .text                   ; Here starts the assembler for this
            align 4                 ;   word
            GLOBAL code_%2          ;
    code_%2:
%endmacro

; macro: defvar
; Define a forth variable. It is a word that pushes in the stack the address
; of the variable.
;
; Parameters:
; name - The forth name of the word.
; label - The assembly name of the word.
; flags - Forth flags of the word.
; value - The initial value of the variable.
%macro defvar 4
            defcode %1, %2, %3
            push var_%2
            NEXT
    section .data
            align 4
    global var_%2
    var_%2:
            dd %4
%endmacro

; macro: defconst
; Define a forth constant. It is a word that pushes in the stack the value
; of the constant.
;
; Parameters:
; name - The forth name of the word.
; label - The assembly name of the word.
; flags - Forth flags of the word.
; value - The value of the constant.
%macro defconst 4
            defcode %1, %2, %3
            push %4
            NEXT
%endmacro

; macro:  LITN
; Insert in a forth word a literal value.
;
; Parametes:
; v - The literal value.
%macro LITN 1
            dd LIT
            dd %1
%endmacro

; macro: branch
; Unconditional branch
;
; Parameters:
; label - The label to branch to.
%macro branch 1
        dd BRANCH 
        dd %1 - $
%endmacro

; macro: zbranch
; Branch if zero
;
; Parameters:
; label - The label to branch to.
%macro zbranch 1
        dd ZBRANCH 
        dd %1 - $
%endmacro

; macro: if
; The IF part of the if-else-the structure. 
;
; e.g.:
; | cond if
; | action_if_true else
; | action_if_false then
; 
; or
; | cond if
; | action then
%macro if 0
        %push if_cond
        zbranch %$ifnot
%endmacro

; macro: else
; The ELSE part of the if-else-then structure.
%macro else 0
        %repl else_cond
        branch %$exit
    %$ifnot:
%endmacro

; macro: then
; The THEN part of the if-else-then structure.
%macro then 0
        %ifctx if_cond
            %$ifnot:
        %endif
    %$exit:
        %pop 
%endmacro

; macro: do
; The DO part of do-loop structure.
; 
;  e.g.:
;  |        LITN 80*25              ; for i = 0 to 80*25
;  |        LITN 0                  ;
;  |        do
;  |             LITN ' '           ;   emit ' '
;  |             dd EMIT            ;
;  |        loop
%macro do 0
        %push do_loop
    %$loop:
        dd TWODUP
        dd GE
        zbranch %$exit
%endmacro

; macro: loop
; The LOOP part of the do-loop structure.
%macro loop 0
        dd INCR
        branch %$loop
    %$exit:
        dd DROP, DROP
        %pop
%endmacro


; macro: begin
; the BEGIN part of the begin-until structure.
; 
; e.g.:
; | begin
; |     actions
; |     cond
; | until
%macro begin 0
        %push begin_loop
    %$loop:
%endmacro

; macro: until
; the UNTIL part of the begin-until structure.
%macro until 0
        zbranch %$loop
    %$exit:
        %pop
%endmacro

; macro: while
; The WHILE part of the begin-while-repeat structure.
; 
;  e.g :
;  | begin
;  |    dd DUP, FETCHBYTE, DUP
;  | while
;  |    dd EMIT, INCR
;  | repeat
%macro while 0
        zbranch %$exit
%endmacro

; macro: repeat
; The REPEAT part of the begin-while-repeat structure.
%macro repeat 0
        branch %$loop
    %$exit:
        %pop
%endmacro

; macro: leave
; Exit the current loop.
%macro leave 0
        branch %$exit
        %pop
%endmacro


%macro call_forth 1
            push esi
            mov esi, %%forthcode
            NEXT
    %%end:  pop esi

    section .rodata
    %%forthcode:
            dd %1
            dd %%call_end
    %%call_end:
            dd %%end
    section .text
%endmacro

