#----------------------------------------------------------------------------
# AICS (Air Inlet Control System)
#----------------------------------------------------------------------------

var computeAICS = func {

	if (CurrentMach < 0.5) {
		ramp1 = 0.0;
		ramp3 = 0.0;
		ramp2 = 0.0;
	} elsif (CurrentMach < 1.2) {
		ramp1 = (CurrentMach - 0.5) * 0.3 / 0.7;
		ramp3 = (CurrentMach - 0.5) * 0.2 / 0.7;
		ramp2 = 0.0;
	} elsif (CurrentMach < 2.0) {
		ramp1 = (CurrentMach - 1.2) * 0.7 / 0.8 + 0.3;
		ramp3 = (CurrentMach - 1.2) + 0.2;
		ramp2 = (CurrentMach - 1.2) / 0.8;
	} else {
		ramp1 = 1.0;
		ramp3 = 1.0;
		ramp2 = 1.0;
	}
	setprop ("/engines/AICS/ramp1", ramp1);
	setprop ("/engines/AICS/ramp2", ramp2);
	setprop ("/engines/AICS/ramp3", ramp3);
}

#----------------------------------------------------------------------------
# Nozzle opening
#----------------------------------------------------------------------------

# Constant
NozzleSpeed = 1.0;

var computeNozzles = func {
	engine1Burner = getprop ("engines/engine[0]/afterburner");
	if (engine1Burner == nil) {
		engine1Burner = 0.0;
	}
	engine2Burner = getprop ("engines/engine[1]/afterburner");
	if (engine2Burner == nil) {
		engine2Burner = 0.0;
	}
	if (CurrentMach < 0.45) {
		maxSeaLevelIdlenozzle = 1.0;
	} elsif (CurrentMach >= 0.45 and CurrentMach < 0.8) {
		maxSeaLevelIdlenozzle = 1.0 * (0.8 - CurrentMach) / 0.35;
	} else {
		maxSeaLevelIdlenozzle = 0.0;
	}
	if (Throttle < ThrottleIdle) {
		if (getprop ("gear/gear[0]/position-norm") == 1.0) {
		#gear down
			if (WOW) {
				idleNozzleTarget = 1.0;
			} else {
				idleNozzleTarget = 0.26;
			}
		} else {
		# gear not down
			if (CurrentAlt <= 30000.0) {
				idleNozzleTarget = 1.0 + (0.15 - maxSeaLevelIdlenozzle) * CurrentAlt / 30000.0;
			} else {
				idleNozzleTarget = 0.15;
			}
			Nozzle1Target = idleNozzleTarget;
			Nozzle2Target = idleNozzleTarget;
		}
	} else {
	# throttle idle
		Nozzle1Target = engine1Burner;
		Nozzle2Target = engine2Burner;
	}
}

#----------------------------------------------------------------------------
# APC - Approach Power Compensator
#----------------------------------------------------------------------------
# target:        - sim/model/f-14b/instrumentation/aoa-indexer/target-deg (11,3 deg AoA)
# engaged by:    - Throttle Mode Lever
#                - keystroke "a" (toggle)
# disengaged by: - Throttle Mode Lever
#                - keystroke "a" (toggle)
#                - WoW
#                - throttle levers at ~ idle or MIL
#                - autopilot emer disengage padle (TODO)

var APCengaged = props.globals.getNode("sim/model/f-14b/systems/apc/engaged");
var engaded = 0;
var gear_down = props.globals.getNode("controls/gear/gear-down");
var disengaged_light = props.globals.getNode("sim/model/f-14b/systems/apc/self-disengaged-light");
var throttle_0 = props.globals.getNode("controls/engines/engine[0]/throttle");
var throttle_1 = props.globals.getNode("controls/engines/engine[1]/throttle");

var computeAPC = func {
	var t0 = throttle_0.getValue();
	var t1 = throttle_1.getValue();
	if (APCengaged.getBoolValue()) { 
		# TODO override throttles
		if ( WOW or !gear_down.getBoolValue()
		or t0 > 0.76 or t0 < 0.08
		or t1 > 0.76 or t1 < 0.08 ) {
			APC_off()
		}
	} else {
		# TODO duplicate throttles
	}
}

var toggleAPC = func {
	engaged = APCengaged.getBoolValue();
	if ( ! engaged ){
		APC_on();
	} else {
		APC_off();
	}
}

var APC_on = func {
	if ( ! WOW and gear_down.getBoolValue()) {
		APCengaged.setBoolValue(1);
		disengaged_light.setBoolValue(0);
		setprop ("autopilot/locks/aoa", "APC");
		setprop ("autopilot/locks/speed", "APC");
		#print ("APC on()");
	}
}

var APC_off = func {
	setprop ("autopilot/internal/target-speed", 0.0);
	APCengaged.setBoolValue(0);
	disengaged_light.setBoolValue(1);
	settimer(func { disengaged_light.setBoolValue(0); }, 10);	
	setprop ("autopilot/locks/aoa", "");
	setprop ("autopilot/locks/speed", "");
	#print ("APC off()");
}





