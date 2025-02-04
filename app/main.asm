;-------------------------------------------------------------------------------
; Include files
            .cdecls C,LIST,"msp430.h"  ; Include device header file
;-------------------------------------------------------------------------------

            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.

            .global __STACK_END
            .sect   .stack                  ; Make stack linker segment ?known?

            .text                           ; Assemble to Flash memory
            .retain                         ; Ensure current section gets linked
            .retainrefs

RESET       mov.w   #__STACK_END,SP         ; Initialize stack pointer


init:
            ; stop watchdog timer
            mov.w   #WDTPW+WDTHOLD,&WDTCTL

setup_Registers
                 mov.w #0000h, R13              ; setting up R13 to be used for loops 
                 mov.w #0000h, R14              ; setting up R14 to be used to transmit Bytes
                 mov.w #0000h, R15              ; setting up R15 to be used for delay      

setup_port2_for_i2c
                
                mov.b   #000, &P2SEL0
                mov.b   #000, &P2SEL1
                bis.b   #BIT0, &P2DIR           ; Setup P2.0 as SCL Line
                bic.b   #BIT0, &P2OUT           ; clear P2.0 output
                
                mov.b   #000, &P2SEL0
                mov.b   #000, &P2SEL1
                bis.b   #BIT2, &P2DIR           ; Setup P2.2 as SDA Line
                bic.b   #BIT2, &P2OUT           ; clear P2.2 output

setup_P6        bic.b   #BIT6, &P6OUT           ; clear P6.6
                bis.b   #BIT6, &P6DIR           ; P6.6 as output

setup_timer_B0
                bis.w	#TBCLR, &TB0CTL				; clear timer and dividers
	        bis.w	#TBSSEL__ACLK, &TB0CTL		; select ACLK as timer source
	        bis.w	#MC__CONTINUOUS, &TB0CTL	; choose continuous counting
	        bis.w	#CNTL__12, &TB0CTL			; timer to toggle LED ~ 1sec
	        bis.w	#ID__8, &TB0CTL				; ^^
	        bis.w	#TBIE, &TB0CTL				; enable overflow interupt
	        bic.w	#TBIFG, &TB0CTL				; clear interupt flag



            ;bic.w   #LOCKLPM5,&PM5CTL0       ; Unlock I/O pins
            bis.w	#GIE, SR				; turn on global eables

            ; Disable low-power mode
            bic.w   #LOCKLPM5,&PM5CTL0

main:
            jmp i2c_init
            nop 
            jmp main
            nop


;------------------------------------------------------------------------------
; I2C Subroutines 
;------------------------------------------------------------------------------


i2c_init: 
        mov.b   #00000101b, &P2OUT     ; send both SDA & SCL high (1)
        mov.w   &P2OUT, R14
        mov.w   #03d, R15
        call    #delay
        nop


i2c_start:              ; send SDA low (0), hold for 25 us then send SCL low (0)
        bic.b   #BIT2, &P2OUT           ; put SDA low (P2.2 -> 0) 
        call    #delay                  ; delay for 25 us
        bis.b   #BIT0, &P2OUT           ; put SCL high (P2.0 -> 1)
        call    #delay
        jmp     i2c_tx_byte

i2c_stop:               ; send SCL high (1), hold for 25 us, then send SDA high (0)
        mov.b   #000000001b, &P2OUT    ; put SCL high (1)
        call    #delay                  ; delay for 25 us 
        mov.b   #000000101b, &P2OUT    ; put SDA high (1)
        call    #delay
        jmp main

i2c_tx_ack:
        bic.b   #BIT0, &P2OUT           ; put SCL (P2.0) low (0)
        call    #delay
        bic.b   #BIT2, &P2OUT           ; put SDA (P2.2) low (0)
        call    #delay
        bis.b   #BIT0, &P2OUT           ; put SCL (P2.0) high (1)
        call    #delay
        jmp     i2c_stop

i2c_rx_ack:
        bic.b   #BIT0, &P2OUT           ; put SCL (P2.0) low (0)
        call    #delay
        bic.b   #BIT2, &P2OUT           ; put SDA (P2.2) low (0)
        call    #delay
        bis.b   #BIT0, &P2OUT           ; put SCL (P2.0) high (1)
        call    #delay

i2c_tx_byte:
        mov.w   #08d, R13               ; run loop 8 times (size of a byte)
        mov.b   &02000h, R14            ; put the slave address value into R14
For_tx:
        bic.b   #BIT0, &P2OUT           ; put SCL (P2.0) low (0)
        call    #delay   
        
        bit.w	#BIT7, R14      	; checking if bit 7 in R14 is set (1)
        jz      Set_High_tx             ; Z will be set to 0 if bit 7 IS a 1
        jnz     Set_Low_tx              ; z will be set to 1 if bit 7 IS NOT a 1

Set_High_tx:
                bis.b   #BIT2, &P2OUT   ; setting SDA (P2.2) to be HIGH
                jmp     End_Set_tx
Set_Low_tx:
                bic.b   #BIT2, &P2OUT   ; setting SDA (P2.2) to be LOW
                jmp     End_Set_tx

End_Set_tx:
        rla.w   R14                     ; because rotating word, R14 has 16 bits of storage, so no need for rlc
        call    #delay
        bis.b   #BIT0, &P2OUT           ; put SCL (P2.0) high (1)  
        call    #delay
        dec     R13
        tst     R13                     ; check to see if Loop is over yet
        jnz     For_tx

        call    #i2c_tx_ack             ; create ACK signal at the end of transmitting
        ret


i2c_rx_byte:


i2c_send_address:


i2c_sda_delay:                          ; delay for the data line


i2c_scl_delay:                          ; delay func for clock line
        xor.b   #BIT0, &P2OUT
        call    #delay
        nop
        ret


i2c_write:


i2c_read:

delay:                ; general delay loop for timing (25 us) 
        dec.w     R15
        jnz     delay
        mov.b    #03d, R15      
        ret


;------------------------------------------------------------------------------
; Data / Values 
;------------------------------------------------------------------------------

            .data           ; save values in data segment memory 
            .retain         ; keep the values 

slave_address_tx:  .short 0000000001101110b   ; makeshift slave address for logic analyzer (WRITE) (55h)
slave_address_rx:  .short 0000000001101111b   ; makeshift slave address for logic analyzer (READ) (55h)         





;------------------------------------------------------------------------------
; Interrupt Service Routine 
;------------------------------------------------------------------------------

timer_B0_1s:        ; subroutine to toggle the green LED every 1 sec
            xor.b   #BIT6, &P6OUT           ; toggle LED2 (green)
            bic.w   #TBIFG, &TB0CTL         ; clear TB0 flag
            reti

;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect   RESET_VECTOR            ; MSP430 RESET Vector
            .short  RESET                   ;

            .sect 	".int42"                ; Timer B0 interrupt vector
            .short 	timer_B0_1s             ; set interrupt vector to point to timer_B0_1s