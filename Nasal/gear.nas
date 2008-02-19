#----------------------------------------------------------------------------
# Nose Wheel Steering
#----------------------------------------------------------------------------

# Constants
NWScutoffSpeed = 80.0; #knots

# Functions

computeNWS = func

 {

   groundSpeed = getprop ("velocities/groundspeed-kt");
   if (groundSpeed == nil) groundSpeed = 0.0;
   rudderInput = getprop ("controls/flight/rudder");

   if (groundSpeed < NWScutoffSpeed) 
     NWS = rudderInput * (NWScutoffSpeed - groundSpeed) / NWScutoffSpeed;
   else 
     NWS = 0.0;

   setprop ("controls/flight/NWS", NWS);

 } # end computeNWS
