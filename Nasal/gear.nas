#----------------------------------------------------------------------------
# Nose Wheel Steering
#----------------------------------------------------------------------------

# Constants
var NWScutoffSpeed = 80.0; #knots

# Functions

var computeNWS = func {

	var NWS_light = 0;
	var NWS = 0.0;

	if ( WOW ) {

		var gs = getprop("velocities/groundspeed-kt");
		if (gs == nil) gs = 0.0;

		var rudderInput = getprop("controls/flight/rudder");

		if ( gs < NWScutoffSpeed ) {
			NWS = rudderInput * (NWScutoffSpeed - gs) / NWScutoffSpeed;
			NWS_light = 1;
		}

	}

setprop("controls/flight/NWS", NWS);
setprop("sim/model/f-14b/instrumentation/gears/nose-wheel-steering-warnlight", NWS_light);

} # end computeNWS
