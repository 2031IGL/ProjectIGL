; This program includes a basic movement API that allows the
; user to specify a desired heading and speed, and the API will
; attempt to control the robot in an appropriate way.
; Also includes several math subroutines.

ORG 0                  ; Jump table is located in mem 0-4
; This code uses the timer interrupt for the control code.
	JUMP   Init        ; Reset vector
	JUMP   IntruderAlert            ; Sonar interrupt 
	JUMP   CTimer_ISR  ; Timer interrupt
	RETI               ; UART interrupt (unused)
	RETI               ; Motor stall interrupt (unused)

;***************************************************************
;* Initialization
;***************************************************************

;;This is a test of the GitHub GUI to make sure my shenanigans don't go unnoticed. :) <3
Init:
	; Always a good idea to make sure the robot
	; stops in the event of a reset.
	LOAD   Zero
	OUT    LVELCMD     ; Stop motors
	OUT    RVELCMD
	STORE  DVel        ; Reset movement API variables
	STORE  DTheta
	OUT    SONAREN     ; Disable sonar (optional)
	OUT    BEEP        ; Stop any beeping (optional)

	CALL   SetupI2C    ; Configure the I2C to read the battery voltage
	CALL   BattCheck   ; Get battery voltage (and end if too low).
	OUT    LCD         ; Display battery voltage (hex, tenths of volts)

	LOADI  &H130
	OUT    BEEP        ; Short hello beep

WaitForSafety:
	; This loop will wait for the user to toggle SW17.  Note that
	; SCOMP does not have direct access to SW17; it only has access
	; to the SAFETY signal contained in XIO.
	IN     XIO         ; XIO contains SAFETY signal
	AND    Mask4       ; SAFETY signal is bit 4
	JPOS   WaitForUser ; If ready, jump to wait for PB3
	IN     TIMER       ; Use the timer value to
	AND    Mask1       ; blink LED17 as a reminder to toggle SW17
	SHIFT  8           ; Shift over to LED17
	OUT    XLEDS       ; LED17 blinks at 2.5Hz (10Hz/4)
	JUMP   WaitForSafety

WaitForUser:
	; This loop will wait for the user to press PB3, to ensure that
	; they have a chance to prepare for any movement in the main code.
	IN     TIMER       ; Used to blink the LEDs above PB3
	AND    Mask1
	SHIFT  5           ; Both LEDG6 and LEDG7
	STORE  Temp        ; (overkill, but looks nice)
	SHIFT  1
	OR     Temp
	OUT    XLEDS
	IN     XIO         ; XIO contains KEYs
	AND    Mask2       ; KEY3 mask (KEY0 is reset and can't be read)
	JPOS   WaitForUser ; not ready (KEYs are active-low, hence JPOS)
	LOAD   Zero
	OUT    XLEDS       ; clear LEDs once ready to continue

;***************************************************************
;* Main code
;***************************************************************
Main:
	CALL Precalc
	CALL Die



;	OUT    RESETPOS    ; reset odometer in case wheels moved after programming

; configure timer interrupts to enable the movement control code
;	LOADI  10          ; fire at 10 Hz (10 ms * 10).
;	OUT    CTIMER      ; turn on timer peripheral
;	SEI    &B0010      ; enable interrupts from source 2 (timer)
	; at this point, timer interrupts will be firing at 10Hz, and
	; code in that ISR will attempt to control the robot.
	; If you want to take manual control of the robot,
	; execute CLI &B0010 to disable the timer interrupt.


; As a quick demo of the movement control, the robot is
; directed to
; - move forward ~1 m at a medium speed,
; - turn left 90 degrees,
; - move forward ~1 m at a slow speed,
; - move back towards (0,0) at a fast speed.

;	LOADI  0
;	STORE  DTheta      ; Desired angle 0
;	LOAD   FMid        ; Defined below as 350.
;	STORE  DVel        ; Desired forward velocity
	; The robot should automatically start moving,
	; trying to match these desired parameters, because
	; the movement API is active.

;Test1:  ; P.S. "Test1" is a terrible, non-descriptive label
;	IN     XPOS        ; X position from odometry
;	OUT    LCD         ; Display X position for debugging
;	SUB    OneMeter    ; Defined below as the robot units for 1 m
;	JNEG   Test1       ; Not there yet, keep checking

	; turn left 90 degrees
;	LOADI  0
;	STORE  DVel
;	LOADI  90
;	STORE  DTheta
;	; Note that we waited until *at* 1 m to do anything, and we
	; didn't let the robot stop moving forward before telling it to turn,
	; so it will likely move well past 1 m.  This code isn't
	; meant to be precise.
;Test2:
;	CALL   GetThetaErr ; get the heading error
;	CALL   Abs         ; absolute value subroutine
;	OUT    LCD         ; Display |angle error| for debugging
;	ADDI   -5          ; check if within 5 degrees of target angle
;	JPOS   Test2       ; if not, keep testing
;	; the robot is now within 5 degrees of 90

;	LOAD   FSlow       ; defined below as 100
;	STORE  DVel
;
;Test3: ; Did I mention that "Test3" is a terrible label?
;	IN     YPOS        ; get the Y position from odometry
;	SUB    OneMeter
;	OUT    LCD         ; Display distance error for debugging
;	JNEG   Test3       ; if not there, keep testing
;	; the robot is now past 1 m in Y.

;	LOAD   FFast       ; defined below as 500
;	STORE  DVel
;
;GoTo00: ; slightly better label than "test"
; This routine uses the provided ATAN2 subroutine to calculate
; the angle needed to reach (0,0).  The origin is a degenerative
; case, but you can use a little more math to use ATAN2 to point to
; any coordinate.
;	IN     XPOS        ; get the X position from odometry
;	CALL   Neg         ; negate
;	STORE  AtanX
;	IN     YPOS        ; get the X position from odometry
;	CALL   Neg         ; negate
;	STORE  AtanY
;	CALL   Atan2       ; Gets the angle from (0,0) to (AtanX,AtanY)
;	STORE  DTheta
;	OUT    SSEG1       ; Display angle for debugging

	; The following bit of code uses another provided subroutine,
	; L2Estimate, the calculate the distance to (0,0).  Once again,
	; the origin is a degenerative case, but adding a bit more math can
	; extend this to any coordinate.
;	IN     XPOS
;	STORE  L2X
;	IN     YPOS
;	STORE  L2Y
;	CALL   L2Estimate
;	OUT    SSEG2       ; Display distance for debugging
;	SUB    OneFoot
;	JPOS   GoTo00      ; If >1 ft from destination, continue
;	; robot is now near the origin

	; done
;	LOADI  0
;	STORE  DVel
;	JUMP   Die
;


Die:
; Sometimes it's useful to permanently stop execution.
; This will also catch the execution if it accidentally
; falls through from above.
	CLI    &B1111      ; disable all interrupts
	LOAD   Zero        ; Stop everything.
	OUT    LVELCMD
	OUT    RVELCMD
	OUT    SONAREN
	LOAD   DEAD        ; An indication that we are dead
	OUT    SSEG2       ; "dEAd" on the sseg
Forever:
	JUMP   Forever     ; Do this forever.
	DEAD:  DW &HDEAD   ; Example of a "local" variable


; Timer ISR.  Currently just calls the movement control code.
; You could, however, do additional tasks here if desired.
CTimer_ISR:
	IN		TIMER
	STORE	InteruptTimer
	CALL   ControlMovement
	IN		TIMER
	SUB		InteruptTimer
	STORE	InteruptTimer
	ADD		InteruptTotal
	STORE	InteruptTotal
	RETI   ; return from ISR


; Control code.  If called repeatedly, this code will attempt
; to control the robot to face the angle specified in DTheta
; and match the speed specified in DVel
DTheta:    DW 0
DVel:      DW 0
ControlMovement:
	LOADI  50          ; used for the CapValue subroutine
	STORE  MaxVal
	CALL   GetThetaErr ; get the heading error
	; A simple way to get a decent velocity value
	; for turning is to multiply the angular error by 4
	; and add ~50.
	SHIFT  2
	STORE  CMAErr      ; hold temporarily
	SHIFT  2           ; multiply by another 4
	CALL   CapValue    ; get a +/- max of 50
	ADD    CMAErr
	STORE  CMAErr      ; now contains a desired differential


	; For this basic control method, simply take the
	; desired forward velocity and add the differential
	; velocity for each wheel when turning is needed.
	LOADI  510
	STORE  MaxVal
	LOAD   DVel
	CALL   CapValue    ; ensure velocity is valid
	STORE  DVel        ; overwrite any invalid input
	ADD    CMAErr
	CALL   CapValue    ; ensure velocity is valid
	STORE  CMAR
	LOAD   CMAErr
	CALL   Neg         ; left wheel gets negative differential
	ADD    DVel
	CALL   CapValue
	STORE  CMAL

	; ensure enough differential is applied
	LOAD   CMAErr
	SHIFT  1           ; double the differential
	STORE  CMAErr
	LOAD   CMAR
	SUB    CMAL        ; calculate the actual differential
	SUB    CMAErr      ; should be 0 if nothing got capped
	JZERO  CMADone
	; re-apply any missing differential
	STORE  CMAErr      ; the missing part
	ADD    CMAL
	CALL   CapValue
	STORE  CMAL
	LOAD   CMAR
	SUB    CMAErr
	CALL   CapValue
	STORE  CMAR

CMADone:
	LOAD   CMAL
	OUT    LVELCMD
	LOAD   CMAR
	OUT    RVELCMD
	
	CALL	CourseCorrection
	CALL	IntruderScan
	
	RETURN
	CMAErr: DW 0       ; holds angle error velocity
	CMAL:    DW 0      ; holds temp left velocity
	CMAR:    DW 0      ; holds temp right velocity
	
CourseCorrection:
	;TO-DO
	;Reads in values from baffle-side sonar and adjusts desired Theta to gently turn toward or away from the baffleCourseCorrection:
	;TO-DO
	;Reads in values from baffle-side sonar and adjusts desired Theta to gently turn toward or away from the baffle
	LOAD	State
	SUB		CCStateSwitch
	JNEG	CCUseSonarZero
	JUMP	CCUseSonarFive
CCUseSonarZero:
	LOADI	3
	STORE	CCConstant
	LOAD	State
	JZERO	CCEnd	;state=0
	ADDI	-1
	JZERO	ZeroBaffleWall ; state=1
	ADDI	-1
	JZERO	ZeroBaffleHead ;state=2
	JUMP	ZeroBaffleWall ;state=3
ZeroBaffleWall:
	IN		DIST0
	STORE	CCCurrentSonar
	LOAD	NPathBaffleWall
	STORE	CCDesiredDistance
	JUMP	CCDetermineDistance
ZeroBaffleHead:
	IN		DIST0
	STORE	CCCurrentSonar
	LOAD	WPathBaffleWall
	STORE	CCDesiredDistance
	JUMP	CCDetermineDistance
CCUseSonarFive:
	LOADI	-3
	STORE	CCConstant
	LOAD	State
	ADDI	-4
	JZERO	CCEnd ;state=4
	ADDI	-1
	JZERO	FiveBaffleWall ;state=5
	ADDI	-1
	JZERO	FiveBaffleHead ;state=6
	JUMP	FiveBaffleWall ;state=7
FiveBaffleWall:
	IN		DIST5
	STORE	CCCurrentSonar
	LOAD	NPathBaffleWall
	STORE	CCDesiredDistance
	JUMP	CCDetermineDistance
FiveBaffleHead:
	IN		DIST5
	STORE	CCCurrentSonar
	LOAD	WPathBaffleWall
	STORE	CCDesiredDistance
	JUMP	CCDetermineDistance
CCDetermineHeading:
	LOAD	CCPreviousSonar
	SUB		CCCurrentSonar
	STORE	CCCourseSwitch
CCDetermineDistance:
	LOAD	CCDesiredDistance
	SUB		CCCurrentSonar
	STORE	CCDistanceSwitch
	JNEG	TooFar
	JZERO	GoodDistance
	JPOS	TooClose
CCEnd:
	LOAD	CCCurrentSonar
	STORE	CCPreviousSonar
	RETURN
	
CCTurnDirection:	DW 0
CCConstant:			DW 3
CCStateSwitch:		DW 4
CCPreviousSonar:	DW &H392
CCCurrentSonar:		DW 0
CCDesiredDistance:	DW 0
CCDistanceSwitch:	DW 0
CCCourseSwitch:		DW 0

TooFar:
	LOAD	CCCourseSwitch
	JNEG	TurnIn
	JPOS	StayStraight
	JZERO	TurnIn
GoodDistance:
	LOAD	CCCourseSwitch
	JNEG	EvenOut
	JPOS	EvenOut
	JZERO	StayStraight
TooClose:
	LOAD	CCCourseSwitch
	JNEG	StayStraight
	JPOS	TurnOut
	JZERO	TurnOut
TurnIn:
	LOAD	DTheta
	ADD		CCConstant
	STORE	DTheta
	LOAD	CCTurnDirection
	ADDI	1
	STORE	CCTurnDirection
	JUMP	CCEnd
StayStraight:
	JUMP	CCEnd
TurnOut:
	LOAD	DTheta
	SUB		CCConstant
	STORE	DTheta
	LOAD	CCTurnDirection
	ADDI	-1
	STORE	CCTurnDirection
	JUMP	CCEnd
EvenOut:
	LOAD	CCTurnDirection
	JZERO	CCEnd
	JPOS	EvenPos
	JNEG	EvenNeg
EvenPos:
	LOAD	CCTurnDirection
	JZERO	CCEND
	SUB		One
	STORE	CCTurnDirection
	LOAD	DTheta
	SUB		CCConstant
	STORE	DTheta
	JUMP	EvenPos
EvenNeg:
	LOAD	CCTurnDirection
	JZERO	CCEND
	ADD		One
	STORE	CCTurnDirection
	LOAD	DTheta
	ADD		CCConstant
	STORE	DTheta
	JUMP	EvenNeg
	
IntruderScan:
	;TO-DO
	;Handles expected measured distance based on state and "intrudercounter"
IntruderSwitch:
	LOAD 	State
	JZERO 	Scanning0
	SUB 	One
	JZERO 	Scanning1
	LOAD 	State
	SUB 	Two
	JZERO 	Scanning2
	LOAD 	State
	SUB 	Three
	JZERO 	Scanning3
	LOAD 	State
	SUB 	Four
	JZERO 	Scanning4
	LOAD 	State
	SUB 	Five
	JZERO 	Scanning5
	LOAD 	State
	SUB 	Six
	JZERO 	Scanning6
	LOAD 	State
	SUB 	Seven
	JZERO 	Scanning7
Scanning0:
	SEI		&B0101
Scanning1:
	CLI		&B0001
	IN		DIST5
	STORE	Temp
	LOAD	NPathNWall
	SUB		200 ;BOOKMARK
Scanning2:
	CLI		&B0001
Scanning3:
	CLI		&B0001
Scanning4:
	SEI		&B0101
Scanning5:
	CLI		&B0001
Scanning6:
	CLI		&B0001
Scanning7:
	CLI		&B0001
	;if we get here, something has broken, so kill everything
	JUMP 	Die
	;enables and reads sonar sensors 2 and 3 every 8th cycle 
	LOAD	FrontScanCycle
	SUB		7
	JZERO	NoScan
	LOAD	State
	JZERO	NoScan
	SUB		4
	JZERO	NoScan
	LOADI	&B00101101
	OUT		SONAREN
	OUT		DIST2
	STORE	Temp
	OUT		DIST3
	ADD		Temp
	SHIFT	-1
	SUB		NoseDistance
	JPOS	NoIntruderInFrontOfOurNose
	CALL	IntruderAlert
NoIntruderInFrontOfOurNose:
	LOADI	&B00100001
	OUT		SONAREN
	RETURN
NoseDistance:
	DW		&H131

NoScan:
	CALL	IncrementFrontCycle
	RETURN
IntruderCounter:	
	DW 0
FrontScanCycle:		
	DW 0

IncrementFrontCycle:
	LOAD	FrontScanCycle
	ADDI	-8
	JZERO	NoWrapFC
	JUMP	WrapUpFC
NoWrapFC:
	LOAD 	FrontScanCycle
	ADDI	1
WrapUpFC:
	STORE	FrontScanCycle
	RETURN
	
; Returns the current angular error wrapped to +/-180
GetThetaErr:
	; convenient way to get angle error in +/-180 range is
	; ((error + 180) % 360 ) - 180
	IN     THETA
	SUB    DTheta      ; actual - desired angle
	CALL   Neg         ; desired - actual angle
	ADDI   180
	CALL   Mod360
	ADDI   -180
	RETURN

; caps a value to +/-MaxVal
CapValue:
	SUB     MaxVal
	JPOS    CapVelHigh
	ADD     MaxVal
	ADD     MaxVal
	JNEG    CapVelLow
	SUB     MaxVal
	RETURN
CapVelHigh:
	LOAD    MaxVal
	RETURN
CapVelLow:
	LOAD    MaxVal
	CALL    Neg
	RETURN
	MaxVal: DW 510


;***************************************************************
;* Subroutines
;***************************************************************

StateSwitch:
	LOAD 	State
	JZERO 	NorthsideSweep
	SUB 	One
	JZERO 	NorthsideE2W
	LOAD 	State
	SUB 	Two
	JZERO 	WestsideN2S
	LOAD 	State
	SUB 	Three
	JZERO 	SouthsideW2E
	LOAD 	State
	SUB 	Four
	JZERO 	SouthsideSweep
	LOAD 	State
	SUB 	Five
	JZERO 	SouthsideE2W
	LOAD 	State
	SUB 	Six
	JZERO 	WestsideS2N
	LOAD 	State
	SUB 	Seven
	JZERO 	NorthsideW2E
	;if we get here, something has broken, so kill everything
	JUMP 	Die
;end of stateswitch


;Sonar interrupt proceeds here. Increment the state variable, then enter switch gauntlet
BaffleTrigger:		
	LOADI 	0
	STORE	DVel
	CALL	StateAdvance
	JUMP	StateSwitch
	
;advances state variable. Wraps around back to zero if greater than max size
StateAdvance:
	LOAD	State
	SUB 	StateMax
	JZERO	NoWrap
	JUMP	WrapUp
NoWrap:
	LOAD 	State
	ADDI	1
WrapUp:
	STORE	State
	RETURN

PreCalc:
	;TO-DO
	;calculates minor changes to the arena based on the baffle's vertical position
	LOAD	Mask0
	OUT 	SONAREN
	IN 		DIST0
	STORE	WallVar
	LOAD	NPathNWall
	SUB		WallVar
	STORE	WallVar
	LOADI	75
	SUB		WallVar
	JPOS	FullCalc
	JUMP	ShortCalc
FullCalc:
	LOAD	NPathNWall
	SUB		WallVar
	STORE	NPathNWall
	LOAD	SPathNWall
	SUB		WallVar
	STORE	SPathNWall
	LOAD	NPathSWall
	ADD		WallVar
	STORE	NPathSWall
	LOAD	SPathFarWall
	ADD		WallVar
	STORE	SPathFarWall
	LOAD	SPathCloseWall
	ADD		WallVar
	STORE	SPathCloseWall
TrigSection:
	LOAD	NPathNWall
	CALL	SecondPower
	STORE	Temp
	LOAD	NEPointBoundary
	CALL	SecondPower
	ADD		Temp
	CALL	RootTwo
	STORE	NEPointNECorner
	;line break for my sanity
	LOAD	NPathNWall
	CALL	SecondPower
	STORE	Temp
	LOAD	WPathWWall
	CALL	SecondPower
	ADD		Temp
	CALL	RootTwo
	STORE	NWPointNCorner
	;line break for my sanity
	LOADI	&H542
	CALL	SecondPower
	STORE	Temp
	LOAD	WPathWWall
	CALL	SecondPower
	ADD		Temp
	CALL	RootTwo
	STORE	NWPointWCorner
	;line break for my sanity
	LOADI	&H6D8
	CALL	SecondPower
	STORE	Temp
	LOAD	WPathWWall
	CALL	SecondPower
	ADD		Temp
	CALL	RootTwo
	STORE	SWPointWCorner
	;line break for my sanity
	LOAD	SPathCloseWall
	CALL	SecondPower
	STORE	Temp
	LOADI	&H379
	CALL	SecondPower
	ADD		Temp
	CALL	RootTwo
	STORE	SWPointSCorner
	;line break for my sanity
	LOAD	SEPointBoundary
	CALL	SecondPower
	STORE	Temp
	LOAD	SPathFarWall
	CALL	SecondPower
	ADD		Temp
	CALL	RootTwo
	STORE	SEPointSECorner
ShortCalc:
	; storing deltas for rotational sonar reading ease of use
	LOAD	NEPointBaffleInCorner
	SUB		NPathBaffleWall
	STORE	NEPTInCBWLDelta
	LOAD	NEPointBaffleOutCorner
	SUB		NPathBaffleWall
	STORE	NEPTOutCBWLDelta
	LOAD	NEPointBaffleOutCorner
	SUB		NEPointBoundary
	STORE	NEPTOutCBNDelta
	LOAD	NEPointNECorner
	SUB		NEPointBoundary
	STORE	NEPTNECBNDelta
	LOAD	NEPointNECorner
	SUB		NPathNWall
	STORE	NEPTNECNWLDelta
	LOAD	NWPointNCorner
	SUB		NPathNWall
	STORE	NWPTNCNWLDelta
	LOAD	NWPointWCorner
	SUB		WPathWWall
	STORE	NWPTWCWWLDelta
	LOAD	SWPointWCorner
	SUB		WPathWWall
	STORE	SWPTWCWWLDelta
	LOAD	SWPointSCorner
	SUB		SPathCloseWall
	STORE	SWPTSCCWLDelta
	LOAD	SEPointSECorner
	SUB		SPathFarWall
	STORE	SEPTSECFWLDelta
	LOAD	SEPointSECorner
	SUB		SEPointBoundary
	STORE	SEPTSECBNDelta
	LOAD	SEPointBaffleInCorner
	SUB		SPathBaffleWall
	STORE	SEPTInCBWLDelta
	LOAD	SEPointBaffleOutCorner
	SUB		SPathBaffleWall
	STORE	SEPTOutCBWLDelta
	LOAD	SEPointBaffleOutCorner
	SUB		SEPointBoundary
	STORE	SEPTOutCBNDelta
	; line break
	LOAD 	NPathBaffleWall
	STORE	AtanY
	LOAD 	NEPTInCBWLDelta
	STORE	AtanX
	CALL 	Atan2
	STORE	NEPTInCBWLTheta
	; line break
	LOAD  	NPathBaffleWall
	STORE 	AtanY
	LOAD  	NEPTOutCBWLDelta
	STORE 	AtanX
	CALL  	Atan2
	STORE 	NEPTOutCBWLTheta
	; line break
	LOAD  	NEPTOutCBNDelta
	STORE 	AtanY
	LOAD  	NEPointBoundary
	STORE	AtanX
	CALL  	Atan2
	STORE 	NEPTOutCBNTheta
	; line break
	LOAD  	NEPTNECBNDelta
	STORE 	AtanY
	LOAD  	NEPointBoundary
	STORE 	AtanX
	CALL  	Atan2
	STORE 	NEPTNECBNTheta
	; line break
	LOAD  	NPathNWall
	STORE 	AtanY
	LOAD  	NEPTNECNWLDelta
	STORE 	AtanX
	CALL  	Atan2
	STORE 	NEPTNECNWLTheta
	; line break
	LOAD  	NPathNWall
	STORE 	AtanY
	LOAD  	NWPTNCNWLDelta
	STORE 	AtanX
	CALL  	Atan2
	STORE 	NWPTNCNWLTheta
	;line break
	LOADI	90
	SUB		NWPTNCNWLTheta
	STORE	Temp
	LOAD	Temp
	SUB		NWPTWCWWLTheta
	STORE 	NWPTNCWCTheta
	;line break
	LOAD  	NWPTWCWWLDelta
	STORE 	AtanY
	LOAD  	WPathWWall
	STORE 	AtanX
	CALL  	Atan2
	STORE 	NWPTWCWWLTheta
	;line break
	;SWPTWCWSCTheta
	LOADI	90
	SUB		SWPTWCWWLTheta
	STORE	Temp
	LOAD	Temp
	SUB		SWPTSCCWLDelta
	STORE 	SWPTWCWSCTheta
	;line break
	;SWPTSCCWLTheta
	LOAD  	SPathCloseWall
	STORE 	AtanY
	LOAD  	SWPTSCCWLDelta
	STORE 	AtanX
	CALL  	Atan2
	STORE 	SWPTSCCWLTheta
	;line break
	LOAD  	SWPTWCWWLDelta
	STORE 	AtanY
	LOAD  	WPathWWall
	STORE 	AtanX
	CALL  	Atan2
	STORE 	SWPTWCWWLTheta
	;line break
	LOAD  	SPathFarWall
	STORE 	AtanY
	LOAD  	SEPTSECFWLDelta
	STORE 	AtanX
	CALL  	Atan2
	STORE 	SEPTSECFWLTheta
	; line break
	LOAD  	SEPTSECBNDelta
	STORE 	AtanY
	LOAD  	SEPointBoundary
	STORE 	AtanX
	CALL  	Atan2
	STORE 	SEPTSECBNTheta
	;line break
	LOAD  	SPathBaffleWall
	STORE 	AtanY
	LOAD  	SEPTInCBWLDelta
	STORE 	AtanX
	CALL  	Atan2
	STORE 	SEPTInCBWLTheta
	;line break
	LOAD  	SPathBaffleWall
	STORE 	AtanY
	LOAD  	SEPTOutCBWLDelta
	STORE 	AtanX
	CALL  	Atan2
	STORE 	SEPTOutCBWLTheta
	;line break
	LOAD  	SEPTOutCBNDelta
	STORE 	AtanY
	LOAD  	SEPointBoundary
	STORE 	AtanX
	CALL  	Atan2
	STORE 	SEPTOutCBNTheta
	JUMP	PostCalcWaitCycle
	
PostCalcWaitCycle:
	; This loop will wait for the user to press PB3, to ensure that
	; they have a chance to prepare for any movement in the main code.
	IN     TIMER       ; Used to blink the LEDs above PB3
	AND    Mask1
	SHIFT  5           ; Both LEDG6 and LEDG7
	STORE  Temp        ; (overkill, but looks nice)
	SHIFT  1
	OR     Temp
	OUT    XLEDS
	IN     XIO         ; XIO contains KEYs
	AND    Mask2       ; KEY3 mask (KEY0 is reset and can't be read)
	JPOS   PostCalcWaitCycle ; not ready (KEYs are active-low, hence JPOS)
	LOAD   Zero
	OUT    XLEDS       ; clear LEDs once ready to continue
	JUMP	StateSwitch

InitialMovement:
	IN		Dist3
	STORE	Temp
	IN		DIST2
	ADD		Temp
	SHIFT	-1
	LOAD	StartingWWall
	SUB		Temp
	JNEG	InitialMovement
	JZERO	StateSwitch
	JPOS	StateSwitch

	
NorthsideSweep:
	;TO-DO
	;execute the 180 degree scan above the baffle	
	; turn left 180 degrees
	LOADI	&B00100001
	STORE	SONAREN
	LOADI	0
	STORE	CourseCorrectToggle
	STORE 	DVel
	LOADI 	360
	STORE 	DTheta
	CALL	StillTurning
	CALL	StateAdvance
	JUMP	StateSwitch
;turns to DTheta at DVel based on internal odometry
StillTurning:
	CALL   GetThetaErr 		; get the heading error
	CALL   Abs         		; absolute value subroutine
	OUT    LCD        	 	; Display |angle error| for debugging
	ADDI   -3         	 	; check if within 5 degrees of target angle
	JPOS   StillTurning     ; if not, keep testing
	; the robot is now within 5 degrees of 90
	RETURN
	
	
NorthsideE2W:
	;Move towards the west wall, execute 90 degree turn(result: facing south) after passing T-Bar edge
	LOADI	&B00100001
	OUT		SONAREN
	LOADI	1
	STORE	CourseCorrectToggle
	LOAD	ClockTimer
	OR		Zero
	JZERO	TimerSetup
	LOAD	FMid
	STORE	DVel
	OUT		TIMER
NPathLoop1:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	NPathLoop1
TimerExit:
	OUT		TIMER
NPathLoop2:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	NPathLoop2
	LOADI	0
	STORE	DVel ;stahp
	LOADI	90
	STORE	DTheta
	CALL	StillTurning ;robot turns 90 degrees to the south, and moves to state[2]
	CALL	StateAdvance
	CALL	StateSwitch
	;END of Northside East to West transit
TimerSetup:
	OUT		TIMER
	LOAD	FMid
	STORE	DVel
TimerSetupLoop:
	IN		DIST0
	SUB		NPathBaffleWall
	JPOS	TimerBreak
	JUMP	TimerSetupLoop
TimerBreak:
	IN		TIMER
	STORE	ClockTimer
	JUMP	TimerExit
	

WestsideN2S:
	;Move south, follow baffle t-bar, execute 90 degree turn(result: facing east) after passing t-bar
	LOADI	&B00100001
	OUT		SONAREN
	LOADI	1
	STORE	CourseCorrectToggle
	LOAD	FMid
	STORE	DVel
WestSideN2SPhase1:
	IN		DIST0 ;load sonar reading again, check if baffle. If not baffle, then intruder
	STORE	Temp
	LOAD	WPathBaffleWall
	ADDI	100
	SUB		Temp
	JPOS	WestSideN2SIntruderSkip
	LOADI	&H724
	STORE	Temp
	IN		DIST0
	SUB		Temp
	JPOS	WestSideN2SPhase1
	CALL	IntruderAlert
WestSideN2SIntruderSkip:
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
WestSideN2SPhase2: ;traverse 48 inches due south
	LOAD	WestSideN2SCounter
	OR		Zero
	JZERO	WestSideN2SPhase2Exit
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	WestSideN2SPhase2
	JZERO	WestSideN2STimerDecrement
	JNEG	WestSideN2STimerDecrement
WestSideN2STimerDecrement:
	LOAD	WestSideN2SCounter
	SUB		One
	STORE	WestSideN2SCounter
	JUMP	WestSideN2SPhase2
WestSideN2SPhase2Exit:
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
WestSideN2SPhase3:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	WestSideN2SPhase3
	LOADI	0
	STORE	DVel
	LOADI	180
	STORE	DTheta
	CALL	StillTurning
	CALL	StateAdvance
	JUMP	StateSwitch
WestSideN2SCounter: DW 4

SouthsideW2E:
	;TO-DO
	;Move east, follow baffle,  stop after moving ~12 inches past the edge
	LOADI	&B00100001
	OUT		SONAREN
	LOADI	1
	STORE	CourseCorrectToggle
	LOAD	FMid
	STORE	DVel
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
SouthsideE2WLoop:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	SouthsideE2WLoop
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
SouthsideE2WLoop2:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	SouthsideE2WLoop2
	LOADI	0
	STORE	DVel
	STORE	DTheta
	CALL	StillTurning
	CALL	StateAdvance
	JUMP	StateSwitch

SouthsideSweep:
	;TO-DO
	;Execute 180 degree scan below the baffle
	LOADI	&B00000001
	OUT		SONAREN
	LOADI	0
	STORE	CourseCorrectToggle
	LOADI  360
	STORE  	DTheta
	CALL	StillTurning
	CALL	StateAdvance
	JUMP	StateSwitch


SouthsideE2W:
	;TO-DO
	;Move towards the west wall, execute 90 degree turn(result: facing north) after passing T-Bar edge
	LOADI	&B00100001
	OUT		SONAREN
	LOADI	1
	STORE	CourseCorrectToggle
	LOAD	FMid
	STORE	DVel
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
SPathLoop1:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	SPathLoop1
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
SPathLoop2:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	SPathLoop2
	LOADI	0
	STORE	DVel ;stahp
	LOADI	-90
	STORE	DTheta
	CALL	StillTurning
	CALL	StateAdvance
	JUMP	StateSwitch


WestsideS2N:
	;TO-DO
	;Move north, follow baffle t-bar, execute 90 degree turn(result: facing east) after passing t-bar
	LOADI	&B00100001
	OUT		SONAREN
	LOADI	1
	STORE	CourseCorrectToggle
	LOAD	FMid
	STORE	DVel
WestSideS2NPhase1:
	IN		DIST5 ;load sonar reading again, check if baffle. If not baffle, then intruder
	STORE	Temp
	LOAD	WPathBaffleWall
	ADDI	100
	SUB		Temp
	JPOS	WestSideS2NIntruderSkip
	LOADI	&H724
	STORE	Temp
	IN		DIST5
	SUB		Temp
	JPOS	WestSideS2NPhase1
	CALL	IntruderAlert
WestSideS2NIntruderSkip:
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
WestSideS2NPhase2: ;traverse 48 inches due north
	LOAD	WestSideS2NCounter
	OR		Zero
	JZERO	WestSideS2NPhase2Exit
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	WestSideS2NPhase2
	JZERO	WestSideS2NTimerDecrement
	JNEG	WestSideS2NTimerDecrement
WestSideS2NTimerDecrement:
	LOAD	WestSideS2NCounter
	SUB		One
	STORE	WestSideS2NCounter
	JUMP	WestSideS2NPhase2
WestSideS2NPhase2Exit:
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
WestSideS2NPhase3:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	WestSideS2NPhase3
	LOADI	0
	STORE	DVel
	LOADI	180
	STORE	DTheta
	CALL	StillTurning
	CALL	StateAdvance
	JUMP	StateSwitch
WestSideS2NCounter: DW 4


NorthsideW2E:
	;TO-DO
	;Move south, follow baffle, stop after moving ~12 inches past the edge
	LOADI	&B00100001
	OUT		SONAREN
	LOADI	1
	STORE	CourseCorrectToggle
	LOAD	FMid
	STORE	DVel
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
NorthsideW2ELoop:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	NorthsideW2ELoop
	OUT		TIMER
	LOADI	0
	STORE	InteruptTotal
NorthsideW2ELoop2:
	IN		TIMER
	STORE	Temp
	LOAD	ClockTimer
	SUB		Temp
	ADD		InteruptTotal
	JPOS	NorthsideW2ELoop2
	LOADI	0
	STORE	DVel
	STORE	DTheta
	CALL	StillTurning
	CALL	StateAdvance
	JUMP	StateSwitch

;end of states

IntruderAlert:
	LOADI	&H20
	OUT		BEEP 
	CALL	Wait1
	LOADI	0
	OUT		BEEP
	RETURN
	



SonarCycleSetup:
	LOAD 	Mask0
	OUT 	SONAREN
	STORE 	CurrSonar
SonarLoop:
	;detect sonar that is on: TODO
	CALL SonarSwitch
	;detect button press
	IN 		XIO
	AND		Mask2 ; isolate PB3
	SUB		Four
	JNEG	SonarCycle
	JUMP 	SonarLoop
SonarCycle:
	LOAD 	CurrSonar
	ADDI 	One
	STORE	CurrSonar
	SUB		Mask7
	JPOS	NewLoop
	LOAD	CurrSonar
BackIn:
	OUT 	SONAREN
	JUMP	SonarLoop
NewLoop:
	LOAD 	Mask0
	STORE	CurrSonar
	JUMP	BackIn
SonarSwitch:
	LOAD	CurrSonar
	SUB		Mask0
	JZERO	Switch0
	LOAD	CurrSonar
	SUB		Mask1
	JZERO	Switch1
	LOAD	CurrSonar
	SUB		Mask2
	JZERO	Switch2
	LOAD	CurrSonar
	SUB		Mask3
	JZERO	Switch3
	LOAD	CurrSonar
	SUB		Mask4
	JZERO	Switch4
	LOAD	CurrSonar
	SUB		Mask5
	JZERO	Switch5
	LOAD	CurrSonar
	SUB		Mask6
	JZERO	Switch6
	LOAD	CurrSonar
	SUB		Mask7
	JZERO	Switch7
Switch0:
	IN		DIST0
	OUT		LCD
	RETURN
Switch1:
	IN		DIST1
	OUT		LCD
	RETURN
Switch2:
	IN		DIST2
	OUT		LCD
	RETURN
Switch3:
	IN		DIST3
	OUT		LCD
	RETURN
Switch4:
	IN		DIST4
	OUT		LCD
	RETURN
Switch5:
	IN		DIST5
	OUT		LCD
	RETURN
Switch6:
	IN		DIST6
	OUT		LCD
	RETURN
Switch7:
	IN		DIST7
	OUT		LCD
	RETURN
	
;********************
;Raise to 2nd power
;By Kyle Hosford
;********************
SecondPower:
	STORE	m16sA
	STORE	m16sB
	CALL 	Mult16s
	LOAD	mres16sH
	RETURN
	
;********************************
; Babylonian Square Root Algorithm (Root 2)
; Written by Kyle Hosford, Fall 2017
; Calculates square root of AC value
; Recurses until value has converged
;********************************
RootTwo:
	;Setup
	STORE	InitNum
	SHIFT	-2
	STORE	RootX0 ;use 1/4 IN number as arbitrary positive starting point
RootRecurse:
	LOAD	InitNum
	STORE	d16sN
	LOAD	RootX0
	STORE	d16sD
	CALL	Div16s ; S / X0
	LOAD	dres16sQ
	ADD		RootX0 ; + X0
	SHIFT	-1 ; divide by 2
	STORE	RootX1
	AND		RootX0 ; check against previous iteration
	SUB		RootX0
	JZERO	RootFinish ; if they're the same, we're done. Otherwise, keep chugging
	LOAD	RootX1
	STORE	RootX0
	JUMP	RootRecurse
RootFinish:
	LOAD	RootX1
	RETURN
InitNum:	DW 0
RootX1:		DW 0
RootX0: 	DW 0
;*******************************************************************************
; Mod360: modulo 360
; Returns AC%360 in AC
; Written by Kevin Johnson.  No licence or copyright applied.
;*******************************************************************************
Mod360:
	; easy modulo: subtract 360 until negative then add 360 until not negative
	JNEG   M360N
	ADDI   -360
	JUMP   Mod360
M360N:
	ADDI   360
	JNEG   M360N
	RETURN

;*******************************************************************************
; Abs: 2's complement absolute value
; Returns abs(AC) in AC
; Neg: 2's complement negation
; Returns -AC in AC
; Written by Kevin Johnson.  No licence or copyright applied.
;*******************************************************************************
Abs:
	JPOS   Abs_r
Neg:
	XOR    NegOne       ; Flip all bits
	ADDI   1            ; Add one (i.e. negate number)
Abs_r:
	RETURN

;******************************************************************************;
; Atan2: 4-quadrant arctangent calculation                                     ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; Original code by Team AKKA, Spring 2015.                                     ;
; Based on methods by Richard Lyons                                            ;
; Code updated by Kevin Johnson to use software mult and div                   ;
; No license or copyright applied.                                             ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; To use: store dX and dY in global variables AtanX and AtanY.                 ;
; Call Atan2                                                                   ;
; Result (angle [0,359]) is returned in AC                                     ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; Requires additional subroutines:                                             ;
; - Mult16s: 16x16->32bit signed multiplication                                ;
; - Div16s: 16/16->16R16 signed division                                       ;
; - Abs: Absolute value                                                        ;
; Requires additional constants:                                               ;
; - One:     DW 1                                                              ;
; - NegOne:  DW 0                                                              ;
; - LowByte: DW &HFF                                                           ;
;******************************************************************************;
Atan2:
	LOAD   AtanY
	CALL   Abs          ; abs(y)
	STORE  AtanT
	LOAD   AtanX        ; abs(x)
	CALL   Abs
	SUB    AtanT        ; abs(x) - abs(y)
	JNEG   A2_sw        ; if abs(y) > abs(x), switch arguments.
	LOAD   AtanX        ; Octants 1, 4, 5, 8
	JNEG   A2_R3
	CALL   A2_calc      ; Octants 1, 8
	JNEG   A2_R1n
	RETURN              ; Return raw value if in octant 1
A2_R1n: ; region 1 negative
	ADDI   360          ; Add 360 if we are in octant 8
	RETURN
A2_R3: ; region 3
	CALL   A2_calc      ; Octants 4, 5
	ADDI   180          ; theta' = theta + 180
	RETURN
A2_sw: ; switch arguments; octants 2, 3, 6, 7
	LOAD   AtanY        ; Swap input arguments
	STORE  AtanT
	LOAD   AtanX
	STORE  AtanY
	LOAD   AtanT
	STORE  AtanX
	JPOS   A2_R2        ; If Y positive, octants 2,3
	CALL   A2_calc      ; else octants 6, 7
	CALL   Neg          ; Negatge the number
	ADDI   270          ; theta' = 270 - theta
	RETURN
A2_R2: ; region 2
	CALL   A2_calc      ; Octants 2, 3
	CALL   Neg          ; negate the angle
	ADDI   90           ; theta' = 90 - theta
	RETURN
A2_calc:
	; calculates R/(1 + 0.28125*R^2)
	LOAD   AtanY
	STORE  d16sN        ; Y in numerator
	LOAD   AtanX
	STORE  d16sD        ; X in denominator
	CALL   A2_div       ; divide
	LOAD   dres16sQ     ; get the quotient (remainder ignored)
	STORE  AtanRatio
	STORE  m16sA
	STORE  m16sB
	CALL   A2_mult      ; X^2
	STORE  m16sA
	LOAD   A2c
	STORE  m16sB
	CALL   A2_mult
	ADDI   256          ; 256/256+0.28125X^2
	STORE  d16sD
	LOAD   AtanRatio
	STORE  d16sN        ; Ratio in numerator
	CALL   A2_div       ; divide
	LOAD   dres16sQ     ; get the quotient (remainder ignored)
	STORE  m16sA        ; <= result in radians
	LOAD   A2cd         ; degree conversion factor
	STORE  m16sB
	CALL   A2_mult      ; convert to degrees
	STORE  AtanT
	SHIFT  -7           ; check 7th bit
	AND    One
	JZERO  A2_rdwn      ; round down
	LOAD   AtanT
	SHIFT  -8
	ADDI   1            ; round up
	RETURN
A2_rdwn:
	LOAD   AtanT
	SHIFT  -8           ; round down
	RETURN
A2_mult: ; multiply, and return bits 23..8 of result
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8            ; move high word of result up 8 bits
	STORE  mres16sH
	LOAD   mres16sL
	SHIFT  -8           ; move low word of result down 8 bits
	AND    LowByte
	OR     mres16sH     ; combine high and low words of result
	RETURN
A2_div: ; 16-bit division scaled by 256, minimizing error
	LOADI  9            ; loop 8 times (256 = 2^8)
	STORE  AtanT
A2_DL:
	LOAD   AtanT
	ADDI   -1
	JPOS   A2_DN        ; not done; continue shifting
	CALL   Div16s       ; do the standard division
	RETURN
A2_DN:
	STORE  AtanT
	LOAD   d16sN        ; start by trying to scale the numerator
	SHIFT  1
	XOR    d16sN        ; if the sign changed,
	JNEG   A2_DD        ; switch to scaling the denominator
	XOR    d16sN        ; get back shifted version
	STORE  d16sN
	JUMP   A2_DL
A2_DD:
	LOAD   d16sD
	SHIFT  -1           ; have to scale denominator
	STORE  d16sD
	JUMP   A2_DL
AtanX:      DW 0
AtanY:      DW 0
AtanRatio:  DW 0        ; =y/x
AtanT:      DW 0        ; temporary value
A2c:        DW 72       ; 72/256=0.28125, with 8 fractional bits
A2cd:       DW 14668    ; = 180/pi with 8 fractional bits

;*******************************************************************************
; Mult16s:  16x16 -> 32-bit signed multiplication
; Based on Booth's algorithm.
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: does not work with factor B = -32768 (most-negative number).
; To use:
; - Store factors in m16sA and m16sB.
; - Call Mult16s
; - Result is stored in mres16sH and mres16sL (high and low words).
;*******************************************************************************
Mult16s:
	LOADI  0
	STORE  m16sc        ; clear carry
	STORE  mres16sH     ; clear result
	LOADI  16           ; load 16 to counter
Mult16s_loop:
	STORE  mcnt16s
	LOAD   m16sc        ; check the carry (from previous iteration)
	JZERO  Mult16s_noc  ; if no carry, move on
	LOAD   mres16sH     ; if a carry,
	ADD    m16sA        ;  add multiplicand to result H
	STORE  mres16sH
Mult16s_noc: ; no carry
	LOAD   m16sB
	AND    One          ; check bit 0 of multiplier
	STORE  m16sc        ; save as next carry
	JZERO  Mult16s_sh   ; if no carry, move on to shift
	LOAD   mres16sH     ; if bit 0 set,
	SUB    m16sA        ;  subtract multiplicand from result H
	STORE  mres16sH
Mult16s_sh:
	LOAD   m16sB
	SHIFT  -1           ; shift result L >>1
	AND    c7FFF        ; clear msb
	STORE  m16sB
	LOAD   mres16sH     ; load result H
	SHIFT  15           ; move lsb to msb
	OR     m16sB
	STORE  m16sB        ; result L now includes carry out from H
	LOAD   mres16sH
	SHIFT  -1
	STORE  mres16sH     ; shift result H >>1
	LOAD   mcnt16s
	ADDI   -1           ; check counter
	JPOS   Mult16s_loop ; need to iterate 16 times
	LOAD   m16sB
	STORE  mres16sL     ; multiplier and result L shared a word
	RETURN              ; Done
c7FFF: DW &H7FFF
m16sA: DW 0 ; multiplicand
m16sB: DW 0 ; multipler
m16sc: DW 0 ; carry
mcnt16s: DW 0 ; counter
mres16sL: DW 0 ; result low
mres16sH: DW 0 ; result high

;*******************************************************************************
; Div16s:  16/16 -> 16 R16 signed division
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: results undefined if denominator = 0.
; To use:
; - Store numerator in d16sN and denominator in d16sD.
; - Call Div16s
; - Result is stored in dres16sQ and dres16sR (quotient and remainder).
; Requires Abs subroutine
;*******************************************************************************
Div16s:
	LOADI  0
	STORE  dres16sR     ; clear remainder result
	STORE  d16sC1       ; clear carry
	LOAD   d16sN
	XOR    d16sD
	STORE  d16sS        ; sign determination = N XOR D
	LOADI  17
	STORE  d16sT        ; preload counter with 17 (16+1)
	LOAD   d16sD
	CALL   Abs          ; take absolute value of denominator
	STORE  d16sD
	LOAD   d16sN
	CALL   Abs          ; take absolute value of numerator
	STORE  d16sN
Div16s_loop:
	LOAD   d16sN
	SHIFT  -15          ; get msb
	AND    One          ; only msb (because shift is arithmetic)
	STORE  d16sC2       ; store as carry
	LOAD   d16sN
	SHIFT  1            ; shift <<1
	OR     d16sC1       ; with carry
	STORE  d16sN
	LOAD   d16sT
	ADDI   -1           ; decrement counter
	JZERO  Div16s_sign  ; if finished looping, finalize result
	STORE  d16sT
	LOAD   dres16sR
	SHIFT  1            ; shift remainder
	OR     d16sC2       ; with carry from other shift
	SUB    d16sD        ; subtract denominator from remainder
	JNEG   Div16s_add   ; if negative, need to add it back
	STORE  dres16sR
	LOADI  1
	STORE  d16sC1       ; set carry
	JUMP   Div16s_loop
Div16s_add:
	ADD    d16sD        ; add denominator back in
	STORE  dres16sR
	LOADI  0
	STORE  d16sC1       ; clear carry
	JUMP   Div16s_loop
Div16s_sign:
	LOAD   d16sN
	STORE  dres16sQ     ; numerator was used to hold quotient result
	LOAD   d16sS        ; check the sign indicator
	JNEG   Div16s_neg
	RETURN
Div16s_neg:
	LOAD   dres16sQ     ; need to negate the result
	CALL   Neg
	STORE  dres16sQ
	RETURN
d16sN: DW 0 ; numerator
d16sD: DW 0 ; denominator
d16sS: DW 0 ; sign value
d16sT: DW 0 ; temp counter
d16sC1: DW 0 ; carry value
d16sC2: DW 0 ; carry value
dres16sQ: DW 0 ; quotient result
dres16sR: DW 0 ; remainder result

;*******************************************************************************
; L2Estimate:  Pythagorean distance estimation
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: this is *not* an exact function.  I think it's most wrong
; on the axes, and maybe at 45 degrees.
; To use:
; - Store X and Y offset in L2X and L2Y.
; - Call L2Estimate
; - Result is returned in AC.
; Result will be in same units as inputs.
; Requires Abs and Mult16s subroutines.
;*******************************************************************************
L2Estimate:
	; take abs() of each value, and find the largest one
	LOAD   L2X
	CALL   Abs
	STORE  L2T1
	LOAD   L2Y
	CALL   Abs
	SUB    L2T1
	JNEG   GDSwap    ; swap if needed to get largest value in X
	ADD    L2T1
CalcDist:
	; Calculation is max(X,Y)*0.961+min(X,Y)*0.406
	STORE  m16sa
	LOADI  246       ; max * 246
	STORE  m16sB
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8
	STORE  L2T2
	LOAD   mres16sL
	SHIFT  -8        ; / 256
	AND    LowByte
	OR     L2T2
	STORE  L2T3
	LOAD   L2T1
	STORE  m16sa
	LOADI  104       ; min * 104
	STORE  m16sB
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8
	STORE  L2T2
	LOAD   mres16sL
	SHIFT  -8        ; / 256
	AND    LowByte
	OR     L2T2
	ADD    L2T3     ; sum
	RETURN
GDSwap: ; swaps the incoming X and Y
	ADD    L2T1
	STORE  L2T2
	LOAD   L2T1
	STORE  L2T3
	LOAD   L2T2
	STORE  L2T1
	LOAD   L2T3
	JUMP   CalcDist
L2X:  DW 0
L2Y:  DW 0
L2T1: DW 0
L2T2: DW 0
L2T3: DW 0


; Subroutine to wait (block) for 1 second
Wait1:
	OUT    TIMER
Wloop:
	IN     TIMER
	OUT    XLEDS       ; User-feedback that a pause is occurring.
	ADDI   -10         ; 1 second at 10Hz.
	JNEG   Wloop
	RETURN

; This subroutine will get the battery voltage,
; and stop program execution if it is too low.
; SetupI2C must be executed prior to this.
BattCheck:
	CALL   GetBattLvl
	JZERO  BattCheck   ; A/D hasn't had time to initialize
	SUB    MinBatt
	JNEG   DeadBatt
	ADD    MinBatt     ; get original value back
	RETURN
; If the battery is too low, we want to make
; sure that the user realizes it...
DeadBatt:
	LOADI  &H20
	OUT    BEEP        ; start beep sound
	CALL   GetBattLvl  ; get the battery level
	OUT    SSEG1       ; display it everywhere
	OUT    SSEG2
	OUT    LCD
	LOAD   Zero
	ADDI   -1          ; 0xFFFF
	OUT    LEDS        ; all LEDs on
	OUT    XLEDS
	CALL   Wait1       ; 1 second
	LOADI  &H140       ; short, high-pitched beep
	OUT    BEEP        ; stop beeping
	LOAD   Zero
	OUT    LEDS        ; LEDs off
	OUT    XLEDS
	CALL   Wait1       ; 1 second
	JUMP   DeadBatt    ; repeat forever

; Subroutine to read the A/D (battery voltage)
; Assumes that SetupI2C has been run
GetBattLvl:
	LOAD   I2CRCmd     ; 0x0190 (write 0B, read 1B, addr 0x90)
	OUT    I2C_CMD     ; to I2C_CMD
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	IN     I2C_DATA    ; get the returned data
	RETURN

; Subroutine to configure the I2C for reading batt voltage
; Only needs to be done once after each reset.
SetupI2C:
	CALL   BlockI2C    ; wait for idle
	LOAD   I2CWCmd     ; 0x1190 (write 1B, read 1B, addr 0x90)
	OUT    I2C_CMD     ; to I2C_CMD register
	LOAD   Zero        ; 0x0000 (A/D port 0, no increment)
	OUT    I2C_DATA    ; to I2C_DATA register
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	RETURN

; Subroutine to block until I2C device is idle
BlockI2C:
	LOAD   Zero
	STORE  Temp        ; Used to check for timeout
BI2CL:
	LOAD   Temp
	ADDI   1           ; this will result in ~0.1s timeout
	STORE  Temp
	JZERO  I2CError    ; Timeout occurred; error
	IN     I2C_RDY     ; Read busy signal
	JPOS   BI2CL       ; If not 0, try again
	RETURN             ; Else return
I2CError:
	LOAD   Zero
	ADDI   &H12C       ; "I2C"
	OUT    SSEG1
	OUT    SSEG2       ; display error message
	JUMP   I2CError

;***************************************************************
;* Variables
;***************************************************************
Temp:	    DW 0 ; "Temp" is not a great name, but can be useful
CurrSonar:	DW 0 ; Iterative sonar counter.
State: 		DW 0 ; state tracking variable; max: 7
BaffleVar:	DW 0 ;variable for baffle calculations
WallVar: 	DW 0 ;variable for wall calculations
ClockTimer:		DW 0

;***************************************************************
;* Constants
;* (though there is nothing stopping you from writing to these)
;***************************************************************
NegOne:   DW -1
Zero:     DW 0
One:      DW 1
Two:      DW 2
Three:    DW 3
Four:     DW 4
Five:     DW 5
Six:      DW 6
Seven:    DW 7
Eight:    DW 8
Nine:     DW 9
Ten:      DW 10


CourseCorrectToggle:	DW 0 ;write 0 to disable course correction, 1 to enable. Defaults disabled
InteruptTimer:			DW 0 ;timer to account for interrupt time
InteruptTotal:			DW 0

StateMax:
		DW 7
SonarInterruptMask:
		DW &B1000
BafflePointMark:
		DW 30
SonarMaskZeroAndFive:
		DW &B00100001
;Distances from the patrol path to the baffle walls

NEPointNECorner:
		DW &H895
NEPointBoundary:
		DW &H4C3
NEPointBaffleOutCorner:
		DW &H5F4
NEPointBaffleInCorner:
		DW &H3C4
NEPointWWall:
		DW &H7BD
NPathBaffleWall:
		DW &H392
NPathBaffleEdge:
		DW &H131
NPathNWall:
		DW &H725
NPathSWall:
		DW &HE4A
NWPointNCorner:
		DW &H7F1
NWPointWCorner:
		DW &H781
WPathWWall:
		DW &H55C
WPathBoundary:
		DW &H725
WPathBaffleWall:
		DW &H131
SWPointWCorner:
		DW &H8B1
SWPointSCorner:
		DW &HA1E
SPathNWall:
		DW &HE4A
SPathFarWall:
		DW &HE30
SPathCloseWall:
		DW &H96D
SPathBaffleWall:
		DW &H392
SPathBaffleCorner:
		DW &H131
SEPointWWall:
		DW &H7BD
SEPointBaffleInCorner:
		DW &H3C4
SEPointBaffleOutCorner:
		DW &H5F4
SEPointBoundary:
		DW &H4C3
SEPointSECorner:
		DW &HEF7
NEPTInCBWLDelta:
		DW 0
NEPTInCBWLTheta:
		DW 0
NEPTOutCBWLDelta:
		DW 0
NEPTOutCBWLTheta:
		DW 0
NEPTOutCBNDelta:
		DW 0
NEPTOutCBNTheta:
		DW 0
NEPTNECBNDelta:
		DW 0
NEPTNECBNTheta:
		DW 0
NEPTNECNWLDelta:
		DW 0
NEPTNECNWLTheta:
		DW 0
NWPTNCNWLDelta:
		DW 0
NWPTNCNWLTheta:
		DW 0
NWPTNCWCDelta:
		DW 0
NWPTNCWCTheta: 
		DW 0
NWPTWCWWLDelta:
		DW 0
NWPTWCWWLTheta: 
		DW 0	
SWPTWCWWLDelta:
		DW 0
SWPTWCWWLTheta:
		DW 0	
SWPTWCWSCTheta:
		DW 0
SWPTSCCWLDelta:
		DW 0
SWPTSCCWLTheta:
		DW 0
SEPTSECFWLDelta:
		DW 0
SEPTSECFWLTheta:
		DW 0
SEPTSECBNDelta:
		DW 0
SEPTSECBNTheta:
		DW 0
SEPTInCBWLDelta:
		DW 0
SEPTInCBWLTheta:
		DW 0
SEPTOutCBWLDelta:
		DW 0
SEPTOutCBWLTheta:
		DW 0
SEPTOutCBNDelta:
		DW 0
SEPTOutCBNTheta:
		DW 0


BaffWallLowBound:	
		DW &H032D	;distance to horizontal wall, lower bound: 32", upper bound: 40", ideal: 36"
BaffleMargin:		
		DW &H00CB	;margin of error: 8"
TBarLowBound:		
		DW &H00CB	;distance to T-Bar wall, lower bound: 8", upper bound: 16", ideal: 12"
TBarEdgeLowBound:	
		DW &H00CB	;distance to T-Bar end, lower bound: 8", upper bound: 16", ideal: 12"
StartingWWall:
		DW &H803



; Some bit masks.
; Masks of multiple bits can be constructed by ORing these
; 1-bit masks together.
Mask0:    DW &B00000001
Mask1:    DW &B00000010
Mask2:    DW &B00000100
Mask3:    DW &B00001000
Mask4:    DW &B00010000
Mask5:    DW &B00100000
Mask6:    DW &B01000000
Mask7:    DW &B10000000
LowByte:  DW &HFF      ; binary 00000000 1111111
LowNibl:  DW &HF       ; 0000 0000 0000 1111

; some useful movement values
OneMeter: DW 961       ; ~1m in 1.04mm units
HalfMeter: DW 481      ; ~0.5m in 1.04mm units
TwoFeet:  DW 586       ; ~2ft in 1.04mm units
OneFoot:  DW 293       ; ~2ft in 1.04mm units
Deg90:    DW 90        ; 90 degrees in odometer units
Deg180:   DW 180       ; 180
Deg270:   DW 270       ; 270
Deg360:   DW 360       ; can never actually happen; for math only
FSlow:    DW 100       ; 100 is about the lowest velocity value that will move
RSlow:    DW -100
FMid:     DW 350       ; 350 is a medium speed
RMid:     DW -350
FFast:    DW 500       ; 500 is almost max speed (511 is max)
RFast:    DW -500

MinBatt:  DW 140       ; 14.0V - minimum safe battery voltage
I2CWCmd:  DW &H1190    ; write one i2c byte, read one byte, addr 0x90
I2CRCmd:  DW &H0190    ; write nothing, read one byte, addr 0x90

;***************************************************************
;* IO address space map
;***************************************************************
SWITCHES: EQU &H00  ; slide switches
LEDS:     EQU &H01  ; red LEDs
TIMER:    EQU &H02  ; timer, usually running at 10 Hz
XIO:      EQU &H03  ; pushbuttons and some misc. inputs
SSEG1:    EQU &H04  ; seven-segment display (4-digits only)
SSEG2:    EQU &H05  ; seven-segment display (4-digits only)
LCD:      EQU &H06  ; primitive 4-digit LCD display
XLEDS:    EQU &H07  ; Green LEDs (and Red LED16+17)
BEEP:     EQU &H0A  ; Control the beep
CTIMER:   EQU &H0C  ; Configurable timer for interrupts
LPOS:     EQU &H80  ; left wheel encoder position (read only)
LVEL:     EQU &H82  ; current left wheel velocity (read only)
LVELCMD:  EQU &H83  ; left wheel velocity command (write only)
RPOS:     EQU &H88  ; same values for right wheel...
RVEL:     EQU &H8A  ; ...
RVELCMD:  EQU &H8B  ; ...
I2C_CMD:  EQU &H90  ; I2C module's CMD register,
I2C_DATA: EQU &H91  ; ... DATA register,
I2C_RDY:  EQU &H92  ; ... and BUSY register
UART_DAT: EQU &H98  ; UART data
UART_RDY: EQU &H98  ; UART status
SONAR:    EQU &HA0  ; base address for more than 16 registers....
DIST0:    EQU &HA8  ; the eight sonar distance readings
DIST1:    EQU &HA9  ; ...
DIST2:    EQU &HAA  ; ...
DIST3:    EQU &HAB  ; ...
DIST4:    EQU &HAC  ; ...
DIST5:    EQU &HAD  ; ...
DIST6:    EQU &HAE  ; ...
DIST7:    EQU &HAF  ; ...
SONALARM: EQU &HB0  ; Write alarm distance; read alarm register
SONARINT: EQU &HB1  ; Write mask for sonar interrupts
SONAREN:  EQU &HB2  ; register to control which sonars are enabled
XPOS:     EQU &HC0  ; Current X-position (read only)
YPOS:     EQU &HC1  ; Y-position
THETA:    EQU &HC2  ; Current rotational position of robot (0-359)
RESETPOS: EQU &HC3  ; write anything here to reset odometry to 0
RIN:      EQU &HC8
LIN:      EQU &HC9
IR_HI:    EQU &HD0  ; read the high word of the IR receiver (OUT will clear both words)
IR_LO:    EQU &HD1  ; read the low word of the IR receiver (OUT will clear both words)
