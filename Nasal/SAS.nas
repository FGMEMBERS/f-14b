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

   SASroll = getprop ("/controls/flight/aileron");    
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
     phiDotZ = fakePitchRate * math.cos (roll*0.01745);
     phiDotX = headingRate * math.sin (roll*0.01745);
   }
   else 
   {
     phiDotZ = 0.0;
     phiDotX = 0.0;
   }
   
   
   setprop ("/orientation/phi-dot", phiDotZ  + phiDotX );
   
   pitchInput = getprop ("/controls/flight/elevator") + getprop ("/f-14/SAS/pitch-bias");

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

   ########################################################################3
   #yaw channel


   yawInput = getprop ("/controls/flight/rudder");

    if (yawInput < 0.1 and yawInput > -0.1)
         yawInput += getprop ("/f-14/SAS/yaw-bias");


     setprop ("/controls/flight/SAS-yaw", yawInput);

 } #end computeSAS
