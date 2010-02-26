; program: forth_core.s
; The core functions of the forth interpreter.
;
; This file is a translation of jonesforth 
; (http://www.annexia.org/_file/jonesforth.s.txt) for being compiled with nasm.

; License: GPL
; José Dinuncio <jdinunci@uc.edu.ve>, 12/2009.
; This file is based on Bran's kernel development tutorial file start.asm

%include "forth_macros.s"
extern main

[BITS 32]
; Topic: forth core
; Forth is an extensible, powerfull concatenative language/environment. This
; file contains the core routines needed for a minimal functional forth
; environment.
;
; Forth code is based in 'words'. A word can be implemented in assembly or 
; using exclusively predefined words. We will call the formers defcode words 
; and the laters defword words.
;
; This is the word structure in this implementation
;
; | +---------------+
; | |     LINK      |  Link to the previous word
; | +---------------+
; | |  FLAGS + LEN  |  Several flags + length of the word name
; | +---------------+
; | |     NAME      |  Word name (4 bytes aligned)
; | +---------------+
; | |   CODEWORD    |  Pointer to the routine that executes this word
; | +---------------+
; | |     BODY      |  Optionally, if this is a defword, a serie of
; | +---------------+    pointers to the codewors of each word that
; | |     ...       |    define the current word.
; | +---------------+
;
; The next word to be executed is pointed by the esi register. The next macro
; is the responsable for its execution and the esi update.
;
; If the word to be executed is a defcode, its implementation is in assembly.
; In this case, CODEword points directly to the assembly routine. The assembly
; routine must end with the next macro, to execute the next word.
;
; If the word to be executed is a defword, its codeword must point to DOCOL.
; DOCOL executes the word body. The word body is a serie of pointer to the
; codewords of each one of the words in this definition. DOCOL pushes on the
; *return stack* the address of the next word to execute and then executes
; one by one the words on the current word body. The word body must end with
; the exit word to restore the address of the next word to execute.

; ============================================================================
;    Virtual Machine Variables
; ============================================================================
; var: statE       
; Is the interpreter executing code (0) or compiling (non-zero)?
defvar STATE, STATE, 0, 0

; var: HERE        
; Points to the next free byte of memory.
defvar HERE, HERE, 0, 0

extern last_word
; var LAtest       
; Points to the newset  word in the dictionary.
defvar LATEST, LATEST, 0, last_word; SySCALL0 must be last in built-in dictionary

; var: S0          
; Stores the address of the top of the parameter stack.
defvar S0, S0, 0, 0

; var: BASE        
; The current base for printing and reading numbers.
defvar BASE, BASE, 0, 10

extern top
; var: TOPMEM
defvar TOPMEM, TOPMEM, 0, top ; SYSCALL0 must be last in built-in dictionary

; var: NOECHO
defvar NOECHO, NOECHO, 0, 1 ; Flag if message is printed when compiling is succsesfull ??

; var: text_buff
defvar TEXT_BUFF, TEXT_BUFF, 0 ,0

; var: PPRT (pointer_to_print) 
defvar PPTR, PPTR, 0 , 0
defvar PPTR_LAST, PPTR_LAST, 0 , 0
defvar SRC, SRC, 0 , 0
defvar SRC_END, SRC_END, 0 , 0
defvar FILP, FILP, 0 , 0
defvar GRUB, GRUB, 0, 0


; ============================================================================
;       Virtual Machine constants
; ============================================================================
; const: VERSION
; The current version of this FORTH.
defconst VERSION, VERSION, 0, 1

extern return_stack_top
; const: R0          
; The address of the top of the return stack.
defconst R0, R0, 0, return_stack_top

; const: DOCOL       
; Pointer to DOCOL.
defconst DOCOL, __DOCOL, 0, DOCOL

; const: F_IMMED     
; The IMMEDIATE flag's actual value.
defconst F_IMMED, __F_IMMED, 0, 0x80

; const: F_HIDDEN    
; The HIDDEN flag's actual value.
defconst F_HIDDEN, __F_HIDDEN, 0, 0x20

; const: F_LENMASK   
;The length mask in the flags/len byte.
defconst F_LENMASK, __F_LENMASK, 0, 0x1f


; ============================================================================
;       Virtual Machine main functions
; ============================================================================
section .text
align 4

; function: DOCOL
;   This is the core of the forth virtual machine. This routine executes the
;   non-native words. A non-native word is formed by a serie of pointers to the 
;   codewords of other forth words. DOCOL executes each one of these codewords.
global DOCOL
DOCOL:
        pushrsp esi         ; Saves the return point
        add eax, 4          ; eax pointed to the codeword of this word,
        mov esi, eax        ;   now esi points to the first word
        next

; function: exit
;   exit is the last word of a defword (a non-defcode word). It restores the 
;   value of esi, stored in the return stack by DOCOL when this word started.
defcode exit, exit, 0
        poprsp esi          ; Pops the address of the word to return to
        next                ; and executes it

global name_exit
