# This is a replacement for fuel.nas for the particlar fuel 
# system of the Grumman F-14b.


fuel.update = func{}; # disable the generic fuel updater

# Initialize internal values
# --------------------------
var PPG = nil;
var LBS_HOUR2GALS_SEC    = nil;
var LBS_HOUR2GALS_PERIOD = nil;
var max_flow18000        = nil;
var max_flow36000        = nil;
var max_flow45000        = nil;
var max_flow85000        = nil;
var max_refuel_flow      = nil;

var ai_enabled = nil;
var refuelingN = nil;
var refuel_serviceable = nil;
var aimodelsN = nil;
var types = {};
var qty_refuelled_gals = nil;

var FWD_Fuselage       = nil;
var AFT_Fuselage       = nil;
var Left_Beam_Box      = nil;
var Left_Sump          = nil;
var Right_Beam_Box     = nil;
var Right_Sump         = nil;
var Left_Wing          = nil;
var Right_Wing         = nil;
var Left_External      = nil;
var Right_External     = nil;
var Left_Proportioner  = nil;
var Right_Proportioner = nil;
neg_g = nil;

var L_Ext_Select_State = nil;
var R_Ext_Select_State = nil;
var l_ext_select_state = nil;
var r_ext_select_state = nil;

var total_gals = 0;
var total_lbs  = 0;
var qty_sel_switch = nil;
var g_fuel_total   = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/total", 1);
var g_fuel_WL      = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/left-wing-display", 1);
var g_fuel_WR      = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/right-wing-display", 1);
var g_fus_feed_L   = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/left-fus-feed-display", 1);
var g_fus_feed_R   = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/right-fus-feed-display", 1);
var Qty_Sel_Switch = props.globals.getNode("sim/model/f-14b/controls/fuel/qty-sel-switch");
var fwd = nil;
var aft = nil;
var Lg  = nil;
var Rg  = nil;
var Lw  = nil;
var Rw  = nil;
var Le  = nil;
var Re  = nil;

var time = 0;
var dt = 0;
var last_time = 0.0;

var total = 0;
var dump_valve = 0;
var dumprate_lbs_hr = 90000; #1500 ppm
var refuel_rate_gpm = 450; # max rate in gallons per minute at 50 psi pressure


var left_shut_off = 0; # TODO: Engine fuel shutoff emergency handles
var right_shut_off = 0;

var LeftEngine		= props.globals.getNode("engines").getChild("engine", 0);
var RightEngine	    = props.globals.getNode("engines").getChild("engine", 1);
var LeftFuel		= LeftEngine.getNode("fuel-consumed-lbs", 1);
var RightFuel		= RightEngine.getNode("fuel-consumed-lbs", 1);
var left_fuel_consumed  = 0;
var right_fuel_consumed = 0;
LeftEngine.getNode("out-of-fuel", 1);
RightEngine.getNode("out-of-fuel", 1);

var DumpValve         = props.globals.getNode("sim/model/f-14b/controls/fuel/dump-valve", 1);
var RefuelProbeSwitch = props.globals.getNode("sim/model/f-14b/controls/fuel/refuel-probe-switch");
var TotalFuelLbs  = props.globals.getNode("consumables/fuel/total-fuel-lbs", 1);
var TotalFuelGals = props.globals.getNode("consumables/fuel/total-fuel-gals", 1);

var max_refuel_flow           = 0;
var remaining_max_flow        = 0;
var amount_to_left_bb         = 0;
var amount_to_left_aft        = 0;
var amount_to_left_external   = 0;
var amount_to_left_wing       = 0;
var amount_to_right_bb        = 0;
var amount_to_right_fwd       = 0;
var amount_to_right_external  = 0;
var amount_to_right_wing      = 0;
var amount_left_sump          = 0;
var amount_right_sump         = 0;
var amount_left_beam_box      = 0;
var amount_right_beam_box     = 0;
var amount_left_external_bb   = 0;
var amount_left_external_aft  = 0;
var amount_right_external_bb  = 0;
var amount_right_external_fwd = 0;
var amount_left_wing_bb       = 0;
var amount_left_wing_aft      = 0;
var amount_right_wing_bb      = 0;
var amount_right_wing_fwd     = 0;
var amount_aft_fuselage       = 0;
var aft_fuselage_prop         = 0;
var amount_fwd_fuselage       = 0;


var init_fuel_system = func {

	print("Initializing F-14B fuel system");

	L_Ext_Select_State = props.globals.getNode("consumables/fuel/tank[8]/selected");
	R_Ext_Select_State = props.globals.getNode("consumables/fuel/tank[9]/selected");
	l_ext_select_state = L_Ext_Select_State.getValue();
	r_ext_select_state = R_Ext_Select_State.getValue();

	#tanks ("name", number, initial connection status)
	FWD_Fuselage   = Tank.new("FWD fuselage", 0, 1);   # 4700 lbs
	AFT_Fuselage   = Tank.new("AFT fuselage", 1, 1);   # 4400 lbs
	Left_Beam_Box  = Tank.new("L beam box", 2, 1);  # 1250 lbs
	Left_Sump      = Tank.new("L sump", 3, 1);      #  300 lbs
	Right_Beam_Box = Tank.new("R beam box", 4, 1); # 1250 lbs
	Right_Sump     = Tank.new("R sump", 5, 1);     #  300 lbs
	Left_Wing      = Tank.new("L wing", 6, 1);      # 2000 lbs
	Right_Wing     = Tank.new("R wing", 7, 1);     # 2000 lbs
	Left_External  = Tank.new("L external", 8, l_ext_select_state);  # 2000 lbs
	Right_External = Tank.new("R external", 9, r_ext_select_state); # 2000 lbs

	#proportioners ("name", number, initial connection status, operational status)
	Left_Proportioner	= Prop.new("L feed line", 10, 1, 1); # 10 lbs
	Right_Proportioner	= Prop.new("R feed line", 11, 1, 1); # 10 lbs

	#valves ("name",property, intitial status)
	DumpValve = Valve.new("dump_valve","sim/model/f-14b/controls/fuel/dump-valve",0);

	neg_g = Neg_g.new(0);

	setlistener("sim/ai/enabled", func(n) { ai_enabled = n.getBoolValue() }, 1);
	refuelingN = props.globals.initNode("/systems/refuel/contact", 0, "BOOL");
	aimodelsN = props.globals.getNode("ai/models", 1);
	foreach (var t; props.globals.getNode("systems/refuel", 1).getChildren("type"))
		types[t.getValue()] = 1;
	setlistener("systems/refuel/serviceable", func(n) refuel_serviceable = n.getBoolValue(), 1);

	PPG = FWD_Fuselage.ppg.getValue();
	LBS_HOUR2GALS_SEC = (1 / PPG) / 3600;

}




var fuel_update = func {

	if ( getprop("/sim/freeze/fuel") ) { return }

	time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
	dt = time - last_time;
	last_time = time;
	neg_g.update();
	calc_levels();

	LBS_HOUR2GALS_PERIOD = LBS_HOUR2GALS_SEC * dt;
	max_flow85000 = 85000 * LBS_HOUR2GALS_PERIOD; 
	max_flow45000 = 45000 * LBS_HOUR2GALS_PERIOD;
	max_flow36000 = 36000 * LBS_HOUR2GALS_PERIOD;
	max_flow18000 = 18000 * LBS_HOUR2GALS_PERIOD; 
	refuel_rate_gpm = 450; # max rate in gallons per minute at 50 psi pressure

	l_ext_select_state = L_Ext_Select_State.getValue();
	r_ext_select_state = R_Ext_Select_State.getValue();


	# Fuel Jettison
	dump_valve = Valve.get("dump_valve");
	if ( dump_valve and ( TotalFuelLbs.getValue() < 4000 ) ) { fuel_dump_off() }
	if ( dump_valve ) {
		Left_Proportioner.jettisonFuel(dt);
		Right_Proportioner.jettisonFuel(dt);
	} else {
		Left_Proportioner.set_dumprate(0);
		Right_Proportioner.set_dumprate(0);
	}


	if ( RefuelProbeSwitch.getValue() > 0 ) {
		# Check refueling tanker available and contact
		var tankers = [];
		if (ai_enabled) {
			var ac = aimodelsN.getChildren("tanker");
			var mp = aimodelsN.getChildren("multiplayer");
			foreach (var a; ac ~ mp) {
				if (!a.getNode("tanker", 1).getValue()) continue;
				if (!a.getNode("refuel/contact", 1).getValue()) continue;
				foreach (var t; a.getNode("refuel", 1).getChildren("type")) {
					var type = t.getValue();
					if (contains(types, type) and types[type]) { append(tankers, a) }
				}
			}
		}
		var refueling = refuel_serviceable and size(tankers) > 0;
		refuelingN.setBoolValue(refueling);

		# Refuel
		if (refueling) {
			max_refuel_flow = refuel_rate_gpm / 60 * dt / 2; # each side.
			# Refuel Left Beam Box. max 450 gpm.
			# Overflow to AFT_Fuselage, then External, then, if selected, external and wing.
			left_beam_box_ullage = Left_Beam_Box.get_ullage();
			aft_fuselage_ullage = AFT_Fuselage.get_ullage();
			amount_to_left_bb = 0;
			amount_to_left_aft = 0;
			amount_to_left_external = 0;
			amount_to_left_wing = 0;
			remaining_max_flow = max_refuel_flow;
			if (( left_beam_box_ullage > 0 )) {
				amount_to_left_bb = left_beam_box_ullage;
				if (( amount_to_left_bb) > remaining_max_flow ) { amount_to_left_bb = remaining_max_flow }
				remaining_max_flow -= amount_to_left_bb;			
			}
			if (( aft_fuselage_ullage > 0 ) and ( remaining_max_flow > 0 )) {
				amount_to_left_aft = aft_fuselage_ullage;
				if ( amount_to_left_aft > remaining_max_flow ) { amount_to_left_aft = remaining_max_flow }
				remaining_max_flow -= amount_to_left_aft;			
			}
			if ( RefuelProbeSwitch.getValue() == 2 ) {
				left_external_ullage = Left_External.get_ullage();
				left_wing_ullage = Left_Wing.get_ullage();
				if (( l_ext_select_state ) and ( left_external_ullage > 0 ) and ( remaining_max_flow > 0 )) {
					amount_to_left_external = left_external_ullage;
					if ( amount_to_left_external > remaining_max_flow ) { amount_to_left_external = remaining_max_flow }
					remaining_max_flow -= amount_to_left_external;
				}
				if (( left_wing_ullage > 0 ) and ( remaining_max_flow > 0 )) {
					amount_to_left_wing = left_wing_ullage;
					if ( amount_to_left_wing > remaining_max_flow ) { amount_to_left_wing = remaining_max_flow }
					remaining_max_flow -= amount_to_left_wing;
				}
			}
			Left_Beam_Box.set_level( Left_Beam_Box.get_level()  + amount_to_left_bb );
			AFT_Fuselage.set_level( AFT_Fuselage.get_level()    + amount_to_left_aft );
			Left_External.set_level( Left_External.get_level()  + amount_to_left_external );
			Left_Wing.set_level( Left_Wing.get_level()          + amount_to_left_wing );
			# Refuel Right Beam Box. max 450 gpm.
			# Overflow to FWD_Fuselage, then External, then, if selected, external and wing.
			right_beam_box_ullage = Right_Beam_Box.get_ullage();
			fwd_fuselage_ullage = FWD_Fuselage.get_ullage();
			amount_to_right_bb = 0;
			amount_to_right_fwd = 0;
			amount_to_right_external = 0;
			amount_to_right_wing = 0;
			remaining_max_flow = max_refuel_flow;
			if (( right_beam_box_ullage > 0 )) {
				amount_to_right_bb = right_beam_box_ullage;
				if (( amount_to_right_bb) > remaining_max_flow ) { amount_to_right_bb = remaining_max_flow }
				remaining_max_flow -= amount_to_right_bb;			
			}
			if (( fwd_fuselage_ullage > 0 ) and ( remaining_max_flow > 0 )) {
				amount_to_right_fwd = fwd_fuselage_ullage;
				if ( amount_to_right_fwd > remaining_max_flow ) { amount_to_right_fwd = remaining_max_flow }
				remaining_max_flow -= amount_to_right_fwd;			
			}
			if ( RefuelProbeSwitch.getValue() == 2 ) {
				right_external_ullage = Right_External.get_ullage();
				right_wing_ullage = Right_Wing.get_ullage();
				if (( r_ext_select_state ) and ( right_external_ullage > 0 ) and ( remaining_max_flow > 0 )) {
					amount_to_right_external = right_external_ullage;
					if ( amount_to_right_external > remaining_max_flow ) { amount_to_right_external = remaining_max_flow }
					remaining_max_flow -= amount_to_right_external;
				}
				if (( right_wing_ullage > 0 ) and ( remaining_max_flow > 0 )) {
					amount_to_right_wing = right_wing_ullage;
					if ( amount_to_right_wing > remaining_max_flow ) { amount_to_right_wing = remaining_max_flow }
					remaining_max_flow -= amount_to_right_wing;
				}
			}
			Right_Beam_Box.set_level( Right_Beam_Box.get_level() + amount_to_right_bb );
			FWD_Fuselage.set_level( FWD_Fuselage.get_level()     + amount_to_right_fwd );
			Right_External.set_level( Right_External.get_level() + amount_to_right_external );
			Right_Wing.set_level( Right_Wing.get_level()         + amount_to_right_wing );

		}
	}


	# Transfer from the proportioners to the engines, reset the consumed fuel, Set engines.
	left_fuel_consumed = LeftFuel.getValue();
	right_fuel_consumed = RightFuel.getValue();
	left_outOfFuel = Left_Proportioner.update(left_fuel_consumed);
	right_outOfFuel = Right_Proportioner.update(right_fuel_consumed);
	LeftFuel.setDoubleValue(0);
	RightFuel.setDoubleValue(0);
	if ( left_outOfFuel ) {
		LeftEngine.getNode("out-of-fuel").setBoolValue(1)
	} else { LeftEngine.getNode("out-of-fuel").setBoolValue(0) }
	if ( right_outOfFuel ) {
		RightEngine.getNode("out-of-fuel").setBoolValue(1)
	} else { RightEngine.getNode("out-of-fuel").setBoolValue(0) }


	# Transfer from left sump to left proportioner (left feed line).
	if ( Left_Proportioner.get_ullage() > 0 ) {
		left_sump_level = Left_Sump.get_level();
		amount_left_sump = Left_Proportioner.get_ullage();
		if ( amount_left_sump > left_sump_level ) { amount_left_sump = left_sump_level }
		Left_Sump.set_level( left_sump_level                       - amount_left_sump );
		Left_Proportioner.set_level( Left_Proportioner.get_level() + amount_left_sump );
	}
	# Transfer from left sump to left proportioner (left feed line).
	if ( Right_Proportioner.get_ullage() > 0 ) {
		right_sump_level = Right_Sump.get_level();
		amount_right_sump = Right_Proportioner.get_ullage();
		if ( amount_right_sump > right_sump_level ) { amount_right_sump = right_sump_level }
		Right_Sump.set_level( right_sump_level                     - amount_right_sump );
		Right_Proportioner.set_level(Right_Proportioner.get_level() + amount_right_sump );
	}
	#print( "from sumps: " ~ amount_left_sump ~ amount_right_sump );

	# Transfer from Left Beam Box to left sump.
	if ( Left_Sump.get_ullage() > 0 ) {
		left_beam_box_level = Left_Beam_Box.get_level();
		amount_left_beam_box = Left_Sump.get_ullage();
		if ( amount_left_beam_box > left_beam_box_level ) { amount_left_beam_box = left_beam_box_level }
		Left_Beam_Box.set_level( left_beam_box_level - amount_left_beam_box );
		Left_Sump.set_level( Left_Sump.get_level()   + amount_left_beam_box );
	}
	# Transfer from Right Beam Box to right sump.
	if ( Right_Sump.get_ullage() > 0 ) {
		right_beam_box_level = Right_Beam_Box.get_level();
		amount_right_beam_box = Right_Sump.get_ullage();
		if ( amount_right_beam_box > right_beam_box_level ) { amount_right_beam_box = right_beam_box_level }
		Right_Beam_Box.set_level( right_beam_box_level - amount_right_beam_box);
		Right_Sump.set_level(Right_Sump.get_level()    + amount_right_beam_box);
	}
	#print( "from bboxes: " ~ amount_left_beam_box ~ amount_right_beam_box );




	# Transfer from Left External to Left Beam Box. max 45000 pph at 25 psi regulated bleed air.
	# Overflow to AFT_Fuselage.
	if ( l_ext_select_state ) {
		left_beam_box_ullage = Left_Beam_Box.get_ullage();
		aft_fuselage_ullage  = AFT_Fuselage.get_ullage();
		left_external_level  = Left_External.get_level();
		amount_left_external_bb = 0;
		amount_left_external_aft = 0;
		remaining_max_flow = 0;
		if (( left_beam_box_ullage > 0 )) {
			amount_left_external_bb = left_beam_box_ullage;
			if (( amount_left_external_bb) > max_flow45000) {
				amount_left_external_bb = max_flow45000;
				amount_left_external_aft = 0;
			}
			if ( amount_left_external_bb > left_external_level ) { amount_left_external_bb = left_external_level}
		}
		if ( aft_fuselage_ullage > 0 ) {
			amount_left_external_aft = aft_fuselage_ullage;
			remaining_max_flow = max_flow45000 - amount_left_external_bb;			
			if ( amount_left_external_aft > remaining_max_flow ) { amount_left_external_aft = remaining_max_flow }
			if ( amount_left_external_bb > left_external_level ) { amount_left_external_bb = left_external_level }
			if (( amount_left_external_bb + amount_left_external_aft ) > left_external_level ) {
				amount_left_external_aft = left_external_level - amount_left_external_bb;
			}
		}
		Left_External.set_level( left_external_level   - ( amount_left_external_bb + amount_left_external_aft ));
		Left_Beam_Box.set_level( Left_Beam_Box.get_level()  + amount_left_external_bb );
		AFT_Fuselage.set_level( AFT_Fuselage.get_level()    + amount_left_external_aft );
	}

	# Transfer from Right External to Right Beam Box. max 45000 pph at 25 psi regulated bleed air.
	# Overflow to FWD_Fuselage.
	if ( r_ext_select_state ) {
		right_beam_box_ullage = Right_Beam_Box.get_ullage();
		fwd_fuselage_ullage   = FWD_Fuselage.get_ullage();
		right_external_level  = Right_External.get_level();
		amount_right_external_bb = 0;
		amount_right_external_fwd = 0;
		remaining_max_flow = 0;
		if (( right_beam_box_ullage > 0 )) {
			amount_right_external_bb = right_beam_box_ullage;
			if ( amount_right_external_bb > max_flow45000 ) {
				amount_right_external_bb = max_flow45000;
				amount_right_external_fwd = 0;
			}
			if ( amount_right_external_bb > right_external_level ) { amount_right_external_bb = right_external_level }
		}
		if ( fwd_fuselage_ullage > 0 ) {
			amount_right_external_fwd = fwd_fuselage_ullage;
			remaining_max_flow = max_flow45000 - amount_right_external_bb;			
			if ( amount_right_external_fwd > remaining_max_flow ) { amount_right_external_fwd = remaining_max_flow }
			if ( amount_right_external_bb > right_external_level ) { amount_right_external_bb = right_external_level }
			if (( amount_right_external_bb + amount_right_external_fwd ) > right_external_level ) {
				amount_right_external_fwd = right_external_level - amount_right_external_bb;
			}
		}
		Right_External.set_level( right_external_level   - ( amount_right_external_bb + amount_right_external_fwd ));
		Right_Beam_Box.set_level( Right_Beam_Box.get_level()  + amount_right_external_bb );
		FWD_Fuselage.set_level( FWD_Fuselage.get_level()      + amount_right_external_fwd );
	}
	


	# Transfer from Left Wing to Left Beam Box. max 18000 pph (2 motive flow transfer pumps).
	# Overflow to AFT_Fuselage.
	left_beam_box_ullage = Left_Beam_Box.get_ullage();
	aft_fuselage_ullage  = AFT_Fuselage.get_ullage();
	left_wing_level      = Left_Wing.get_level();
	amount_left_wing_bb = 0;
	amount_left_wing_aft = 0;
	remaining_max_flow = 0;
	if ( left_beam_box_ullage > 0 ) {
		amount_left_wing_bb = left_beam_box_ullage;
		if (( amount_left_wing_bb) > max_flow18000) {
			amount_left_wing_bb = max_flow18000;
			amount_left_wing_aft = 0;
		}
		if ( amount_left_wing_bb > left_wing_level ) { amount_left_wing_bb = left_wing_level }
	}
	if ( aft_fuselage_ullage > 0 ) {
		amount_left_wing_aft = aft_fuselage_ullage;
		remaining_max_flow = max_flow18000 - amount_left_wing_bb;			
		if ( amount_left_wing_aft > remaining_max_flow ) { amount_left_wing_aft = remaining_max_flow }
		if ( amount_left_wing_bb > left_wing_level ) { amount_left_wing_bb = left_wing_level }
		if (( amount_left_wing_bb + amount_left_wing_aft ) > left_wing_level ) {
			amount_left_wing_aft = left_wing_level - amount_left_wing_bb;
		}
	}
	Left_Wing.set_level( left_wing_level                - ( amount_left_wing_bb + amount_left_wing_aft ));
	Left_Beam_Box.set_level( Left_Beam_Box.get_level()  + amount_left_wing_bb );
	AFT_Fuselage.set_level( AFT_Fuselage.get_level()    + amount_left_wing_aft );

	# Transfer from Right Wing to Right Beam Box. max 18000 pph (2 motive flow transfer pumps).
	# Overflow to FWD_Fuselage.
	right_beam_box_ullage = Right_Beam_Box.get_ullage();
	fwd_fuselage_ullage   = FWD_Fuselage.get_ullage();
	right_wing_level      = Right_Wing.get_level();
	amount_right_wing_bb = 0;
	amount_right_wing_fwd = 0;
	remaining_max_flow = 0;
	if ( right_beam_box_ullage > 0 ) {
		amount_right_wing_bb = right_beam_box_ullage;
		if (( amount_right_wing_bb) > max_flow18000) {
			amount_right_wing_bb = max_flow18000;
			amount_right_wing_fwd = 0;
		}
		if ( amount_right_wing_bb > right_wing_level ) { amount_right_wing_bb = right_wing_level }
	}
	if ( fwd_fuselage_ullage > 0 ) {
		amount_right_wing_fwd = fwd_fuselage_ullage;
		remaining_max_flow = max_flow18000 - amount_right_wing_bb;			
		if ( amount_right_wing_fwd > remaining_max_flow ) { amount_right_wing_fwd = remaining_max_flow }
		if ( amount_right_wing_bb > right_wing_level ) { amount_right_wing_bb = right_wing_level }
		if (( amount_right_wing_bb + amount_right_wing_fwd ) > right_wing_level ) {
			amount_right_wing_fwd = right_wing_level - amount_right_wing_bb;
		}
	}
	Right_Wing.set_level(right_wing_level                  - ( amount_right_wing_bb + amount_right_wing_fwd ));
	Right_Beam_Box.set_level( Right_Beam_Box.get_level()   + amount_right_wing_bb );
	FWD_Fuselage.set_level( FWD_Fuselage.get_level()       + amount_right_wing_fwd );



	left_beam_box_ullage  = Left_Beam_Box.get_ullage();
	left_beam_box_level   = Left_Beam_Box.get_level();
	aft_fuselage_level    = AFT_Fuselage.get_level();
	if ( ! neg_g.get_neg_g() ) {
		# transfer from AFT fuselage to Left Beam Box. max 36000 pph (4 motive flow transfer pumps).
		if ( left_beam_box_ullage > 0 ) {
			amount_aft_fuselage = left_beam_box_ullage;
			if ( amount_aft_fuselage > max_flow36000 ) { amount_aft_fuselage = max_flow36000 }
			if ( amount_aft_fuselage > aft_fuselage_level ) { amount_aft_fuselage = aft_fuselage_level }
			AFT_Fuselage.set_level( aft_fuselage_level    - amount_aft_fuselage );
			Left_Beam_Box.set_level( left_beam_box_level  + amount_aft_fuselage );
		}
	} else {
		# transfer from AFT fuselage to Left Beam Box. 18000 to 0 pph depending of AFT fuselage filling.
		if ( left_beam_box_ullage > 0 ) {
			aft_fuselage_prop = (  aft_fuselage_level / AFT_Fuselage.get_capacity() );
			amount_aft_fuselage = left_beam_box_ullage;
			if ( amount_aft_fuselage > max_flow18000 ) { amount_aft_fuselage = max_flow18000 }
			amount_aft_fuselage = amount_aft_fuselage * aft_fuselage_prop * aft_fuselage_prop;
			if ( amount_aft_fuselage > aft_fuselage_level ) { amount_aft_fuselage = aft_fuselage_level }
			AFT_Fuselage.set_level( aft_fuselage_level    - amount_aft_fuselage );
			Left_Beam_Box.set_level( left_beam_box_level  + amount_aft_fuselage );
		}
	}
	
	# transfer from FWD fuselage to Right Beam Box. max 18000 pph (2 motive flow transfer pumps).
	right_beam_box_ullage = Right_Beam_Box.get_ullage();
	right_beam_box_level  = Right_Beam_Box.get_level();
	fwd_fuselage_level    = FWD_Fuselage.get_level();
	if ( right_beam_box_ullage > 0 ) {
		amount_fwd_fuselage = right_beam_box_ullage;
		if ( amount_fwd_fuselage > max_flow18000) { amount_fwd_fuselage = max_flow18000 }
		if ( amount_fwd_fuselage > fwd_fuselage_level ) { amount_fwd_fuselage = fwd_fuselage_level }
		FWD_Fuselage.set_level( fwd_fuselage_level      - amount_fwd_fuselage );
		Right_Beam_Box.set_level( right_beam_box_level  + amount_fwd_fuselage );
	}




	if ( ! neg_g.get_neg_g() ) {
		# transfer from AFT fuselage to Left Sump. max 85000 pph gravity balance (guess).
		left_sump_ullage   = Left_Sump.get_ullage();
		left_sump_level    = Left_Sump.get_level();	
		aft_fuselage_level = AFT_Fuselage.get_level();
		if ( left_sump_ullage > 0 ) {
			Left_Sump_AFT_balance =
				( Left_Sump.get_capacity() / left_sump_level )
				/ ( AFT_Fuselage.get_capacity() / aft_fuselage_level );
			if (( left_sump_ullage > 0 ) and ( Left_Sump_AFT_balance > 1 )) {
				amount_aft_fuselage = left_sump_ullage;
				if ( amount_aft_fuselage > max_flow85000 ) { amount_aft_fuselage = max_flow85000 }
				if ( amount_aft_fuselage > aft_fuselage_level ) { amount_aft_fuselage = aft_fuselage_level }
				AFT_Fuselage.set_level( aft_fuselage_level  - amount_aft_fuselage );
				Left_Sump.set_level( left_sump_level        + amount_aft_fuselage );
			}
		}
		# transfer from FWD fuselage to Right Sump. max 85000 pph gravity balance (guess).
		right_sump_ullage  = Right_Sump.get_ullage();
		right_sump_level   = Right_Sump.get_level();	
		fwd_fuselage_level = FWD_Fuselage.get_level();
		if ( right_sump_ullage > 0 ) {
			Right_Sump_FWD_balance =
				( Right_Sump.get_capacity() / right_sump_level )
				/ ( FWD_Fuselage.get_capacity() / fwd_fuselage_level );
			if (( right_sump_ullage > 0 ) and  ( Right_Sump_FWD_balance > 1 )) {
				amount_fwd_fuselage = right_sump_ullage;
				if ( amount_fwd_fuselage > max_flow85000) { amount_fwd_fuselage = max_flow85000 }
				if ( amount_fwd_fuselage > fwd_fuselage_level ) { amount_fwd_fuselage = fwd_fuselage_level }
				FWD_Fuselage.set_level( fwd_fuselage_level  - amount_fwd_fuselage );
				Right_Sump.set_level( right_sump_level      + amount_fwd_fuselage );
			}
		}
	}
}





var calc_levels = func() {
	# Calculate total fuel in tanks (not including small amount in proportioners) for use
	# in the various gauges displays.
	total_gals = total_lbs = 0;
	foreach (var t; Tank.list) {
		total_gals = total_gals + t.get_level();
		total_lbs = total_lbs + t.get_level_lbs();
	}
	fwd = FWD_Fuselage.get_level_lbs();
	aft = AFT_Fuselage.get_level_lbs();
	Lg  = Left_Beam_Box.get_level_lbs() + Left_Sump.get_level_lbs();
	Rg  = Right_Beam_Box.get_level_lbs() + Right_Sump.get_level_lbs();
	Lw  = Left_Wing.get_level_lbs();
	Rw  = Right_Wing.get_level_lbs();
	Le  = Left_External.get_level_lbs();
	Re  = Right_External.get_level_lbs();
	g_fuel_total.setDoubleValue( total_lbs );
	TotalFuelLbs.setValue(total_lbs);
	g_fus_feed_L.setDoubleValue( Lg + aft );
	g_fus_feed_R.setDoubleValue( Rg + fwd );
	qty_sel_switch = Qty_Sel_Switch.getValue();
	if ( qty_sel_switch < 0 ) {
		g_fuel_WL.setDoubleValue( Le );
		g_fuel_WR.setDoubleValue( Re );
	} elsif ( qty_sel_switch > 0 ) {
		g_fuel_WL.setDoubleValue( Lw );
		g_fuel_WR.setDoubleValue( Rw );
	} else {
		g_fuel_WL.setDoubleValue( Lg );
		g_fuel_WR.setDoubleValue( Rg );
	}

}



# Controls
# --------

var fuel_dump_switch_toggle = func() {
	var sw = getprop("sim/model/f-14b/controls/fuel/dump-switch");
	if ( !sw ) {
		setprop("sim/model/f-14b/controls/fuel/dump-switch", 1);
		if (( !WOW ) and (getprop("surface-positions/speedbrake-pos-norm") == 0 )) {
			fuel_dump_on();
		} else { settimer(func { fuel_dump_off() }, 0.1) } 
	} else { fuel_dump_off() }
} 
var fuel_dump_on = func() {
	Valve.set("dump_valve",1);
	setprop("sim/multiplay/generic/int[0]", 1);
}
var fuel_dump_off = func() {
	setprop("sim/model/f-14b/controls/fuel/dump-switch", 0);
	Valve.set("dump_valve",0);
	setprop("sim/multiplay/generic/int[0]", 0);
}


var refuel_probe_switch_up = func() {
	var sw = getprop("sim/model/f-14b/controls/fuel/refuel-probe-switch");
	if ( sw < 2 ) {
		sw += 1;
		setprop("sim/model/f-14b/controls/fuel/refuel-probe-switch", sw);
	}
	f14.RefuelProbeTargetPosition = 1.0;
}
var refuel_probe_switch_down = func() {
	var sw = getprop("sim/model/f-14b/controls/fuel/refuel-probe-switch");
	if ( sw > 0 ) {
		sw -= 1;
		setprop("sim/model/f-14b/controls/fuel/refuel-probe-switch", sw);
	}
	if ( sw == 0 ) { f14.RefuelProbeTargetPosition = 0.0; }
}


# Specify Classes
# ---------------

# This class defines a tank

Tank = {
	new : func (name, number, connect) {
		var obj = { parents : [Tank]};
		obj.prop = props.globals.getNode("consumables/fuel").getChild ("tank", number , 1);
		obj.name = obj.prop.getNode("name", 1);
		obj.prop.getChild("name", 0, 1).setValue(name);
		obj.capacity = obj.prop.getNode("capacity-gal_us", 1);
		obj.ppg = obj.prop.getNode("density-ppg", 1);
		obj.level_gal_us = obj.prop.getNode("level-gal_us", 1);
		obj.level_lbs = obj.prop.getNode("level-lbs", 1);
		obj.transfering = obj.prop.getNode("transfering", 1);
		obj.prop.getChild("selected", 0, 1).setBoolValue(connect);
		obj.prop.getChild("transfering", 0, 1).setBoolValue(0);
		obj.ppg.setDoubleValue(6.3);

		append(Tank.list, obj);
		return obj;
	},
	get_capacity : func {
		return me.capacity.getValue(); 
	},
	get_level : func {
		return me.level_gal_us.getValue();	
	},	
	get_level_lbs : func {
		return me.level_lbs.getValue();	
	},
	set_level : func (gals_us){
		if(gals_us < 0) gals_us = 0;
		me.level_gal_us.setDoubleValue(gals_us);
		me.level_lbs.setDoubleValue(gals_us * me.ppg.getValue());
	},
	set_transfering : func (transfering){
		me.transfering.setBoolValue(transfering);
	},
	get_amount : func (dt, ullage) {
		var amount = (flowrate_lbs_hr / (me.ppg.getValue() * 60 * 60)) * dt * 1 ;
		if(amount > me.level_gal_us.getValue()) {
			amount = me.level_gal_us.getValue();
		} 
		if(amount > ullage) {
			amount = ullage;
		} 
		var flowrate_lbs = ((amount/dt) * 60 * 60) * me.ppg.getValue();
		return amount
	},
	get_ullage : func () {
		return me.get_capacity() - me.get_level()
	},
	get_name : func () {
		return me.name.getValue();
	},
	set_transfer_tank : func (dt, tank) {
		foreach (var t; Tank.list) {
			if(t.get_name() == tank)  {
				transfer = me.get_amount(dt, t.get_ullage());
				me.set_level(me.get_level() - transfer);
				t.set_level(t.get_level() + transfer);
			} 
		}
	},
	list : [],
};


# This class defines a proportioner
# TODO: explain what is a proportioner
Prop = {
	new : func (name, number, connect, running) {
		var obj = { parents : [Prop]};
		obj.prop = props.globals.getNode("consumables/fuel").getChild ("tank", number , 1);
		obj.name = obj.prop.getNode("name", 1);
		obj.prop.getChild("name", 0, 1).setValue(name);
		obj.capacity = obj.prop.getNode("capacity-gal_us", 1);
		obj.ppg = obj.prop.getNode("density-ppg", 1);
		obj.level_gal_us = obj.prop.getNode("level-gal_us", 1);
		obj.level_lbs = obj.prop.getNode("level-lbs", 1);
		obj.dumprate = obj.prop.getNode("dump-rate-lbs-hr", 1);
		obj.running = obj.prop.getNode("running", 1);
		obj.running.setBoolValue(running);
		obj.prop.getChild("selected", 0, 1).setBoolValue(connect);
		obj.prop.getChild("dump-rate-lbs-hr", 0, 1).setDoubleValue(0);
		obj.ppg.setDoubleValue(6.3);
		append(Prop.list, obj);
		return obj;
	},
	
	set_level : func (gals_us){
		if(gals_us < 0) gals_us = 0;
		me.level_gal_us.setDoubleValue(gals_us);
		me.level_lbs.setDoubleValue(gals_us * me.ppg.getValue());
	},
	set_dumprate : func (dumprate){
		me.dumprate.setDoubleValue(dumprate);
	},
	get_capacity : func {
		return me.capacity.getValue();
	},
	get_level : func {
		return me.level_gal_us.getValue();
	},
	get_running : func {
		return me.running.getValue();
	},
	get_ullage : func () {
		return me.get_capacity() - me.get_level();
	},
	get_name : func () {
		return me.name.getValue();
	},
	get_lbs : func () {
		return me.level_lbs.getValue();
	},
	update : func (amount_lbs) {
		var ppg = me.ppg.getValue();
		var level = me.get_lbs();
		if (level == 0) {
			return 1;
		} else {
			me.prop.getChild("selected").setBoolValue(1);
			me.running.setBoolValue(1);
			level = level - amount_lbs ;
			if(level <= 0) level = 0;
			me.set_level(level/ppg);
			return 0;
		}
	},
	get_amount : func (dt, ullage) {
		var amount = (dumprate_lbs_hr / (me.ppg.getValue() * 60 * 60)) * dt * 1 ;
		if(amount > me.level_gal_us.getValue()) {
			amount = me.level_gal_us.getValue();
		}
		if(amount > ullage) {
			amount = ullage;
		}
		var dumprate_lbs = ((amount/dt) * 60 * 60) * me.ppg.getValue();
		return amount
	},
	set_transfer_tank : func (dt, tank) {
		foreach (var r; Recup.list) {
			if(r.get_name() == tank and me.get_running()) {
				transfer = me.get_amount(dt, r.get_ullage());
				me.set_level(me.get_level() - transfer);
				r.set_level(r.get_level() + transfer);
			}
		}
	},
	jettisonFuel : func (dt) {
		var amount = 0;
		if(me.get_level() > 0 and me.get_running()) {
			amount = (dumprate_lbs_hr / (me.ppg.getValue() * 60 * 60)) * dt * 1 ;
			if(amount > me.level_gal_us.getValue()) {
				amount = me.level_gal_us.getValue();
			}
		}
		var dumprate_lbs = ((amount/dt) * 60) * me.ppg.getValue();
		me.set_dumprate(dumprate_lbs);
		me.set_level(me.get_level() - amount);
	},
	list : [],
};




# this class specifies the negative g switch

Neg_g = {
	new : func(switch) {
		var obj = { parents : [Neg_g]};
		obj.prop = props.globals.getNode("controls/fuel/neg-g",1);
		obj.switch = switch;
		obj.prop.setBoolValue(switch);
		obj.acceleration = props.globals.getNode("accelerations/pilot-g", 1);
		obj.check = props.globals.getNode("controls/fuel/recuperator-check", 1);
		return obj;
	},
	update : func() {
		var acc = me.acceleration.getValue();
		var check = me.check.getValue();
		if (acc < 0 or check ) {
			me.prop.setBoolValue(1);
		} else {
			me.prop.setBoolValue(0);
		}
	},
	get_neg_g : func() {
		return me.prop.getValue();
	},
};	


# this class specifies fuel valves

Valve = {
	new : func (name,
				prop,
				initial_pos
				){
		var obj = {parents : [Valve] };
		obj.prop = props.globals.getNode(prop, 1);
		obj.name = name;
		obj.prop.setBoolValue(initial_pos);
		append(Valve.list, obj);
		return obj;
	},
	set : func (valve, pos) {
		foreach (var v; Valve.list) {
			if(v.get_name() == valve) {
				print("valve ",v.get_name()," ", pos);
				v.prop.setValue(pos);
			}
		}
	},
	get : func (valve) {
		var pos = 0;
		foreach (var v; Valve.list) {
			if(v.get_name() == valve) {
				pos = v.prop.getValue();
			}
		}
		return pos;
	},
	get_name : func () {
		return me.name;
	},
	list : [],
};
	

	
