#----------------------------------------------------------------------------
# Nose Wheel Steering
#----------------------------------------------------------------------------

# Constants
var NWScutoffSpeed = 80.0; #knots


var rudder = props.globals.getNode("controls/flight/rudder");
var nw_steering = props.globals.getNode("controls/flight/NWS", 1);
var nw_steering_warnlight = props.globals.getNode(
	"sim/model/f-14b/instrumentation/gears/nose-wheel-steering-warnlight", 1);
var GroundSpeed = props.globals.getNode("velocities/groundspeed-kt");

# Functions

var computeNWS = func {

	var NWS_light = 0;
	var NWS = 0.0;

	if ( WOW ) {

		var gs = GroundSpeed.getValue();
		if (gs == nil) gs = 0.0;

		var rudderInput = rudder.getValue();

		if ( gs < NWScutoffSpeed ) {
			NWS = rudderInput * (NWScutoffSpeed - gs) / NWScutoffSpeed;
			NWS_light = 1;
		}

	}

	nw_steering.setDoubleValue( NWS );
	nw_steering_warnlight.setBoolValue( NWS_light );

} # end computeNWS
