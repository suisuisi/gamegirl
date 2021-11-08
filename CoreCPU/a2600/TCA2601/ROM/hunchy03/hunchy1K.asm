; -----------------------------------------------------------------------------
; Hunchy v0.3 (1K Version) - Atari 2600 VCS 
; Copyright (C) Chris Walton 2005 <cwalton@gmail.com>
;
; This code was created with the help of the great people on the AtariAge
; "2600 Programming For Newbies" forum: http://www.atariage.com/forums/
; -----------------------------------------------------------------------------

; TODO:
; 1) Improve appearance of sprites (and colours)
; 2) Fix minor glitches (knight and arrows)
	
; Suggestions for 2K "Deluxe" Version
; - Title Screen, End Screen, Music, High Score (time-based), and limited lives
; - Reverse Arrows & Cannonballs
; - Moving Platform Levels
; - Difficulty switch (slow/fast) & PAL/NTSC Switch
	
	PROCESSOR 6502
	INCLUDE vcs.h
	INCLUDE macro.h

	; BIT Absolute Macro
	MAC BITABS
	.byte $2C
	ENDM
			
; Game Constants
NO_ILLEGAL_OPCODES = 1			; No Cheating! 
PALCOLS		= 0			; PAL/NTSC Colours (0=NTSC)
PALTIME		= 0			; 50Hz/60Hz Timing (0=60Hz)
				
; Player Constants
STARTY		= 49			; Player Y Position (default)
XMIN		= 12			; Minimum X Position
XMAX		= 148			; Maximum X Position
HEIGHT		= 16			; Player Sprite Height
JUMPHEIGHT	= 9			; Player Jump Height

; Rope Constants	
ROPEXPOS	= 82			; X Position at Top
ROPELENGTH	= 48			; Rope Length
ROPEMAX		= 8			; Maximum Offset Factor

; Knight Variables
KNIGHTXPOS	= 47			; Default X Position 
KNIGHTYPOS	= 33			; Initial Y Position
KNIGHTHEIGHT	= 16			; Knight Sprite Height 
		
; Cannonball Variables
BALLYPOS	= 38			; Default Y Position
BALLHEIGHT	= 3			; Cannonball Sprite Height 

; Arrow Variables
ARROWYPOS	= 51			; Default Y Position 

	IF PALCOLS
; PAL Colours
WHITE		= $0E
YELLOW		= $28
ORANGE		= $44	
PINK		= $4C
PURPLE		= $AC
LIGHTBLUE	= $DE
MIDBLUE		= $DA
DARKBLUE	= $D6
DARKGREEN	= $54
	ELSE	
; NTSC Colours	
WHITE		= $0C
YELLOW		= $1C
ORANGE		= $24	
PINK		= $3C
PURPLE		= $6A
LIGHTBLUE	= $7E
MIDBLUE		= $7A
DARKBLUE	= $94
DARKGREEN	= $B4
	ENDIF
	
        SEG.U VARS
        ORG $80

; Game Variables
LEVEL	ds 1			; Game Level	
CYCLE	ds 1			; Game Cycle 
STACK	ds 1			; Stack Pointer Storage		
PFLINE	ds 1			; PF Line
PFMASK	ds 1			; PF Change Mask
FIELD2	ds 6			; PF2 Table
HOLES	ds 1			; Collision Detection
DUR0	ds 1			; Sound Duration (Channel 0)
		
; Player Variables
PLAYERX ds 1                    ; X Coordinate
PLAYERY ds 1                    ; Y Coordinate	
JSTEP	ds 1			; Jump Step
ONROPE	ds 1			; On Rope (0 = No)
OFFROPE	ds 1			; Jump Off Rope (0 = No)
FALL	ds 1			; Falling (0 = No)
PSWITCH	ds 1			; Player SwitchDraw Start Variable 
PEND	ds 1			; Player SwitchDraw End Variable
PEND2	ds 1			; Player SwitchDraw End Variable
PLAYPTR	ds 2			; Player Sprite Pointer
PLAYCOL	ds 2			; Player Colour Table Pointer
			
; Knight Variables
KSHOW	ds 1			; Show Knights (0=No)
KNIGHTY	ds 1			; Knight Y Position
KJUMPY	ds 1			; Jump Y Position
KSWITCH	ds 1			; Knight SwitchDraw Start Variable
KEND	ds 1			; Knight SwitchDraw End Variable
KEND2	ds 1			; Knight SwitchDraw End Variable
KPTR	ds 2			; Knight Sprite Pointer
KCOL	ds 2			; Knight Colour Table Pointer
		
; Rope Variables
RSHOW	ds 1			; Show Rope (0=No)
RDIR	ds 1			; Rope Direction
RSHIFT	ds 1			; Rope Multiplier
RPOS	ds 1			; Rope Position (Actual)
OLDRPOS	ds 1			; Old Rope Position (Scaled)
NEWRPOS	ds 1			; New Rope Position (Scaled)
RDISP	ds 1			; Rope Displacement (Pixels)
ROPE	ds #ROPELENGTH+1	; Rope Offset Table (HMOVE Offsets)

; Object Variables
ObjectPosition
BALLX	ds 1			; CannonBall Position
ARROWX	ds 1			; Arrow Position
ObjectSpeed
BSPEED	ds 1			; Ball Speed (Pixels)
ASPEED	ds 1			; Arrow Speed (Pixels)
		
EndVars
	; Display Remaining RAM
        echo "----",($100 - *) , "bytes left (RAM)"   

; Begin code segment (2K)
        SEG CODE
        ORG $F800
Start
	; Wipe Registers 
	CLEAN_START
		
	; Set Starting Positions
	jsr ResetGame
	
MainLoop
	; Do Vertical Sync (Routine by Manuel Polik)
	lda #$02           ; VSYNC enable
	sta WSYNC 
	sta VSYNC 
	sta WSYNC  
	sta WSYNC 
	lsr                ; VSYNC disable
	sta WSYNC  
	sta VSYNC
	
	; Set Vertical Blank Timer
	IF PALTIME
	ldy #53			;  (45*76)/64 = 53
	ELSE
	ldy #43			;  (37*76)/64 = 43
	ENDIF
	sty TIM64T

	; Calculate Sprite Positions & Game Data (Vertical Blank)
	jsr GameLogic

	; Draw the Screen (Kernel)
	jsr DrawScreen

	; Check Collisions (Overscan)
	jsr CollisionDetect

        ; Finish Overscan
WaitOverscanEnd
        lda INTIM
        bne WaitOverscanEnd        
        beq MainLoop
	
GameLogic				
	; Decrement Cycle Counter
	dec CYCLE
	
	; Update Movements Every Second Cycle (too fast otherwise) 
	bit CYCLE		; A contains #1 on entry
	beq DoCycle
	jmp EndCycle
DoCycle
	; Set X to Zero (used in several places)
	ldx #0
	
	; Move Knights
	lda #%00100000
	bit CYCLE
	bne EndKJump	
	lsr
	bit CYCLE
	bne KMoveDown
KMoveUp
	dec KJUMPY
	BITABS		; Skip Next Instruction
KMoveDown
	inc KJUMPY
EndKJump

	; Check if we are already jumping
	lda JSTEP
	beq CheckJump
	; Increment jump step
	inc JSTEP
	; Check if we have reached the half way point
	cmp #JUMPHEIGHT
	bcc MoveDown
MoveUp
	dec PLAYERY	
	; Check if we have reached default position yet
	lda #STARTY
	cmp PLAYERY
	bmi EndJump
	; Finish Jump
	stx JSTEP
	stx OFFROPE
	beq EndJump
MoveDown
	inc PLAYERY
	bne EndJump
CheckJump
	; Read Joystick Fire Button
        lda INPT4
        bmi EndJump
	inc JSTEP
	; Check if we are on the rope
 	ldy ONROPE
 	beq EndJump
	; Move off rope
	inc OFFROPE
	dec ONROPE 
EndJump
	; Move Player Left and Right
	bit SWCHA
	bpl MoveRight
	bvc MoveLeft
	jmp EndJoy
MoveLeft
	; Cannot move past left edge
	lda PLAYERX
	cmp #XMIN
	bcc EndJoy
	; Decrement position
	dec PLAYERX
	; Reflect player sprite
	lda #8
	sta REFP0
	; Play Sound
	bne MoveSound
MoveRight
	; Check if we have reached the right edge
	lda PLAYERX
	cmp #XMAX
	bcs EndJoy
	; Increment position
	inc PLAYERX
	; Player sprite is not reflected
	stx REFP0
	; Play Sound
	bne MoveSound
EndJoy
 	; Play Sound when Jumping
	lda JSTEP
	bne MoveSound
	; Play Sound When Falling
  	lda FALL
  	beq EndSound
MoveSound
 	; Calculate Sound Based on Player Y Position
  	lda #128
  	sbc PLAYERY
  	lsr
  	sta AUDF0
  	lda #6
  	sta AUDV0
	asl
 	sta AUDC0	
 	lda #1
  	sta DUR0
EndSound
	
	; Move Cannonball & Arrow
	jsr MoveObject
	inx
	jsr MoveObject					
EndCycle
	
	; Move swinging rope
MoveRope
	lda #%00000011
 	bit CYCLE
 	bne EndRope
	; Move left if Bit 0 is clear (right otherwise)
	lsr
	bit RDIR
	bne RopeLeft
RopeRight
	inc RSHIFT
	lda #ROPEMAX
	cmp RSHIFT
	bne CalcRope
	inc RDIR
	bne CalcRope
RopeLeft
	dec RSHIFT
	bne CalcRope
	inc RDIR
CalcRope
 	ldy #ROPELENGTH
RopeLoop
	; Add Movement to Current Rope Position
	clc
        lda RPOS
        adc RSHIFT
        sta RPOS
	; Mask 3 LSB (SubPixel Movement)
        and #%11111000
        sta NEWRPOS
	ldx #0
	; No Movement
	cmp OLDRPOS
        beq EndHMove
	; Move Left
        ldx #%11110000
	; Check Direction
        lda #%00000010
        bit RDIR
        beq EndHMove
	; Move Right
        ldx #%00010000
EndHMove
	; Store Rope Positions
	stx ROPE,Y
        lda NEWRPOS
        sta OLDRPOS
	dey			; Skip Every Second Rope Position
	dey
	bne RopeLoop
	; Convert Rope Movement into Player Displacement
	lda RPOS
	lsr
	lsr
	lsr
	sta RDISP
EndRope

	; Check if player is on the rope
OnRope
	lda ONROPE
	beq EndOnRope
	; Check Rope Direction
        lda #%00000010
        bit RDIR
	beq IncDisp
DecDisp
	sec
	lda #ROPEXPOS-4
	sbc RDISP
	bne EndDisp	
IncDisp
	clc
	lda #ROPEXPOS-4
	adc RDISP
EndDisp
	sta PLAYERX	
EndOnRope
							
	; Get Level Data 
 	lda LEVEL
	and #%00001111		; Wrap after level 15
	tax
 	lda Levels,X
	tay
	; Set Cannonball Speed
	and #%00000111
	sta BSPEED
	; Set Arrow Speed
	tya
	and #%00111000
	lsr
	lsr
	lsr
	sta ASPEED
	; Set Screen Configuration
	ldx Field2		; Default Configuration
	tya
 	and #%11000000
	beq EndScreen
	bmi Screen2
; Screen 1 (Knights)
Screen1
	; Set Knight Position
 	lda KJUMPY
 	sta KNIGHTY
	; Get PF2
	ldx Field2+1
	; Show Knights
	lda #%00000110	
	sta KSHOW
	bne EndScreen
; Screen 2 (Rope Swing)
Screen2
	; Get PF2
	ldx Field2+2
	; Show Rope
	lda #%00000010
	sta RSHOW
EndScreen
	; Store PF2
	stx FIELD2+1
EndLevel
	
	; Player Sprite Horizontal Position
 	lda PLAYERX
	ldx #0
 	jsr XPosition
 	; Knight Sprite Horizontal Position 
 	lda #KNIGHTXPOS
 	inx
 	jsr XPosition
	; Cannonball Sprite Horizontal Position
	lda BALLX
	inx
	jsr XPosition
	; Arrow Sprite Horizontal Position
	lda ARROWX
	inx
	jsr XPosition
	; Rope Sprite Horizontal Position 
  	lda #ROPEXPOS
  	inx
  	jsr XPosition		
	; Commit Positions
 	sta WSYNC
 	sta HMOVE
	
	;  Player SwitchDraw Variables
	sec
	lda PLAYERY
	sta PSWITCH
	sbc #HEIGHT
	sta PEND2
	ora #%10000000
	sta PEND
	; Player Body Sprite Pointer (Animated)
	lda PLAYERX
 	and #%00001100		; Frame Calculated from X Position
	asl
	asl
	adc #<Player1
	sec
	sbc PEND2
	sta PLAYPTR
	lda #>Player1
	sta PLAYPTR+1
	; Player Colour Pointer
	sec
	lda #<PlayerCol
	sbc PEND2
	sta PLAYCOL
	lda #>PlayerCol
	sta PLAYCOL+1

	; Knight SwitchDraw Variables
	sec
	lda KNIGHTY
	sta KSWITCH
	sbc #KNIGHTHEIGHT
	sta KEND2
	ora #%10000000
	sta KEND	
	; Knight Sprite Pointer
	sec
	lda #<Knight
	sbc KEND2
	sta KPTR
	lda #>Knight
	sta KPTR+1
	; Knight Colour Pointer
	sec
	lda #<KnightCol
	sbc KEND2
	sta KCOL
	lda #>KnightCol
	sta KCOL+1	
		
	; Reset Collision Vector
	sta CXCLR
	
	; Set Arrow Size (x8)
	lda #%00110000
	sta NUSIZ1	
	
	; Set Cannonball Size (x4) 
	lda #%00100000
	sta NUSIZ0
	
	; Set Reflected Playfield and 2-Pixel Ball
	lda #%00010001	  
	sta CTRLPF
	
	; Enable Rope
 	lda RSHOW
	sta ENABL
	lda #ROPELENGTH
	sta RPOS
	
	; Silence Sounds
 	lda DUR0
 	bne Dec0
 	sta AUDV0
 	BITABS			; Skip Next Instruction
Dec0
 	dec DUR0
		
	; Reset HMOVE registers to prevent further movement
	sta HMCLR	
	rts

	; Player SwitchDraw (Routine by Thomas Jentzsch)
PSwitch
	bne PWait		; [6] + 2/3
	lda PEND		; [8] + 3
	sta PSWITCH		; [11] + 3
	lda #0			; [14] + 2
	beq PContinue		; [16] + 3
PWait
	SLEEP 5			; [9] + 5
	lda #0			; [14] + 2
	beq PContinue		; [16] + 3

	; Knight SwitchDraw (Routine by Thomas Jentzsch)
KSwitch
	bne KWait		; [28] + 2/3
	lda KEND		; [30] + 3	
	sta KSWITCH		; [33] + 3
	lda #0			; [36] + 2
	beq KContinue		; [38] + 3
KWait
	SLEEP 5			; [31] + 5
	lda #0			; [36] + 2
	beq KContinue		; [38] + 3
			
DrawScreen
	; Wait for end of Vertical Blank
WaitVblank
	lda INTIM
	bne WaitVblank
	sta VBLANK
	
	; Store Stack Pointer
	tsx
	stx STACK
	
	; Move Stack Pointer to ENAM1 if Displaying Arrow
	lda ARROWX
	beq NoArrow
	ldx #ENAM1
	txs
NoArrow

	; Set Castle Colour
 	lda #ORANGE
  	sta COLUPF
	
	; Set Arrow Colour
	lda #WHITE
	sta COLUP1
		
	; Initialise Playfield	(PF2 Empty)
 	ldy #5
 	sty PFLINE
 	lda Field0,Y
 	sta PF0
 	lda Field1,Y
 	sta PF1
	
	; Set Line Counter (192-16)/2
        ldy #88
Kernel
	sta WSYNC		; [0]

	; Draw Player
 	cpy PSWITCH		; [0] + 3 
  	bpl PSwitch		; [3] + 2/3
	lda (PLAYCOL),Y		; [5] + 5
	sta.w COLUP0		; [10] + 4
	lda (PLAYPTR),Y		; [14] + 5 
PContinue
	sta GRP0		; [19] + 3

	; Draw Knight	
  	cpy KSWITCH		; [22] + 3
  	bpl KSwitch		; [25] + 2/3
 	lda (KCOL),Y		; [27] + 5
 	sta.w COLUP1		; [32] + 4
 	lda (KPTR),Y		; [36] + 5	
KContinue
	sta GRP1		; [41] + 3	
		
  	; Update Playfield Counter
	tya			; [44] + 2
	bit PFMASK		; [46] + 3
	beq PFChange		; [49] + 2/3
	nop			; [51] + 2
	BITABS			; [53] + 4	; Skip Next Instruction
PFChange	
	dec PFLINE		; [52] + 5

	; Draw Cannonball
 	sec			; [57] + 2
 	sbc #BALLYPOS		; [59] + 2
 	adc #BALLHEIGHT		; [61] + 2
 	rol			; [63] + 2
 	rol			; [65] + 2
 	ldx BALLX		; [67] + 3
 	bne ShowBall		; [70] + 2/3
	BITABS			; [72] + 4 	; Skip Next Instruction	
ShowBall
 	sta ENAM0		; [73] + 3

	; Commit Movements
	sta HMOVE		; [0] + 3
	
	; Display PF0 & PF1
	ldx PFLINE		; [3] + 3
	lda Field0,X		; [6] + 4
	sta PF0			; [10] + 3 < 22
	lda Field1,X		; [13] + 4
	sta PF1			; [17] + 3 < 28	
		
	; Draw Arrow
   	cpy #ARROWYPOS		; [20] + 2
	php			; [22] + 3

	; Display PF2
	lda FIELD2,X		; [25] + 4
	sta PF2			; [29] + 3 < 38	
	
	; Draw Rope
 	ldx RPOS		; [32] + 3
 	bne RopeDec		; [35] + 2/3
	stx ENABL		; [37] + 3	
	beq EndRopeShift	; [40] + 3
RopeDec	
	dec RPOS		; [38] + 5
EndRopeShift
	lda ROPE,X		; [43] + 4
 	sta HMBL		; [47] + 3
	
	; Update Knights Shift
   	cpy #ARROWYPOS		; [50] + 2	
 	bpl NoShift		; [52] + 2/3
	lda KSHOW		; [54] + 3
	sta NUSIZ1		; [57] + 3
NoShift

	; Reset Stack Pointer & Loop
	pla			; [60] + 4
	dey			; [64] + 2
	bne Kernel		; [66] + 3
EndKernel
		
 	; Clear Player Graphics
 	sty GRP0
	
 	; Draw Water
 	lda #DARKBLUE
 	sta COLUPF
	IF PALTIME
	ldy #52			; 228-(88*2) = 52
	ELSE
 	ldy #16			; 192-(88*2) = 16
	ENDIF
WaterLoop
 	sta WSYNC
 	dey
 	bne WaterLoop
	
 	; Clear PF Registers		
 	sty PF0
 	sty PF1
 	sty PF2
	
	; Start Vertical Blank
	lda #2
	sta WSYNC
	sta VBLANK	     

	; Set Timer for Overscan
	IF PALTIME
	ldy #42			; (36*76)/64 = 42
	ELSE
	ldy #35			; (30*76)/64 = 35
	ENDIF
	sty TIM64T

	; Restore Stack Pointer
	ldx STACK
	txs
	rts
	
        if (>Kernel != >EndKernel)
          echo "WARNING: Kernel crosses a page boundary!"
        endif		
		
CollisionDetect 
	; Check if we are falling
	lda FALL
	beq NotFalling
	; Check if we have reached the bottom of the screen
	dec PLAYERY
	beq Reset
	rts
NotFalling
		
	; Check if we have reached RHS of Screen
	lda PLAYERX
	cmp #XMAX
	bcc NoLevelChange
	; Increment level counter
	inc LEVEL
Reset
	; Reset Variables
	jsr ResetGame
	rts
NoLevelChange
	
	; Arrow Collision
	bit CXM0P
	bvs Die
	; Cannonball Collision
	bit CXM1P
	bmi Die			
	; Knight Collisions	
	bit CXPPMM
	bmi Die
	; Rope Collision
	bit CXP0FB
	bvs Rope

	; Skip Hole Collisions if we are jumping (or on rope)
	lda JSTEP
	bne EndHoles
	; Clear Hole Count
	sta HOLES		
	; Calculate Hole Mask
	lda #%00111111
	ldy KSHOW
	bne EndMask
	lda #%00100001
	ldy RSHOW
	bne EndMask
	lda #%00110011
EndMask
	; Check Hole Positions
	ldx #6
HoleLoop
	; Skip Positions if mask not set
	lsr
	bcc NextPosition
	ldy FieldHoles-1,X
	; Increment holes count 
	cpy PLAYERX
	bcc NextPosition
	inc HOLES
NextPosition
	dex
	bne HoleLoop
	; Die if result is not an even number
	lda #%00000001
	bit HOLES
	bne Die
EndHoles
	rts
Die
	; Start player falling
	inc FALL
	rts
Rope
	; Ignore rope collisions if we have just got off the rope
	ldy OFFROPE
	bne EndRopeColl
	; Otherwise, set rope conditions and clear any jump in progress
	sty JSTEP
	iny
	sty ONROPE
EndRopeColl
	rts
		
ResetGame
	; Reset All Game Variables (except LEVEL)
	lda #0
	ldy #<EndVars
ClearLoop
	sta $00,Y
	dey
	cpy #<LEVEL
	bne ClearLoop
	; Reset Sprites
	sta ENABL
	sta ENAM0
	sta ENAM1
	; Set Default Values
	lda #XMIN
	sta PLAYERX		; Player Start Position
	lda #STARTY
	sta PLAYERY		
	lda #KNIGHTYPOS
	sta KJUMPY		; Knight Position
	lda #%00001111
	sta PFMASK		; PF Change Mask
	lda #%11111111
	sta FIELD2		; Playfield Base
	rts

	; Sprite Horizontal Positioning Routine (Battlezone Variant)
XPosition
	sec
        sta WSYNC
	; Divide Position by 15
Divide15
        sbc #15
        bcs Divide15
	; Invert LSB
        eor #7
	; Shift to make HMPx value 
        asl
        asl
        asl
        asl
	; Store Positions (Strobe)
        sta HMP0,X 
        sta RESP0,X
	rts	
		
	; Move Game Object (X = Object - 0=Cannonball, 1=Arrow)
MoveObject
	sec
	lda ObjectPosition,X
	sbc ObjectSpeed,X
	; Check LHS 
	cmp #XMAX+8
	bcc StoreObject	
	; Check Arrow Enabled
	lda ObjectSpeed,X
	beq EndObjectMove
	; Play Shoot Sound
 	lda #8
 	sta AUDV0
 	sta AUDC0
	sta AUDF0
 	sta DUR0
	; Set/Reset Start Position
	lda #XMAX+8
StoreObject
	sta ObjectPosition,X
EndObjectMove
	rts
        if (>MoveObject != >EndObjectMove)
          echo "WARNING: MoveObject crosses a page boundary!"
        endif
		
Field2
	DC.B	%11111110	
	DC.B	%01111110
	DC.B	%00000000
Field1
	DC.B	%11111111
	DC.B	%11111110
	DC.B	%00000000
	DC.B	%00000000
	DC.B	%11110000
	DC.B	%00110000	
Field0
	DC.B	%11000000
	DC.B	%11000000
	DC.B	%00000000
	DC.B	%00000000
	DC.B	%11000000
	DC.B	%11000000
FieldHoles
	DC.B	114,107,82,75,50,43
FieldEnd
        if (>Field2 != >FieldEnd)
          echo "WARNING: Field table crosses a page boundary!"
        endif			

	; Levels
	; Bits 0-2 Cannonball Speed (0 = None)
	; Bits 3-5 Arrow Speed (0 = None)
	; Bits 6-7 Level Type (0=Straight, 1=Knights, 2=Swing, 3=Final)
Levels
	DC.B	%00000000
	DC.B	%01000000
	DC.B	%00010000
	DC.B	%10000000
	DC.B	%00000010
	DC.B	%01010000
	DC.B	%00000011
	DC.B	%10000001
	DC.B	%00010001	
	DC.B	%01000010
	DC.B	%00011010
	DC.B	%01010001
	DC.B	%10001000
	DC.B	%01100001
	DC.B	%00010100	
	DC.B	%10001010
LevelsEnd
;       if (>Levels != >LevelsEnd)
;         echo "WARNING: Levels table crosses a page boundary!"
;       endif	
	
; Player Frame 1
PlayerCol
	DC.B	#YELLOW,#YELLOW,#YELLOW,#YELLOW
	DC.B	#YELLOW,#YELLOW,#YELLOW,#YELLOW	
	DC.B	#YELLOW,#PINK,#PINK,#PINK
	DC.B	#PINK,#DARKGREEN,#DARKGREEN,#DARKGREEN
Player1
	DC.B	%00011000
	DC.B	%00010000
	DC.B	%00011000
	DC.B	%00111100
	DC.B	%01101110
	DC.B	%01101110
	DC.B	%01101110		
	DC.B	%01101110
	DC.B	%00111100
	DC.B	%00011000
	DC.B	%00010000
	DC.B	%00111100
	DC.B	%00110100
	DC.B	%01111110
	DC.B	%00111100
	DC.B	%00011000
; Player Frame 2
Player2
	DC.B	%00100100
	DC.B	%01001010
	DC.B	%00111000
	DC.B	%00111100
	DC.B	%01110110
	DC.B	%01110110
	DC.B	%01101110	
	DC.B	%01101110
	DC.B	%00111100
	DC.B	%00011000
	DC.B	%00010000
	DC.B	%00111100
	DC.B	%00110100
	DC.B	%01111110
	DC.B	%00111100
	DC.B	%00011000
; Player Frame 3
Player3
	DC.B	%00011000
	DC.B	%00010000
	DC.B	%00011000
	DC.B	%00111100
	DC.B	%01101110
	DC.B	%01101110
	DC.B	%01101110	
	DC.B	%01101110
	DC.B	%00111100
	DC.B	%00011000
	DC.B	%00010000
	DC.B	%00111100
	DC.B	%00110100
	DC.B	%01111110
	DC.B	%00111100
	DC.B	%00011000
; Player Frame 4
Player4
	DC.B	%00100100
	DC.B	%01001010
	DC.B	%00111000
	DC.B	%00111100
	DC.B	%01011110
	DC.B	%01011110
	DC.B	%01101110
	DC.B	%01101110
	DC.B	%00111100
	DC.B	%00011000
	DC.B	%00010000
	DC.B	%00111100
	DC.B	%00110100
	DC.B	%01111110
	DC.B	%00111100
	DC.B	%00011000
PlayerEnd
        if (>PlayerCol != >PlayerEnd)
          echo "WARNING: Player table crosses a page boundary!"
        endif       			
								
; Knight
KnightCol
	DC.B	#MIDBLUE,#MIDBLUE,#MIDBLUE,#MIDBLUE
	DC.B	#MIDBLUE,#MIDBLUE,#MIDBLUE,#MIDBLUE
	DC.B	#MIDBLUE,#LIGHTBLUE,#LIGHTBLUE,#LIGHTBLUE
	DC.B	#LIGHTBLUE,#LIGHTBLUE,#LIGHTBLUE,#LIGHTBLUE
Knight
	DC.B	%01100110
        DC.B	%00100100
        DC.B	%01011110
        DC.B	%10101011
        DC.B	%01010110
        DC.B	%00101100
        DC.B	%00011000
        DC.B	%00100100
        DC.B	%01000010
        DC.B	%10011001
        DC.B	%11111111
        DC.B	%10111101
        DC.B	%10101111
        DC.B	%01010110
        DC.B	%00101100
        DC.B	%00011000
KnightEnd
        if (>KnightCol != >KnightEnd)
          echo "WARNING: Knight table crosses a page boundary!"
        endif	
					
	ORG $FBFC		; 1K Limit!
End
	DC.B	"Hunchy - (C) Chris Walton 2005" 
			
	ORG $FFFC,0
	.word Start
	.word Start
