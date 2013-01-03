; Standard definitions of Mode bits and Interrupt (I & F) flags in PSRs

Mode_USR        EQU     0x10
Mode_FIQ        EQU     0x11
Mode_IRQ        EQU     0x12
Mode_SVC        EQU     0x13
Mode_ABT        EQU     0x17
Mode_UND        EQU     0x1B
Mode_SYS        EQU     0x1F

I_Bit           EQU     0x80            ; when I bit is set, IRQ is disabled
F_Bit           EQU     0x40            ; when F bit is set, FIQ is disabled


;// <h> Stack Configuration (Stack Sizes in Bytes)
;//   <o0> Undefined Mode      <0x0-0xFFFFFFFF:8>
;//   <o1> Supervisor Mode     <0x0-0xFFFFFFFF:8>
;//   <o2> Abort Mode          <0x0-0xFFFFFFFF:8>
;//   <o3> Fast Interrupt Mode <0x0-0xFFFFFFFF:8>
;//   <o4> Interrupt Mode      <0x0-0xFFFFFFFF:8>
;//   <o5> User/System Mode    <0x0-0xFFFFFFFF:8>
;// </h>

UND_Stack_Size  EQU     0x00000000
SVC_Stack_Size  EQU     0x00000080
ABT_Stack_Size  EQU     0x00000000
FIQ_Stack_Size  EQU     0x00000000
IRQ_Stack_Size  EQU     0x00000080
USR_Stack_Size  EQU     0x00000000

ISR_Stack_Size  EQU     (UND_Stack_Size + SVC_Stack_Size + ABT_Stack_Size + \
                         FIQ_Stack_Size + IRQ_Stack_Size)

        		AREA     RESET, CODE
				ENTRY
;  Dummy Handlers are implemented as infinite loops which can be modified.

Vectors         LDR     PC, Reset_Addr         
                LDR     PC, Undef_Addr
                LDR     PC, SWI_Addr
                LDR     PC, PAbt_Addr
                LDR     PC, DAbt_Addr
                NOP                            ; Reserved Vector 
                LDR     PC, IRQ_Addr
;               LDR     PC, [PC, #-0x0FF0]     ; Vector from VicVectAddr
                LDR     PC, FIQ_Addr

ACBASE			DCD		P0COUNT
SCONTR			DCD		SIMCONTROL

Reset_Addr      DCD     Reset_Handler
Undef_Addr      DCD     Undef_Handler
SWI_Addr        DCD     SWI_Handler
PAbt_Addr       DCD     PAbt_Handler
DAbt_Addr       DCD     DAbt_Handler
                DCD     0                      ; Reserved Address 
FIQ_Addr        DCD     FIQ_Handler

Undef_Handler   B       Undef_Handler
SWI_Handler     B       SWI_Handler
PAbt_Handler    B       PAbt_Handler
DAbt_Handler    B       DAbt_Handler
FIQ_Handler     B       FIQ_Handler


				AREA 	ARMuser, CODE,READONLY

IRQ_Addr        DCD     ISR_FUNC1
EINT2			EQU 	16
Addr_VicIntEn	DCD		0xFFFFF010	 	; set to (1<<EINT0)
Addr_EXTMODE	DCD 	0xE01FC148   	; set to 1
Addr_PINSEL0	DCD		0xE002C000		; set to 2_1100
Addr_EXTINT		DCD		0xE01FC140

;  addresses of two registers that allow faster input

Addr_IOPIN		DCD		0xE0028000


; Initialise the Interrupt System
;  ...
ISR_FUNC1		STMED	R13!, {R0,R1}
				MOV 	R0, #(1 << 2) 	   ; bit 2 of EXTINT
				LDR 	R1,	Addr_EXTINT	   
				STR		R0, [R1]		   ; EINT2 reset interrupt
				LDMED	R13!, {R0,R1}
				B 		ISR_FUNC

Reset_Handler
; PORT0.1 1->0 triggers EINT0 IRQ interrupt
				MOV R0, #(1 << EINT2)
				LDR R1, Addr_VicIntEn
				STR R0, [R1]
				MOV R0, #(1 << 30)
				LDR R1, Addr_PINSEL0
				STR R0, [R1]
				MOV R0, #(1 << 2)
				LDR R1, Addr_EXTMODE
				STR R0, [R1]

;  Setup Stack for each mode

                LDR     R0, =Stack_Top

;  Enter Undefined Instruction Mode and set its Stack Pointer
                MSR     CPSR_c, #Mode_UND:OR:I_Bit:OR:F_Bit
                MOV     SP, R0
                SUB     R0, R0, #UND_Stack_Size

;  Enter Abort Mode and set its Stack Pointer
                MSR     CPSR_c, #Mode_ABT:OR:I_Bit:OR:F_Bit
                MOV     SP, R0
                SUB     R0, R0, #ABT_Stack_Size

;  Enter FIQ Mode and set its Stack Pointer
                MSR     CPSR_c, #Mode_FIQ:OR:I_Bit:OR:F_Bit
                MOV     SP, R0
                SUB     R0, R0, #FIQ_Stack_Size

;  Enter IRQ Mode and set its Stack Pointer
                MSR     CPSR_c, #Mode_IRQ:OR:I_Bit:OR:F_Bit
                MOV     SP, R0
                SUB     R0, R0, #IRQ_Stack_Size

;  Enter Supervisor Mode and set its Stack Pointer
                MSR     CPSR_c, #Mode_SVC:OR:F_Bit
                MOV     SP, R0
                SUB     R0, R0, #SVC_Stack_Size
				B 		START
;----------------------------DO NOT CHANGE ABOVE THIS COMMENT--------------------------------
;--------------------------------------------------------------------------------------------
;--------------------------------------------------------------------------------------------
				; constant data used in counting loop
Addr_FIOPIN		DCD		0x3FFFC014
Addr_FIOMASK	DCD		0x3FFFC010
Addr_SCS		DCD		0xE01FC1A0

LTORG
START		    ; initialse	 counting loop
				LDR R0, Addr_SCS		; These three lines set the MCU to use the FIOPIN interface, rather than IOPIN
				MOV R1, #1				; bit0 = 1 enables FIOPIN usage (all other bits must be 0)
				STR R1, [R0]
				
				LDR R0, Addr_FIOMASK	; These three lines set the FIOMASK so that they only read the pins we need to
				LDR R1, =0xFEFEFEFE		; All others are ignored. This saves the commented out AND command in the main Loop.
				STR R1, [R0]
				
				MOV R0, #0				; R0 used as 'scratch' register
				MOV R1, #0				; Set the 'history' on the pins to be 0
				MOV R4, #0				; Set the total count to 0
				MOV R5, #0				; Total transitions in p0
				MOV R6, #0				; Total transitions in p1
				MOV R7, #0				; Total transitions in p2
				MOV R8, #0				; Total transitions in p3
				MOV R9, #0xFF			; Used to set mask for AND when calculating
				MOV R10, #10			; Counts down from 255 to 0 to detect when to loop
				LDR R11, =0x01010101	; Mask to AND with before processing IOPIN values
				LDR R12, Addr_FIOPIN		; Mem location of IOPIN
				;todo add 1 in each byte so the mask is set correctly.
				B M_LOOP
				LTORG

M_LOOP
				GBLA count
count			SETA 0

				WHILE count <=255

;				IF count = {50}
;					NOP
;				ENDIF
count			SETA count+1
				LDR R2, [R12]			; Move IO status to R2
			;	AND R2, R11, R2
				BIC R3, R2, R1			; XOR previous state of pins with current state. Will detect transition
				MOV R1, R2				; R1 arstores the previous state of the pins
				ADD R4, R4, R3
				
				WEND
				
				; This shifts values in to individual 32 bit registers
				
				AND R0, R4, #0xFF		; Remove other registers for to find number of p0 transitions
				ADD R5, R5, R0
				
				AND R0, R9, R4, lsr #8
				ADD R6, R6, R0
				
				AND R0, R9, R4, lsr #16
				ADD R7, R7, R0
				
				AND R0, R9, R4, lsr #24
				ADD R8, R8, R0
				
				MOV R4, #0
				
				CMP R10, #1
				
				BPL M_LOOP
				B FINISH


FINISH
				LDR R12, =P0COUNT
				STR R5, [R12]
				
				LDR R12, =P1COUNT
				STR R6, [R12]
				
				LDR R12, =P2COUNT
				STR R7, [R12]
				
				LDR R12, =P3COUNT
				STR R8, [R12]
				
				B LOOP_END

ISR_FUNC		
				MOV R10, #-1			; Interrupt must set variable to terminate main loop
				;B FINAL_SHIFT			; for skeleton code only		
				SUBS pc,lr,#4			; replace this by return from interrupt
				B FINISH				; branch to LOOP_END will be at end of LOOP code

;--------------------------------------------------------------------------------------------
; PARAMETERS TO CONTROL SIMULATION, VALUES MAY BE CHANGED TO IMPLEMENT DIFFERENT TESTS
;--------------------------------------------------------------------------------------------
SIMCONTROL
SIM_TIME 		DCD  	100000	  ; length of simulation in cycles (100MHz clock)
P0_PERIOD		DCD   	13        ; bit 0 input period in cycles
P1_PERIOD		DCD   	12		  ; bit 8 input period in cycles
P2_PERIOD		DCD  	15		  ; bit 16 input period	in cycles
P3_PERIOD		DCD		18		  ; bit 24 input period	in cycles
;---------------------DO NOT CHANGE AFTER THIS COMMENT---------------------------------------
;--------------------------------------------------------------------------------------------
;--------------------------------------------------------------------------------------------
LOOP_END		MOV R0, #0x7f00
				LDR R0, [R0] 	; read memory location 7f00 to stop simulation
STOP			B 	STOP
;-----------------------------------------------------------------------------
 				AREA	DATA, READWRITE

P0COUNT			DCD		0
P1COUNT			DCD		0
P2COUNT			DCD		0
P3COUNT			DCD		0
;------------------------------------------------------------------------------			
                AREA    STACK, NOINIT, READWRITE, ALIGN=3

Stack_Mem       SPACE   USR_Stack_Size
__initial_sp    SPACE   ISR_Stack_Size

Stack_Top


        		END                     ; Mark end of file

