#----------------------------------------------------------------------------
# Nose Wheel Steering
#----------------------------------------------------------------------------

# Constants
var NWScutoffSpeed = 80.0; #knots


var velocities_groundSpeed = props.globals.getNode("velocities/groundspeed-kt");
var rudder = props.globals.getNode("controls/flight/rudder");
var nw_steering = props.globals.getNode("controls/flight/NWS", 1);
var nw_steering_warnlight = props.globals.getNode(
	"sim/model/f-14b/instrumentation/gears/nose-wheel-steering-warnlight", 1);

# Functions

var computeNWS = func {

	var NWS_light = 0;
	var NWS = 0.0;

	if ( WOW ) {

		var groundSpeed = velocities_groundSpeed.getValue();
		if (groundSpeed == nil) groundSpeed = 0.0;

		var rudderInput = rudder.getValue();

		if ( groundSpeed < NWScutoffSpeed ) {
			NWS = rudderInput * (NWScutoffSpeed - groundSpeed) / NWScutoffSpeed;
			NWS_light = 1;
		}

	}

	nw_steering.setDoubleValue( NWS );
	nw_steering_warnlight.setBoolValue( NWS_light );

} # end computeNWS
