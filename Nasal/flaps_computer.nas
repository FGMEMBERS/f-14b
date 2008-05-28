#----------------------------------------------------------------------------
# Flaps computer     
#----------------------------------------------------------------------------

# Constants
var FlapsClean = 0;
var FlapsToLdg = 1;

var ManeuverSlatLoAlphaThreshold = 7.7;
var ManeuverSlatHiAlphaThreshold = 10.5;
var ManeuverFlapExtension = 0.286;
var MaxManeuverSlatExtension = 0.41;
var LinearManeuverSlatExtensionCoeff = MaxManeuverSlatExtension
                                   /
                                   (ManeuverSlatHiAlphaThreshold 
                                   -
                                   ManeuverSlatLoAlphaThreshold);

var wow = props.globals.getNode("gear/gear/wow");

# Functions

# Hijack the generic flaps command so everybody's joystick flap command works
# for the F-14 too. 
controls.flapsDown = func(step) {
	if (step == 1) {
		lowerFlaps();
	} elsif (step == -1) {
		raiseFlaps();
	} else {
		return;
	}
}


var lowerFlaps = func 

{
	FlapsCommand = getprop ("/controls/flight/flapscommand");

	# wing sweep interlock
	if (WingSweep > 0.05) return;

	if (FlapsCommand < FlapsToLdg) 
	{
		FlapsCommand += 1;
		setprop ("/controls/flight/flapscommand", FlapsCommand);
	}

} # end lowerFlaps

var raiseFlaps = func 

{

	FlapsCommand = getprop ("/controls/flight/flapscommand");
	if (FlapsCommand > FlapsClean) 
	{
		FlapsCommand -=1;
		setprop ("/controls/flight/flapscommand", FlapsCommand);
		DLCactive = false;
		setprop("/controls/flight/DLC",0.0);
	}
} # end raiseFlaps


var computeFlaps = func 

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
		if (CurrentMach <= maneuverSlatsCutoffMach and ! wow.getBoolValue())
		{
			if (Alpha > ManeuverSlatLoAlphaThreshold 
				and Alpha <= ManeuverSlatHiAlphaThreshold)
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

	# do not know how to make a switch...case in Nasal :o(

	if (FlapsCommand == FlapsToLdg) 
	{
		setprop ("/controls/flight/mainFlaps", 1.0);
		setprop ("/controls/flight/auxFlaps", 1.0);
		setprop ("/controls/flight/slats", 1.0);
	}


} # end computeFlaps
