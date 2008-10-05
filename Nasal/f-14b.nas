# f-14b.nas

#===========================================================================
# Utilities 
#===========================================================================

# strobes ===========================================================

strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("sim/model/lighting/strobe", [0.03, 1.9+rand()/5], strobe_switch);

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
var sweep_generic      = props.globals.getNode("sim/multiplay/generic/float[0]");
var radar_standby      = props.globals.getNode("instrumentation/radar/radar-standby");
#var main_flap_generic  = props.globals.getNode("sim/multiplay/generic/float[1]");
var aux_flap_generic   = props.globals.getNode("sim/multiplay/generic/float[2]");
var slat_generic       = props.globals.getNode("sim/multiplay/generic/float[3]");
var left_elev_generic  = props.globals.getNode("sim/multiplay/generic/float[4]");
var right_elev_generic = props.globals.getNode("sim/multiplay/generic/float[5]");
var refuel_generic     = props.globals.getNode("sim/multiplay/generic/float[6]");
var fuel_dump_generic  = props.globals.getNode("sim/multiplay/generic/int[0]");
# sim/multiplay/generic/int[1] <->     <!-- formation slimmers -->
var radar_standby_generic = props.globals.getNode("sim/multiplay/generic/int[2]");

var toggleAccess = func {
	if (DoorsTargetPosition == 0.0) DoorsTargetPosition = 1.0;
	else DoorsTargetPosition = 0.0;
	}

var toggleProbe = func {
	if (RefuelProbeTargetPosition == 0.0) RefuelProbeTargetPosition = 1.0;
	else RefuelProbeTargetPosition = 0.0;
}


#var switchLivery = func

	#{
	#texture_index = getprop ("f-14/livery-number");
	#if (texture_index == 2) texture_index = 0;
	#else texture_index = texture_index + 1;
	#setprop ("f-14/livery-number", texture_index);
	#}

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
	setprop ("surface-positions/wing-sweep", currentSweep);
	setprop ("controls/flight/wing-sweep", WingSweep);

	# Copy surfaces animations properties so they are transmited via multiplayer.
	sweep_generic.setDoubleValue(currentSweep);
	#main_flap_generic.setDoubleValue(main_flap_output.getValue());
	aux_flap_generic.setDoubleValue(aux_flap_output.getValue());
	slat_generic.setDoubleValue(slat_output.getValue());
	left_elev_generic.setDoubleValue(left_elev_output.getValue());
	right_elev_generic.setDoubleValue(right_elev_output.getValue());
	refuel_generic.setDoubleValue(refuel_output.getValue());
	radar_standby_generic.setIntValue(radar_standby.getValue());

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



var registerBurner = func {settimer (updateBurner, 0.04);}

var Burner = 0;
setprop ("f-14/burner", Burner);

var updateBurner = func {
	Burner +=1;
	if (Burner == 3) Burner = 0;
	setprop ("f-14/burner", Burner); 
	registerBurner ();
}

var startProcess = func {
	settimer (updateFCS, 1.0);
	settimer (updateBurner, 1.0);
	#aircraft.livery.init("Aircraft/f-14b/Models/Liveries", "sim/model/livery/name", "sim/model/livery/index");
}

setlistener("/sim/signals/fdm-initialized", startProcess);
