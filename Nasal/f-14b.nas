# f-14b.nas

#===========================================================================
# Utilities 
#===========================================================================

# Lighting ===========================================================

# Collision lights flasher
var anti_collision_switch = props.globals.getNode("sim/model/f-14b/controls/lighting/anti-collision-switch");
aircraft.light.new("sim/model/f-14b/lighting/anti-collision", [0.09, 1.20], anti_collision_switch);

# Navigation lights steady/flash dimmed/bright
# ------------------------
var position_flash_sw = props.globals.getNode("sim/model/f-14b/controls/lighting/position-flash-switch");
var position = aircraft.light.new("sim/model/f-14b/lighting/position", [0.08, 1.15]);
setprop("/sim/model/f-14b/lighting/position/enabled", 1);
var sw_pos_prop = props.globals.getNode("sim/model/f-14b/controls/lighting/position-wing-switch", 1);
var position_intens = 0;



var position_switch = func(n) {
	var sw_pos = sw_pos_prop.getValue();
	if (n == 1) {
		if (sw_pos == 0) {
			sw_pos_prop.setIntValue(1);
			position.switch(0);
			position_intens = 0;
		} elsif (sw_pos == 1) {
			sw_pos_prop.setIntValue(2);
			position.switch(1);
			position_intens = 6;
		}
	} else {
		if (sw_pos == 2) {
			sw_pos_prop.setIntValue(1);
			position.switch(0);
			position_intens = 0;
		} elsif (sw_pos == 1) {
			sw_pos_prop.setIntValue(0);
			position.switch(1);
			position_intens = 3;
		}
	}	
}
var position_flash_switch = func {
	if (! position_flash_sw.getBoolValue() ) {
		position_flash_sw.setBoolValue(1);
		position.blink();
	} else {
		position_flash_sw.setBoolValue(0);
		position.cont();
	}
}

var position_flash_init  = func {
	if (position_flash_sw.getBoolValue() ) {
		position.blink();
	} else {
		position.cont();
	}
	var sw_pos = sw_pos_prop.getValue();
	if (sw_pos == 0 ) {
		position_intens = 3;
		position.switch(1);
	} elsif (sw_pos == 1 ) {
		position_intens = 0;
		position.switch(0);
	} elsif (sw_pos == 2 ) {
		position_intens = 6;
		position.switch(1);
	}
}
#============================================================================
# Flight control system 
#============================================================================

#----------------------------------------------------------------------------
# timedMotions
#----------------------------------------------------------------------------

var CurrentLeftSpoiler = 0.0;
var CurrentRightSpoiler = 0.0;
var CurrentInnerLeftSpoiler = 0.0;
var CurrentInnerRightSpoiler = 0.0;


var SpoilerSpeed = 1.0; # full extension in 1 second

var DoorsTargetPosition = 0.0;
var DoorsPosition = 0.0;
var DoorsSpeed = 0.2;
setprop ("canopy/position-norm", DoorsPosition);


var RefuelProbeTargetPosition = 0.0;
var RefuelProbePosition = 0.0;
var RefuelProbeSpeed = 0.5;
setprop ("sim/model/f-14b/refuel/probe-position", RefuelProbePosition);

var currentSweep = 0.0;
var SweepSpeed = 0.3;


# Properties used for multiplayer syncronization.
#var main_flap_output   = props.globals.getNode("surface-positions/main-flap-pos-norm", 1);
var aux_flap_output    = props.globals.getNode("surface-positions/aux-flap-pos-norm", 1);
var slat_output        = props.globals.getNode("surface-positions/slats-pos-norm", 1);
var left_elev_output   = props.globals.getNode("surface-positions/left-elevator-pos-norm", 1);
var right_elev_output  = props.globals.getNode("surface-positions/right-elevator-pos-norm", 1);
var refuel_output      = props.globals.getNode("sim/model/f-14b/refuel/probe-position", 1);
var lighting_collision = props.globals.getNode("sim/model/f-14b/lighting/anti-collision/state", 1);
var lighting_position  = props.globals.getNode("sim/model/f-14b/lighting/position/state", 1);
var radar_standby      = props.globals.getNode("instrumentation/radar/radar-standby");
var left_wing_torn     = props.globals.getNode("sim/model/f-14b/wings/left-wing-torn");
var right_wing_torn    = props.globals.getNode("sim/model/f-14b/wings/right-wing-torn");

#var main_flap_generic  = props.globals.getNode("sim/multiplay/generic/float[1]");
var aux_flap_generic   = props.globals.getNode("sim/multiplay/generic/float[2]");
var slat_generic       = props.globals.getNode("sim/multiplay/generic/float[3]");
var left_elev_generic  = props.globals.getNode("sim/multiplay/generic/float[4]");
var right_elev_generic = props.globals.getNode("sim/multiplay/generic/float[5]");
var refuel_generic     = props.globals.getNode("sim/multiplay/generic/float[6]");
var fuel_dump_generic  = props.globals.getNode("sim/multiplay/generic/int[0]");
# sim/multiplay/generic/int[1] used by formation slimmers.
var radar_standby_generic      = props.globals.getNode("sim/multiplay/generic/int[2]");
var lighting_collision_generic = props.globals.getNode("sim/multiplay/generic/int[3]");
var lighting_position_generic  = props.globals.getNode("sim/multiplay/generic/int[4]");
var left_wing_torn_generic     = props.globals.getNode("sim/multiplay/generic/int[5]");
var right_wing_torn_generic    = props.globals.getNode("sim/multiplay/generic/int[6]");
# sim/multiplay/generic/string[0] used by external loads, see ext_stores.nas.

var toggleAccess = func {
	if (DoorsTargetPosition == 0.0) DoorsTargetPosition = 1.0;
	else DoorsTargetPosition = 0.0;
	}

var toggleProbe = func {
	if (RefuelProbeTargetPosition == 0.0) RefuelProbeTargetPosition = 1.0;
	else RefuelProbeTargetPosition = 0.0;
}


var switchHeatBlur = func {
	if (getprop ("f-14/heat-blur-on")) setprop ("f-14/heat-blur-on", false);
	else setprop ("f-14/heat-blur-on", true);
}



var timedMotions = func {

	if (deltaT == nil) deltaT = 0.0;

	# Outboard Spoilers
	if (CurrentLeftSpoiler > LeftSpoilersTarget ) {
		CurrentLeftSpoiler -= SpoilerSpeed * deltaT;
		if (CurrentLeftSpoiler < LeftSpoilersTarget) {
			CurrentLeftSpoiler = LeftSpoilersTarget;
		}
	} elsif (CurrentLeftSpoiler < LeftSpoilersTarget) {
		CurrentLeftSpoiler += SpoilerSpeed * deltaT;
		if (CurrentLeftSpoiler > LeftSpoilersTarget) {
			CurrentLeftSpoiler = LeftSpoilersTarget;
		}
	}

	if (CurrentRightSpoiler > RightSpoilersTarget ) {
		CurrentRightSpoiler -= SpoilerSpeed * deltaT;
		if (CurrentRightSpoiler < RightSpoilersTarget) {
			CurrentRightSpoiler = RightSpoilersTarget;
		}
	} elsif (CurrentRightSpoiler < RightSpoilersTarget) {
		CurrentRightSpoiler += SpoilerSpeed * deltaT;
		if (CurrentRightSpoiler > RightSpoilersTarget) {
			CurrentRightSpoiler = RightSpoilersTarget;
		}
	}

	# Inboard Spoilers
	if (CurrentInnerLeftSpoiler > InnerLeftSpoilersTarget ) {
		CurrentInnerLeftSpoiler -= SpoilerSpeed * deltaT;
		if (CurrentInnerLeftSpoiler < InnerLeftSpoilersTarget) {
			CurrentInnerLeftSpoiler = InnerLeftSpoilersTarget;
		}
	} elsif (CurrentInnerLeftSpoiler < InnerLeftSpoilersTarget) {
		CurrentInnerLeftSpoiler += SpoilerSpeed * deltaT;
		if (CurrentInnerLeftSpoiler > InnerLeftSpoilersTarget) {
			CurrentInnerLeftSpoiler = InnerLeftSpoilersTarget;
		}
	}

	if (CurrentInnerRightSpoiler > InnerRightSpoilersTarget ) {
		CurrentInnerRightSpoiler -= SpoilerSpeed * deltaT;
		if (CurrentInnerRightSpoiler < InnerRightSpoilersTarget) {
			CurrentInnerRightSpoiler = InnerRightSpoilersTarget;
		}
	} elsif (CurrentInnerRightSpoiler < InnerRightSpoilersTarget) {
		CurrentInnerRightSpoiler += SpoilerSpeed * deltaT;
		if (CurrentInnerRightSpoiler > InnerRightSpoilersTarget) {
			CurrentInnerRightSpoiler = InnerRightSpoilersTarget;
		}
	}

	# Refuel Probe
	if (RefuelProbePosition > RefuelProbeTargetPosition) {
		RefuelProbePosition -= RefuelProbeSpeed * deltaT;
		if (RefuelProbePosition < RefuelProbeTargetPosition) {
			RefuelProbePosition = RefuelProbeTargetPosition;
		}
	} elsif (RefuelProbePosition < RefuelProbeTargetPosition) {
		RefuelProbePosition += RefuelProbeSpeed * deltaT;
		if (RefuelProbePosition > RefuelProbeTargetPosition) {
			RefuelProbePosition = RefuelProbeTargetPosition;
		}
	}


    #---------------------------------
    if (DoorsPosition > DoorsTargetPosition)
    {
     DoorsPosition -= DoorsSpeed * deltaT;
     if (DoorsPosition < DoorsTargetPosition) DoorsPosition = DoorsTargetPosition;
    }
    elsif (DoorsPosition < DoorsTargetPosition)
    {
     DoorsPosition += DoorsSpeed * deltaT;
     if (DoorsPosition > DoorsTargetPosition) DoorsPosition = DoorsTargetPosition;
    } #end if (DoorsPosition > DoorsTargetPosition )

    #---------------------------------
    if (Nozzle1 > Nozzle1Target)
    {
     Nozzle1 -= NozzleSpeed * deltaT;
     if (Nozzle1 < Nozzle1Target) Nozzle1 = Nozzle1Target;
    }
    elsif (Nozzle1 < Nozzle1Target)
    {
     Nozzle1 += NozzleSpeed * deltaT;
     if (Nozzle1 > Nozzle1Target) Nozzle1 = Nozzle1Target;
    } #end if (Nozzle1 > Nozzle1Target)

    #---------------------------------
    if (Nozzle2 > Nozzle2Target)
    {
     Nozzle2 -= NozzleSpeed * deltaT;
     if (Nozzle2 < Nozzle2Target) Nozzle2 = Nozzle2Target;
    }
    elsif (Nozzle2 < Nozzle2Target)
    {
     Nozzle2 += NozzleSpeed * deltaT;
     if (Nozzle2 > Nozzle2Target) Nozzle2 = Nozzle2Target;

    } #end if (Nozzle2 > Nozzle2Target)

    #---------------------------------
    if (currentSweep > WingSweep)
    {
     currentSweep -= SweepSpeed * deltaT;
     if (currentSweep < WingSweep) currentSweep = WingSweep;
    }
    elsif (currentSweep < WingSweep)
    {
     currentSweep += SweepSpeed * deltaT;
     if (currentSweep > WingSweep) currentSweep = WingSweep;

    } #end if (Nozzle2 > Nozzle2Target)

	setprop ("surface-positions/left-spoilers", CurrentLeftSpoiler);
	setprop ("surface-positions/right-spoilers", CurrentRightSpoiler);
	setprop ("surface-positions/inner-left-spoilers", CurrentInnerLeftSpoiler);
	setprop ("surface-positions/inner-right-spoilers", CurrentInnerRightSpoiler);
	setprop ("engines/engine[0]/nozzle-pos-norm", Nozzle1);
	setprop ("engines/engine[1]/nozzle-pos-norm", Nozzle2);
	setprop ("canopy/position-norm", DoorsPosition);
	setprop ("sim/model/f-14b/refuel/probe-position", RefuelProbePosition);
	setprop ("surface-positions/wing-pos-norm", currentSweep);
	setprop ("controls/flight/wing-sweep", WingSweep);

	# Copy surfaces animations properties so they are transmited via multiplayer.
	#main_flap_generic.setDoubleValue(main_flap_output.getValue());
	aux_flap_generic.setDoubleValue(aux_flap_output.getValue());
	slat_generic.setDoubleValue(slat_output.getValue());
	left_elev_generic.setDoubleValue(left_elev_output.getValue());
	right_elev_generic.setDoubleValue(right_elev_output.getValue());
	refuel_generic.setDoubleValue(refuel_output.getValue());
	radar_standby_generic.setIntValue(radar_standby.getValue());
	lighting_collision_generic.setIntValue(lighting_collision.getValue());
	lighting_position_generic.setIntValue(lighting_position.getValue() * position_intens);
	left_wing_torn_generic.setIntValue(left_wing_torn.getValue());
	right_wing_torn_generic.setIntValue(right_wing_torn.getValue());
}



#----------------------------------------------------------------------------
# FCS update
#----------------------------------------------------------------------------

var registerFCS = func {settimer (updateFCS, 0);}

var updateFCS = func {
	#Fectch most commonly used values
	CurrentIAS = getprop ("/velocities/airspeed-kt");
	CurrentMach = getprop ("/velocities/mach");
	CurrentAlt = getprop ("/position/altitude-ft");
	WOW = getprop ("/gear/gear[1]/wow") or getprop ("/gear/gear[2]/wow");
	Alpha = getprop ("/orientation/alpha-deg");
	Throttle = getprop ("/controls/engines/engine/throttle");
	ElevatorTrim = getprop ("/controls/flight/elevator-trim");
	deltaT = getprop ("sim/time/delta-sec");

	#update functions
	f14.computeSweep ();
	f14.computeDrag ();
	f14.computeFlaps ();
	f14.computeSpoilers ();
	f14.computeNozzles ();
	f14.computeSAS ();
	f14.computeAdverse ();
	f14.computeNWS ();
	f14.computeAICS ();
	f14.computeAPC ();
	f14.timedMotions ();
	f14.registerFCS ();
}


var startProcess = func {
	settimer (updateFCS, 1.0);
	position_flash_init();
}

setlistener("/sim/signals/fdm-initialized", startProcess);

#----------------------------------------------------------------------------
# View change: Ctrl-V switchback to view #0 but switch to Rio view when already
# in view #0.
#----------------------------------------------------------------------------

var CurrentView_Num = props.globals.getNode("sim/current-view/view-number");
var rio_view_num = view.indexof("RIO View");

var toggle_cockpit_views = func() {
	cur_v = CurrentView_Num.getValue();
	if (cur_v != 0 ) {
		CurrentView_Num.setValue(0);
	} else {
		CurrentView_Num.setValue(rio_view_num);
	}
}






