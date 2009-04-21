#----------------------------------------------------------------------------
# Stability Augmentation System
#----------------------------------------------------------------------------

# Constants
var D2R = math.pi / 180;


var PitchLoSpeed     = 230.0;
var RollLoSpeed      = 400.0;
var PreviousHeading  = 0.0;
var PreviousSlip     = 0.0;

# Pid constants
var PitchVarTarget   =  0.0;
var PitchKp          = -0.05;
var PitchKi          =  0.0;
var PitchKd          =  0.0;

var RollVarTarget    =  0.0;
var RollKp           =  0.005;
var RollKi           =  0.0;
var RollKd           =  0.0;

var YawVarTarget     =  0.0;
var YawKp            =  0.01;
var YawKi            =  0.0;
var YawKd            =  0.0;

var PreviousPitchBias  = 0.0;
var PreviousRollBias   = 0.0;
var PreviousYawBias    = 0.0;

# Derivative
var PitchPIDpreviousError = 0.0;
var PitchPIDppError       = 0.0;
var RollPIDpreviousError  = 0.0;
var RollPIDppError        = 0.0;
var YawPIDpreviousError   = 0.0;
var YawPIDppError         = 0.0;

# Limiters
var PitchMaxOutput   =  0.2;
var PitchMinOutput   = -0.2;
var MaxPitchElevator =  1.0;
var MinPitchElevator =  0.5;
var RollMaxOutput    =  0.01;
var RollMinOutput    = -0.01;
var YawMaxOutput     =  0.3;
var YawMinOutput     = -0.3;

# SAS and Autopilot Controls
var SASpitch_on = props.globals.getNode("sim/model/f-14b/controls/SAS/pitch");
var SASroll_on  = props.globals.getNode("sim/model/f-14b/controls/SAS/roll");
var SASyaw_on   = props.globals.getNode("sim/model/f-14b/controls/SAS/yaw");
var steering    = 0.0;
# Autopilot Locks
var ap_alt_lock  = props.globals.getNode("autopilot/locks/altitude");
var ap_hdg_lock  = props.globals.getNode("autopilot/locks/heading");

# Raw input smoothing filter
var raw_elev           = props.globals.getNode("controls/flight/elevator");
var raw_aileron        = props.globals.getNode("controls/flight/aileron");
var smooth_elev_node   = props.globals.getNode("sim/model/f-14b/controls/flight/sas-elevator", 1);
var last_elev          = 0;
var elev_smooth_factor = 0.1;


# Elevator Trim
# -------------
var MaxTrimRate   = 0.015;
var TrimIncrement = 0.0075;
var CurrentTrim   = 0.0;

var trimUp = func {
	CurrentTrim += TrimIncrement;
	if (CurrentTrim > 1.0) CurrentTrim = 1.0;
	setprop ("controls/flight/elevator-trim", CurrentTrim);
}

trimDown = func {
	CurrentTrim -= TrimIncrement;
	if (CurrentTrim < -1.0) CurrentTrim = -1.0;
	setprop ("controls/flight/elevator-trim", CurrentTrim);
}



# Stability Augmentation System
# -----------------------------
var dt_mva_vec = [0,0,0,0,0,0,0];

var computeSAS = func {
	var airspeed = getprop ("velocities/airspeed-kt");
	squaredAirspeed = airspeed * airspeed;

	raw_e = raw_elev.getValue();
	raw_a = raw_aileron.getValue();
	steering = ((raw_e > 0.05 or -0.05 > raw_e) or (raw_a > 0.01 or -0.01 > raw_a)) ? 1 : 0;

	mvaf_dT = (dt_mva_vec[0]+dt_mva_vec[1]+dt_mva_vec[2]+dt_mva_vec[3]+dt_mva_vec[4]+dt_mva_vec[5]+dt_mva_vec[6])/7;
	pop(dt_mva_vec);
	dt_mva_vec = [deltaT] ~ dt_mva_vec;

	# Temporarly disengage Autopilot when control stick steering or when 7 frames average fps < 10.
	# Simple mode, Attitude: pitch and roll.
	# f14_afcs.ap_lock_att:
	# 0 = attitude not engaged (no autopilot at all).
	# 1 = attitude engaged and running.
	# 2 = attitude engaged and temporary disabled.
	# 3 = attitude engaged and temporary disabled with altitude selected.
	if ( f14_afcs.ap_lock_att > 0 ) {
		if ( f14_afcs.ap_lock_att == 1 and ( steering or mvaf_dT >= 0.1 )) {
			if (f14_afcs.ap_alt_lock.getValue() == "altitude-hold") {
				f14_afcs.ap_lock_att = 3;
			} else {
				f14_afcs.ap_lock_att = 2;
			}
			ap_alt_lock.setValue("");
			ap_hdg_lock.setValue("");
		} elsif ( f14_afcs.ap_lock_att > 1 and !steering and mvaf_dT < 0.1 ) {
			if ( f14_afcs.ap_lock_att == 3 ) {
				f14_afcs.alt_enable.setBoolValue(1);
			}
			f14_afcs.ap_lock_att = 1;
			f14_afcs.afcs_attitude_engage();
		}
	}


	# Roll Channel
	# ------------
	# Roll PID computation
	if ( f14_afcs.ap_lock_att != 1 ) {
		RollVarError = RollVarTarget - getprop ("orientation/roll-deg");

		rollBias = PreviousRollBias 
				+ RollKp * (RollVarError - RollPIDpreviousError);
				#+ RollKi * deltaT * RollVarError # unused: RollKi = 0
				#+ RollKd * (RollVarError - 2* RollPIDpreviousError + RollPIDppError) / deltaT; # unused: RollKd = 0

		RollPIDpreviousError = RollVarError;
		RollPIDppError = RollPIDpreviousError;
		PreviousRollBias = rollBias;

		if (rollBias > RollMaxOutput) rollBias = RollMaxOutput;
		if (rollBias < RollMinOutput) rollBias = RollMinOutput;

		SASroll = (getprop ("controls/flight/aileron") + rollBias + getprop ("controls/flight/aileron-trim")) * ! OverSweep;   
		if (airspeed > RollLoSpeed)
			SASroll = SASroll * ( (RollLoSpeed * RollLoSpeed) / squaredAirspeed );

		setprop ("controls/flight/SAS-roll", SASroll);
	}


	# Pitch Channel
	# -------------
	# Compute pitch rate to feed PID controller
	fakePitchRate = getprop ("orientation/pitch-rate-degps");
	currentHeading = getprop ("orientation/heading-deg");
	roll = getprop("orientation/roll-deg");

	if (currentHeading != nil and PreviousHeading != nil and fakePitchRate !=nil and roll!=nil) {
		headingRate = (currentHeading - PreviousHeading) / deltaT;
		PreviousHeading = currentHeading;
		phiDot = fakePitchRate * math.cos (roll*D2R) + headingRate * math.sin (roll*D2R);
		# phiDot = pitch_rate_degps * cos(roll) + yaw_rate_degps * sin(roll)
	} else {
		phiDot = 0.0;
	}

	if (SASpitch_on.getValue()) {


		# 1) Exponential Filter smoothing the longitudinal input.		
		var filtered_move = (raw_e - last_elev) * elev_smooth_factor;
		smooth_elev = last_elev + filtered_move;
		last_elev = smooth_elev;
		smooth_elev_node.setDoubleValue(smooth_elev);

		if ( deltaT < 0.06 ) {
			# 2) PID Bias Filter based on current attitude change rate.
			var PitchVarError = PitchVarTarget - phiDot; # PitchVarTarget: adjustment variable, normaly set to 0.0
			pitchBias = PreviousPitchBias 
					+ PitchKp * (PitchVarError - PitchPIDpreviousError);
					#+ PitchKi * deltaT * PitchVarError # unused: PitchKi = 0
					#+ PitchKd * (PitchVarError - 2* PitchPIDpreviousError + PitchPIDppError) / deltaT; # unused: PitchKd = 0

			PitchPIDpreviousError = PitchVarError;
			PitchPIDppError = PitchPIDpreviousError;
			PreviousPitchBias = pitchBias;

			if (pitchBias > PitchMaxOutput) pitchBias = PitchMaxOutput;
			if (pitchBias < PitchMinOutput) pitchBias = PitchMinOutput;
		} else {
			pitchBias = 0;
		}
	} else {
		pitchBias = 0;
		smooth_elev = raw_e;
	}
	# Sums 1) and 2).
	pitchInput = smooth_elev + pitchBias;

	# Adapt trim rate to speed.
	if (airspeed < 120.0) { 
		TrimIncrement = MaxTrimRate;
	} else {
		TrimIncrement = MaxTrimRate * 14400 / squaredAirspeed;
	}

	# ITS: Integrated Trim System, computes pitch trim bias due to flaps. 
	currentFlaps =  getprop ("surface-positions/aux-flap-pos-norm");
	if (currentFlaps == nil) currentFlaps = 0.0;
	flapsTrim = 0.20 * currentFlaps;

	# DLC: Direct Lift Control (depends on SAS).
	if (SASpitch_on.getValue()) {
		DLCTrim = 0.08 * getprop ("controls/flight/DLC");	
	} else { 
		DLCTrim = 0.0
	}
	pitchInput -= flapsTrim + DLCTrim;

	# Longitudinal authority limit
	# Mechanicaly "handled".
	if (pitchInput > 0) {
		SASpitch = pitchInput * MinPitchElevator * ! OverSweep;
	} else {
		SASpitch = pitchInput * MaxPitchElevator * ! OverSweep;
	}

	# Quadratic Law
	if (airspeed > PitchLoSpeed)
		SASpitch = SASpitch * ( (PitchLoSpeed * PitchLoSpeed) / squaredAirspeed );

	setprop ("controls/flight/SAS-pitch", SASpitch);



	# Yaw Channel
	# -----------
	# Yaw PID computation
	YawVarError = YawVarTarget - getprop ("orientation/side-slip-deg");
	yawBias = PreviousYawBias 
			+ YawKp * (YawVarError - YawPIDpreviousError)
			+ YawKi * deltaT * YawVarError
			+ YawKd * (YawVarError - 2* YawPIDpreviousError + YawPIDppError) / deltaT;

	YawPIDpreviousError = YawVarError;
	YawPIDppError = YawPIDpreviousError;
	PreviousYawBias = yawBias;

	if (yawBias > YawMaxOutput) yawBias = YawMaxOutput;
	if (yawBias < YawMinOutput) yawBias = YawMinOutput;

	yawInput = getprop ("controls/flight/rudder");
	radalt =  getprop ("position/altitude-agl-ft");

	if (yawInput < 0.1 and yawInput > -0.1 and radalt > 50.0) #agl when on carrier deck ?
		yawInput += yawBias;

	setprop ("controls/flight/SAS-yaw", yawInput);



}
