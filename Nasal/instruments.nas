var UPDATE_PERIOD = 0.1;





# TACAN: nav[1]
# ------------- 
var nav1_back = 0;
setlistener( "instrumentation/tacan/switch-position", func {nav1_freq_update();} );

var tc              = props.globals.getNode("instrumentation/tacan/");
var tc_sw_pos       = tc.getNode("switch-position");
var tc_freq         = tc.getNode("frequencies");
var tc_true_hdg     = props.globals.getNode("instrumentation/tacan/indicated-bearing-true-deg");
var tc_mag_hdg      = props.globals.getNode("sim/model/f-14b/instrumentation/tacan/indicated-mag-bearing-deg", 1);
var heading_offset  = props.globals.getNode("instrumentation/heading-indicator-fg/offset-deg");
var tcn_ident       = props.globals.getNode("instrumentation/tacan/ident");
var vtc_ident       = props.globals.getNode("instrumentation/nav[1]/nav-id");
var from_flag       = props.globals.getNode("sim/model/f-14b/instrumentation/hsd/from-flag", 1);
var to_flag         = props.globals.getNode("sim/model/f-14b/instrumentation/hsd/to-flag", 1);
var cdi_deflection  = props.globals.getNode("sim/model/f-14b/instrumentation/hsd/needle-deflection", 1);
var vtc_from_flag   = props.globals.getNode("instrumentation/nav[1]/from-flag");
var vtc_to_flag     = props.globals.getNode("instrumentation/nav[1]/to-flag");
var vtc_deflection  = props.globals.getNode("instrumentation/nav[1]/heading-needle-deflection");
var course_radial   = props.globals.getNode("instrumentation/nav[1]/radials/selected-deg");

# compute the local magnetic deviation #######
var true_hdg_deg  = props.globals.getNode("orientation/heading-deg");
var mag_hdg_deg   = props.globals.getNode("orientation/heading-magnetic-deg");
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

var tacan_update = func {
	var tc_true_bearing = tc_true_hdg.getValue();
	var tc_mag_bearing = geo.normdeg( tc_true_bearing + mag_dev );
	if ( tc_true_bearing != 0 ) {
		tc_mag_hdg.setDoubleValue( tc_mag_bearing );
	} else {
		tc_mag_hdg.setDoubleValue( 0.0 );
	}
}

# set nav[1] so we can use radials from a TACAN station #######
var nav1_freq_update = func {
	if ( tc_sw_pos.getValue() == 1 ) {
		#print("nav1_freq_updat etc_sw_pos = 1");
		var tacan_freq = getprop( "instrumentation/tacan/frequencies/selected-mhz" );
		var nav1_freq = getprop( "instrumentation/nav[1]/frequencies/selected-mhz" );
		var nav1_back = nav1_freq;
		setprop("instrumentation/nav[1]/frequencies/selected-mhz", tacan_freq);
	} else {
	setprop("instrumentation/nav[1]/frequencies/selected-mhz", nav1_back);
	}
}

# Get TACAN radials on HSD's Course Deviation Indicator ########
# CDI works with ils OR tacan OR vortac (which freq is tuned from the tacan panel)
var tacan_dev_indicator = func {
	var tcn = tc_sw_pos.getValue();
	if ( tcn ) {
		var tcnid = tcn_ident.getValue();
		var vtcid = vtc_ident.getValue();
		if ( tcnid == vtcid ) {
			# we have a VORTAC
			from_flag.setBoolValue(vtc_from_flag.getBoolValue());
			to_flag.setBoolValue(vtc_to_flag.getBoolValue());
			cdi_deflection.setValue(vtc_deflection.getValue());
		} else {
			# we have a legacy TACAN
			var tcn_toflag = 1;
			var tcn_fromflag = 0;
			var tcn_bearing = tc_mag_hdg.getValue();
			var radial = course_radial.getValue();
			var delt = tcn_bearing - radial;
			if ( delt > 180 ) {
				delt -= 360;
			} elsif ( delt < -180 ) {
				delt += 360;
			}
			if ( delt > 90 ) {
				delt -= 180;
				tcn_toflag = 0;
				tcn_fromflag = 1;
			} elsif ( delt < - 90 ) {
				delt += 180;
				tcn_toflag = 0;
				tcn_fromflag = 1;
			}
			if ( delt > 10 ) { delt = 10 };
			if ( delt < -10 ) { delt = -10 };
			from_flag.setBoolValue(tcn_fromflag);
			to_flag.setBoolValue(tcn_toflag);
			cdi_deflection.setValue(delt);
		}
	}
}

# TACAN XY Switch
var xy_sign = props.globals.getNode("instrumentation/tacan/frequencies/selected-channel[4]");
var xy_switch = props.globals.getNode("sim/model/f-14b/controls/instrumentation/tacan/xy-switch", 1);

tacan_switch_init = func {
	var s = xy_sign.getValue();
	if (s == "X") { xy_switch.setValue( 0 ) } else { xy_switch.setValue( 1 ) }
}

var tacan_XYtoggle = func {
	var s = xy_sign.getValue();
	if ( s == "X" ) {
		xy_sign.setValue( "Y" );
		xy_switch.setValue( 1 );
	} else {
		xy_sign.setValue( "X" );
		xy_switch.setValue( 0 );
	}
}


# Radios
var com_0 = props.globals.getNode("instrumentation/comm/frequencies/selected-mhz");
var com_1 = props.globals.getNode("instrumentation/comm[1]/frequencies/selected-mhz");

# fuel gauges ###############
var bingo      = props.globals.getNode("sim/model/f-14b/controls/fuel/bingo", 1);
var fuel_tolal = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/total", 1);
var fuel_WL    = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/left-wing-display", 1);
var fuel_WR    = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/right-wing-display", 1);
var fus_feed_L = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/left-fus-feed-display", 1);
var fus_feed_R = props.globals.getNode("sim/model/f-14b/instrumentation/fuel-gauges/right-fus-feed-display", 1);
var fwd_lvl    = props.globals.getNode("consumables/fuel/tank[0]/level-lbs", 1); # FWD tank
var aft_lvl    = props.globals.getNode("consumables/fuel/tank[1]/level-lbs", 1); # AFT tank
var Lfg_lvl    = props.globals.getNode("consumables/fuel/tank[2]/level-lbs", 1); # left feed group
var Rfg_lvl    = props.globals.getNode("consumables/fuel/tank[3]/level-lbs", 1); # right feed group
var Lw_lvl     = props.globals.getNode("consumables/fuel/tank[4]/level-lbs", 1); # left wing tank 2000 lbs
var Rw_lvl     = props.globals.getNode("consumables/fuel/tank[5]/level-lbs", 1); # right wing tank 2000 lbs
var Le_lvl     = props.globals.getNode("consumables/fuel/tank[6]/level-lbs", 1); # left external tank 2000 lbs
var Re_lvl     = props.globals.getNode("consumables/fuel/tank[7]/level-lbs", 1); # right external tank 2000 lbs
var fwd_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[0]/level-gal_us", 1);
var aft_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[1]/level-gal_us", 1);
var Lfg_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[2]/level-gal_us", 1);
var Rfg_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[3]/level-gal_us", 1);
var Lw_lvl_gal_us     = props.globals.getNode("consumables/fuel/tank[4]/level-gal_us", 1);
var Rw_lvl_gal_us     = props.globals.getNode("consumables/fuel/tank[5]/level-gal_us", 1);
var Le_lvl_gal_us     = props.globals.getNode("consumables/fuel/tank[6]/level-gal_us", 1);
var Re_lvl_gal_us     = props.globals.getNode("consumables/fuel/tank[7]/level-gal_us", 1);
aircraft.data.add(	bingo,
					fwd_lvl,
					aft_lvl,
					Lfg_lvl,
					Rfg_lvl,
					Lw_lvl,
					Rw_lvl,
					Le_lvl,
					Re_lvl
				);
aircraft.data.add(	fwd_lvl_gal_us,
					aft_lvl_gal_us,
					Lfg_lvl_gal_us,
					Rfg_lvl_gal_us,
					Lw_lvl_gal_us,
					Rw_lvl_gal_us,
					Le_lvl_gal_us,
					Re_lvl_gal_us
				);

var fuel_gauge = func {
	var fwd = fwd_lvl.getValue();
	var aft = aft_lvl.getValue();
	var Lg = Lfg_lvl.getValue();
	var Rg = Rfg_lvl.getValue();
	var Lw = Lw_lvl.getValue();
	var Rw = Rw_lvl.getValue();
	var Le = Le_lvl.getValue();
	var Re = Re_lvl.getValue();
	var total = fwd + aft + Lw + Rw + Lg + Rg + Le + Re;
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
aircraft.data.add( g_min, g_max );

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

# VDI #####################
var ticker = props.globals.getNode("sim/model/f-14b/instrumentation/ticker", 1);
aircraft.data.add("sim/model/f-14b/controls/VDI/brightness",
	"sim/model/f-14b/controls/VDI/on-off",
	"sim/hud/visibility[0]",
	"sim/hud/visibility[1]",
	"sim/model/f-14b/controls/HSD/on-off",
	"sim/model/f-14b/controls/pilots-displays/hsd-mode-nav");

var inc_ticker = func {
	# ticker used for VDI background continuous translation animation
	var tick = ticker.getValue();
	tick += 1 ;
	ticker.setDoubleValue(tick);
}

# Air Speed Indicator #####
aircraft.data.add("sim/model/f-14b/instrumentation/airspeed-indicator/safe-speed-limit-bug");

# Radar Altimeter #########
aircraft.data.add("sim/model/f-14b/instrumentation/radar-altimeter/limit-bug");

# Lighting ################
aircraft.data.add("sim/model/f-14b/controls/lighting/hook-bypass",
	"controls/lighting/instruments-norm",
	"controls/lighting/panel-norm");

# HSD #####################
var hsd_mode_node = props.globals.getNode("sim/model/f-14b/controls/pilots-displays/hsd-mode-nav");


# AFCS Filters ############
var pitch_pid_pgain = props.globals.getNode("sim/model/f-14b/systems/afcs/pitch-pid-pgain", 1);
var vs_pid_pgain = props.globals.getNode("sim/model/f-14b/systems/afcs/vs-pid-pgain", 1);
var p_pgain = 0;
var mach = 0;

var afcs_filters = func {
	mach = f14.CurrentMach + 0.01;
	p_pgain = -0.01 / ( mach * mach * mach * mach );
	if ( p_pgain < -0.05 ) { p_pgain = -0.05 }
	pitch_pid_pgain.setDoubleValue(p_pgain);
	vs_pid_pgain.setDoubleValue(p_pgain/10);
}

# Main loop ###############
var cnt = 0;

var main_loop = func {
	cnt += 1;
	# done each 0.1 sec.
	inc_ticker();
	local_mag_deviation();
	tacan_update();
	tacan_dev_indicator();
	f14_hud.update_hud();
	g_min_max();
	f14_chronograph.update_chrono();
	afcs_filters();
	#f14_mp_watcher.watch_aimp_models();
	if (( cnt == 3 ) or ( cnt == 6 )) {
		# done each 0.3 sec.
		fuel_gauge();
		if ( cnt == 6 ) {
			# done each 0.6 sec.
			nav1_freq_update();
			cnt = 0;
		}
	}
	settimer(main_loop, UPDATE_PERIOD);
}


# Init ####################
var init = func {
	print("Initializing F-14B Instruments System");
	aircraft.data.load();
	ticker.setDoubleValue(0);
	f14_hud.init_hud();
	tacan_switch_init();
	radardist.init();
	f14_radar.init();
	#f14_mp_watcher.init();
	setprop("controls/switches/radar_init", 0);
	# properties to be stored
	aircraft.data.add(com_0, com_1);
	foreach (var f_tc; tc_freq.getChildren()) {
		aircraft.data.add(f_tc);
	}
	# launch
	settimer(main_loop, 0.5);
}

setlistener("/sim/signals/fdm-initialized", init);


# Miscelaneous definitions and tools ############

# warning lights medium speed flasher
# -----------------------------------
aircraft.light.new("sim/model/f-14b/lighting/warn-medium-lights-switch", [0.3, 0.2]);
setprop("sim/model/f-14b/lighting/warn-medium-lights-switch/enabled", 1);

# Old Fashioned Radio Button Selector
# -----------------------------------
# Where group is the parent node that contains the radio state nodes as children.

radio_bt_sel = func(group, which) {
	foreach (var n; props.globals.getNode(group).getChildren()) {
		n.setBoolValue(n.getName() == which);
		#var toto = n.getName();print(toto);
	}
}

