var UPDATE_PERIOD = 0.1;

# compute the local magnetic deviation #######
var true_hdg_deg  = props.globals.getNode("orientation/heading-deg");
var mag_hdg_deg   = props.globals.getNode("instrumentation/heading-indicator/indicated-heading-deg");
var local_mag_dev = props.globals.getNode("sim/model/f-14b/instrumentation/orientation/local-mag-dev", 1);
var mag_dev = 0;

var local_mag_deviation = func {
	var true_hdg = true_hdg_deg.getValue();
	var mag_hdg = mag_hdg_deg.getValue();
	mag_dev = geo.normdeg( mag_hdg - true_hdg );
	if ( mag_dev > 180 ) { mag_dev -= 360 }
	local_mag_dev.setDoubleValue( mag_dev ); 
}

# get a magnetic tacan bearing ###############
var tacan_true_bearing_deg = props.globals.getNode("instrumentation/tacan/indicated-bearing-true-deg");
var tacan_mag_bearing_deg = props.globals.getNode("sim/model/f-14b/instrumentation/tacan/indicated-mag-bearing-deg", 1);

var tacan_update = func {
	var tcn_true_bearing = tacan_true_bearing_deg.getValue();
	var tcn_mag_bearing = geo.normdeg( tcn_true_bearing + mag_dev );
	tacan_mag_bearing_deg.setDoubleValue( tcn_mag_bearing );
}

# fuel gauges ###############
var bingo      = props.globals.getNode("sim/model/f-14b/controls/fuel/bingo");
var fuel_tolal = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/total", 1);
var fuel_WL    = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/left-wing-display", 1);
var fuel_WR    = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/right-wing-display", 1);
var fus_feed_L = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/left-fus-feed-display", 1);
var fus_feed_R = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/right-fus-feed-display", 1);
var fwd_lvl    = props.globals.getNode("consumables/fuel/tank[0]/level-lbs"); # FWD tank
var aft_lvl    = props.globals.getNode("consumables/fuel/tank[1]/level-lbs"); # AFT tank
var Lfg_lvl    = props.globals.getNode("consumables/fuel/tank[2]/level-lbs"); # left feed group
var Rfg_lvl    = props.globals.getNode("consumables/fuel/tank[3]/level-lbs"); # right feed group
var Lw_lvl     = props.globals.getNode("consumables/fuel/tank[4]/level-lbs"); # left wing tank 2000 lbs
var Rw_lvl     = props.globals.getNode("consumables/fuel/tank[5]/level-lbs"); # right wing tank 2000 lbs

var fuel_gauge = func {
	var fwd = fwd_lvl.getValue();
	var aft = aft_lvl.getValue();
	var Lg = Lfg_lvl.getValue();
	var Rg = Rfg_lvl.getValue();
	var Lw = Lw_lvl.getValue();
	var Rw = Rw_lvl.getValue();
	var total = fwd + aft + Lw + Rw + Lg + Rg;
	fuel_tolal.setDoubleValue( total );
	fuel_WL.setDoubleValue( Lw );
	fuel_WR.setDoubleValue( Rw );
	fus_feed_L.setDoubleValue( Lg + aft );
	fus_feed_R.setDoubleValue( Rg + fwd );
}

# Accelerometer ###########
var g_curr = props.globals.getNode("accelerations/pilot-g");
var g_max  = props.globals.getNode("sim/model/f-14b/instrumentation/g-meter/g-max");
var g_min  = props.globals.getNode("sim/model/f-14b/instrumentation/g-meter/g-min");

var g_min_max = func {
	# records g min and max values
	var curr = g_curr.getValue();
	var max = g_max.getValue();
	var min = g_min.getValue();
	if ( curr >= max ) {
		g_max.setDoubleValue(curr);
	} elsif ( curr <= min ) {
		g_min.setDoubleValue(curr);
	}
}

# VDI ticker ###########
var ticker = props.globals.getNode("sim/model/f-14b/instrumentation/ticker", 1);

inc_ticker = func {
	# used for VDI background continuous translation animation
	var tick = ticker.getValue();
	tick += 1 ;
	ticker.setDoubleValue(tick);
}

# Main loop ###############
var cnt = 0;

var main_loop = func {
	cnt += 1;
	# done each 0.1 sec.
	inc_ticker();
	local_mag_deviation();
	tacan_update();
	f14_hud.update_hud();
	g_min_max();
	if (( cnt == 3 ) or ( cnt == 6 )) {
		# done each 0.3 sec.
		fuel_gauge();
		if ( cnt == 6 ) {
			# done each 0.6 sec.
			setprop("instrumentation/heading-indicator/spin", 1);
			cnt = 0;
		}
	}
	settimer(main_loop, UPDATE_PERIOD);
}


# Init ####################
var init = func {
	print("Initializing F-14B Instruments System");
	ticker.setDoubleValue(0);
	f14_hud.init_hud();
	settimer(main_loop, 0.5);
}

setlistener("/sim/signals/fdm-initialized", init);


# Miscelaneous definitions and tools ############

# warning lights medium speed flasher
# -----------------------------------
aircraft.light.new("sim/model/f-14b/lighting/warn-medium-lights-switch", [0.4, 0.3]);
setprop("sim/model/f-14b/lighting/warn-medium-lights-switch/enabled", 1);

