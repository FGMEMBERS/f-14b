#----------------------------------------------------------------------------
# Flaps computer     
#----------------------------------------------------------------------------

#Constants
FlapsClean = 0;
FlapsToLdg = 1;

ManeuverSlatLoAlphaThreshold = 7.7;
ManeuverSlatHiAlphaThreshold = 10.5;
ManeuverFlapExtension = 0.286;
MaxManeuverSlatExtension = 0.41;
LinearManeuverSlatExtensionCoeff = MaxManeuverSlatExtension
                                   /
                                   (ManeuverSlatHiAlphaThreshold 
                                   -
                                   ManeuverSlatLoAlphaThreshold);

# Functions

lowerFlaps = func 

{
  FlapsCommand = getprop ("/controls/flight/flapscommand");

  #wing sweep interlock
  if (WingSweep > 0.05) return;

  if (FlapsCommand < FlapsToLdg) 
   {
    FlapsCommand += 1;
    setprop ("/controls/flight/flapscommand", FlapsCommand);
   }

} #end lowerFlaps

raiseFlaps = func 

 {
 
   FlapsCommand = getprop ("/controls/flight/flapscommand");
   if (FlapsCommand > FlapsClean) 
    {
      FlapsCommand -=1;
      setprop ("/controls/flight/flapscommand", FlapsCommand);
	  DLCactive = false;
      setprop("/controls/flight/DLC",0.0);
   }
 } #end raiseFlaps


computeFlaps = func 

{
  if (CurrentMach == nil) CurrentMach = 0.0; 
  if (CurrentAlt == nil) CurrentAlt = 0.0;
  if (Alpha == nil) Alpha = 0.0;
  FlapsCommand = getprop ("/controls/flight/flapscommand");

  if (CurrentAlt > 30000.0)
     maneuverSlatsCutoffMach = 0.85;
  else 
     maneuverSlatsCutoffMach = 0.5 +  CurrentAlt * 0.35 / 30000;

  # Lock flaps if sweep is not at 20 degrees
  
  if (FlapsCommand == FlapsClean) 
   {
     setprop ("/controls/flight/auxFlaps", 0.0);
     if (CurrentMach <= maneuverSlatsCutoffMach)
       {
         if (Alpha > ManeuverSlatLoAlphaThreshold 
             and 
             Alpha <= ManeuverSlatHiAlphaThreshold)
          {     
           setprop ("/controls/flight/mainFlaps", ManeuverFlapExtension);
           setprop ("/controls/flight/slats", 
                    (Alpha - ManeuverSlatLoAlphaThreshold) 
                    * LinearManeuverSlatExtensionCoeff);
          } 
         elsif (Alpha > ManeuverSlatHiAlphaThreshold)
          {        
           setprop ("/controls/flight/mainFlaps", ManeuverFlapExtension);
           setprop ("/controls/flight/slats", MaxManeuverSlatExtension);
          }
         else
          {
           setprop ("/controls/flight/mainFlaps", 0.0);
           setprop ("/controls/flight/slats", 0.0);
          }
        }
        else
        {
         setprop ("/controls/flight/mainFlaps", 0.0);
         setprop ("/controls/flight/slats", 0.0);
        }
   }
          
     #do not know how to make a switch...case in Nasal :o(
     
     if (FlapsCommand == FlapsToLdg) 
        {
         setprop ("/controls/flight/mainFlaps", 1.0);
         setprop ("/controls/flight/auxFlaps", 1.0);
         setprop ("/controls/flight/slats", 1.0);
        }        
      
} # end computeFlaps
