
#----------------------------------------------------------------------------
# Spoiler computer     
# Most of it is for display purposes only since the YaSim flight model cannot
# handle split inputs for left and right wings that are not strict opposite
# Spoilers act for roll control, ground spoiler (anti-bounce) and direct lift
# control on approach
#----------------------------------------------------------------------------

# Constants
MaxFlightSpoilers = 0.7;
SpoilersMinima = 0.0;

# Functions

toggleDLC = func

 {

   if (!DLCactive and (getprop ("/controls/flight/flapscommand") >= FlapsToLdg))
     {
       DLCactive = true;
       setprop("/controls/flight/DLC",0.3);
     }
   else 
     {
       DLCactive = false;
       setprop("/controls/flight/DLC",0.0);
     }
 } #end toggleDLC

toggleGroundSpoilers = func 
{
 if (getprop ("/controls/flight/ground-spoilers-armed"))
  setprop ("/controls/flight/ground-spoilers-armed", false);
 else
  setprop ("/controls/flight/ground-spoilers-armed", true);
} # end toggleGroundSpoilers

computeSpoilers = func 
 {
  
  #local variables --
  rollCommand = - getprop ("/controls/flight/aileron");
  DLC = 0.0;
  groundSpoilersArmed = getprop ("/controls/flight/ground-spoilers-armed");
  

  # body of the function --

  # Compute a bias to reduce spoilers extension from full extension at sweep = 20deg
  # to no extension past 56 deg

  if (WingSweep > 0.8) wingSweepBias = 0.0;
  else wingSweepBias = 1.0 - (WingSweep * 1.25); 

  #Ground spoiler activation  


  if ((groundSpoilersArmed and !WOW)
	  or
      (WOW and !GroundSpoilersLatchedClosed and groundSpoilersArmed))

   {
    GroundSpoilersLatchedClosed = false;
   }
   else
   {
    GroundSpoilersLatchedClosed = true;
   }  
  
  if (groundSpoilersArmed 
      and 
      ! GroundSpoilersLatchedClosed 
      and 
      Throttle < ThrottleIdle)
   { 
    
     #if weight on wheels or ground spoilers deployed (in case of hard bounce)
       if (GroundSpoilersDeployed or WOW) 
       {
        GroundSpoilersDeployed = true;
        LeftSpoilersTarget = 1.0 * wingSweepBias;
        RightSpoilersTarget = 1.0 * wingSweepBias;
        InnerLeftSpoilersTarget = 1.0 * wingSweepBias; 
        InnerRightSpoilersTarget = 1.0 * wingSweepBias;
        setprop ("/controls/flight/yasim-spoilers", 1.0 * wingSweepBias);
        return;
       } # end if weight on wheels or ground spoilers deployed

    } #end if ground spoilers armed

  # If we have come this far, the ground spoilers are not armed 
  # and consquently should not be deployed. Let's make sure this is the case

  GroundSpoilersDeployed = false;

  # Compute the contribution of Direct Lift Control on spoiler extension
  # If wings are swept back, or the aircraft is on the ground, Direct Lift
  # Control is deactivated

  if (WingSweep > 0.05) DLC = 0.0; # add a condition on weight on wheels
  else DLC = getprop("/controls/flight/DLC"); 

  #spoilers are depressed -4 degrees when flaps are out
  if (getprop ("/controls/flight/flapscommand") != nil)
  {
   if(getprop ("/controls/flight/flapscommand") == FlapsToLdg)
    SpoilersMinima = -0.073;
   else
    SpoilersMinima = 0.0;
   }

  LeftSpoilersTarget = rollCommand * wingSweepBias * MaxFlightSpoilers + SpoilersMinima;
  RightSpoilersTarget = (-rollCommand) * wingSweepBias * MaxFlightSpoilers + SpoilersMinima;

  if (DLCactive)
   {
    InnerLeftSpoilersTarget = (DLC + rollCommand) * wingSweepBias * MaxFlightSpoilers + SpoilersMinima;
    InnerRightSpoilersTarget = (DLC - rollCommand) * wingSweepBias * MaxFlightSpoilers + SpoilersMinima;
   }
  else 
   {
    InnerLeftSpoilersTarget = LeftSpoilersTarget;
    InnerRightSpoilersTarget = RightSpoilersTarget;
   }

  # clip the values to in-flight maxima
  if (LeftSpoilersTarget < SpoilersMinima) LeftSpoilersTarget = SpoilersMinima;
  if (RightSpoilersTarget < SpoilersMinima) RightSpoilersTarget = SpoilersMinima;
  if (LeftSpoilersTarget > MaxFlightSpoilers) LeftSpoilersTarget = MaxFlightSpoilers;
  if (RightSpoilersTarget > MaxFlightSpoilers) RightSpoilersTarget = MaxFlightSpoilers;
  if (InnerLeftSpoilersTarget < SpoilersMinima) InnerLeftSpoilersTarget = SpoilersMinima;
  if (InnerRightSpoilersTarget < SpoilersMinima) InnerRightSpoilersTarget = SpoilersMinima;
  if (InnerLeftSpoilersTarget > MaxFlightSpoilers) InnerLeftSpoilersTarget = MaxFlightSpoilers;
  if (InnerRightSpoilersTarget > MaxFlightSpoilers) InnerRightSpoilersTarget = MaxFlightSpoilers;

  setprop ("/controls/flight/yasim-spoilers", (InnerRightSpoilersTarget + InnerLeftSpoilersTarget) / 2.0);

 } #end compute spoilers

