#----------------------------------------------------------------------------
# Stability Augmentation System
#----------------------------------------------------------------------------

# Constants
MaxPitchElevator = 1.0;
MinPitchElevator = 0.5;

PitchLoSpeed = 230.0;

RollLoSpeed = 400.0;

MaxTrimRate = 0.015;
TrimIncrement = 0.015;

PreviousHeading = 0.0;
PreviousSlip = 0.0;

#Pid constants
var PitchVarTarget = 0.0;
var PitchKp = -0.05;
var PitchKi = 0.0;
var PitchKd = 0.0;

var RollVarTarget = 0.0;
var RollKp = 0.005;
var RollKi = 0.0;
var RollKd = 0.0;

var YawVarTarget = 0.0;
var YawKp = 0.01;
var YawKi = 0.0;
var YawKd = 0.0;


var PreviousPitchBias = 0.0;
var PreviousRollBias = 0.0;
var PreviousYawBias = 0.0;

#derivative
var PitchPIDpreviousError = 0.0;
var PitchPIDppError = 0.0;
var RollPIDpreviousError = 0.0;
var RollPIDppError = 0.0;
var YawPIDpreviousError = 0.0;
var YawPIDppError = 0.0;

#Limiters
PitchMaxOutput = 0.2;
PitchMinOutput = -0.2;

RollMaxOutput = 0.01;
RollMinOutput = -0.01;

YawMaxOutput = 0.3;
YawMinOutput = -0.3;

var raw_elev      = props.globals.getNode("controls/flight/elevator");
var smooth_elev   = props.globals.getNode("sim/model/f-14b/controls/flight/sas-elevator", 1);
var last_elev = 0;
var elev_smooth_factor = 0.1;


# Functions

CurrentTrim = 0.0;

trimUp = func 

 {
  
   
   CurrentTrim += TrimIncrement;
   if (CurrentTrim > 1.0) CurrentTrim = 1.0;
   setprop ("/controls/flight/elevator-trim", CurrentTrim);
 
 }

trimDown = func 

 {
  
   
   CurrentTrim -= TrimIncrement;
   if (CurrentTrim < -1.0) CurrentTrim = -1.0;
   setprop ("/controls/flight/elevator-trim", CurrentTrim);
 
 }

computeSAS = func

 {

   airspeed = getprop ("/velocities/airspeed-kt");
   squaredAirspeed = airspeed * airspeed;


   ########################################################################3
   #roll channel
   
   # Roll PID computation
   RollVarError = RollVarTarget - getprop ("/orientation/roll-deg");
   
   rollBias = PreviousRollBias 
              + RollKp * (RollVarError - RollPIDpreviousError)
			  + RollKi * deltaT * RollVarError
			  + RollKd * (RollVarError - 2* RollPIDpreviousError + RollPIDppError) / deltaT;

   RollPIDpreviousError = RollVarError;
   RollPIDppError = RollPIDpreviousError;
   PreviousRollBias = rollBias;

   if (rollBias > RollMaxOutput) rollBias = RollMaxOutput;
   if (rollBias < RollMinOutput) rollBias = RollMinOutput;


   SASroll = getprop ("/controls/flight/aileron") + rollBias + getprop ("/controls/flight/aileron-trim");   
   if (airspeed > RollLoSpeed)
     SASroll = SASroll * ( (RollLoSpeed * RollLoSpeed) / squaredAirspeed );

   setprop ("/controls/flight/SAS-roll", SASroll);

   ########################################################################3
   #pitch channel

   #compute pitch rate to feed PID controller
   fakePitchRate = getprop ("/orientation/pitch-rate-degps");
   currentHeading = getprop ("/orientation/heading-deg");
   roll = getprop("/orientation/roll-deg");

   if (currentHeading != nil and PreviousHeading != nil and fakePitchRate !=nil and roll!=nil)
   {
     headingRate = (currentHeading - PreviousHeading) / deltaT;
     PreviousHeading = currentHeading;
     phiDot = fakePitchRate * math.cos (roll*0.01745) + headingRate * math.sin (roll*0.01745);
   }
   else 
   {
     phiDot = 0.0;     
   }
   
   
   #setprop ("/orientation/phi-dot", phiDot);

	# - Filter that smooths the elevator input (helps in case of bad joystick).
	var raw_e = raw_elev.getValue();
	var filtered_move = (raw_e - last_elev) * elev_smooth_factor;
	var new_smooth_elev = last_elev + filtered_move;
	last_elev = new_smooth_elev;
	smooth_elev.setDoubleValue(new_smooth_elev);

   #pitchInput = getprop ("/controls/flight/elevator") + getprop ("/f-14/SAS/pitch-bias");

   # Pitch PID computation
   PitchVarError = PitchVarTarget - phiDot; 
   pitchBias = PreviousPitchBias 
              + PitchKp * (PitchVarError - PitchPIDpreviousError)
			  + PitchKi * deltaT * PitchVarError
			  + PitchKd * (PitchVarError - 2* PitchPIDpreviousError + PitchPIDppError) / deltaT;

   PitchPIDpreviousError = PitchVarError;
   PitchPIDppError = PitchPIDpreviousError;
   PreviousPitchBias = pitchBias;

   if (pitchBias > PitchMaxOutput) pitchBias = PitchMaxOutput;
   if (pitchBias < PitchMinOutput) pitchBias = PitchMinOutput;

   # pitchInput = getprop ("/controls/flight/elevator") + pitchBias;
   pitchInput = getprop ("sim/model/f-14b/controls/flight/sas-elevator") + pitchBias;

   #adapt trim rate to speed
   if (airspeed < 120.0) 
     TrimIncrement = MaxTrimRate;
   else 
     TrimIncrement = MaxTrimRate * 14400 / squaredAirspeed;

   #compute pitch trim bias due to flaps and Direct lift control

   currentFlaps =  getprop ("/surface-positions/aux-flap-pos-norm");
   if (currentFlaps == nil) currentFlaps = 0.0;
   
    flapsTrim = 0.20 * currentFlaps;
    DLCTrim = 0.08 * getprop ("controls/flight/DLC");

   pitchInput -= flapsTrim + DLCTrim;

   #nose down authority limit
   
   if (pitchInput > 0)
     SASpitch = pitchInput * MinPitchElevator;
   else 
     SASpitch = pitchInput * MaxPitchElevator;
   
   #  Quadratic Law
   if (airspeed > PitchLoSpeed)
     SASpitch = SASpitch * ( (PitchLoSpeed * PitchLoSpeed) / squaredAirspeed );

   # Autopilot pitch gearing vs. airspeed
   #if (airspeed > PitchLoSpeed)
   #  SASpitch = SASpitch * ( (PitchLoSpeed * PitchLoSpeed) / squaredAirspeed );
      
   setprop ("/controls/flight/SAS-pitch", SASpitch);

   ########################################################################
   #yaw channel

   # Yaw PID computation
   YawVarError = YawVarTarget - getprop ("/orientation/side-slip-deg");
   yawBias = PreviousYawBias 
             + YawKp * (YawVarError - YawPIDpreviousError)
			 + YawKi * deltaT * YawVarError
			 + YawKd * (YawVarError - 2* YawPIDpreviousError + YawPIDppError) / deltaT;

   YawPIDpreviousError = YawVarError;
   YawPIDppError = YawPIDpreviousError;
   PreviousYawBias = yawBias;

   if (yawBias > YawMaxOutput) yawBias = YawMaxOutput;
   if (yawBias < YawMinOutput) yawBias = YawMinOutput;

   yawInput = getprop ("/controls/flight/rudder");
   radalt =  getprop ("position/altitude-agl-ft");

    if (yawInput < 0.1 and yawInput > -0.1 and radalt > 50.0)
		 yawInput += yawBias;

     setprop ("/controls/flight/SAS-yaw", yawInput);


 } #end computeSAS
