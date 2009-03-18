# AWG-9 Radar routines.
# RWR (Radar Warning Receiver) is computed in the radar loop for better performance

var SwpFac  = props.globals.getNode("sim/model/f-14b/instrumentation/awg-9/sweep-factor", 1);
var DisplayRdr  = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/display-rdr");
var HudTgtHDisplay  = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/target-display", 1);
var HudTgtHDev  = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/target-horizontal-deviation", 1);
var HudTgtVDev  = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/target-vertical-deviation", 1);
var HudCombinedDevDeg  = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/combined_dev_deg", 1);
var AzField = props.globals.getNode("instrumentation/radar/az-field", 1);
var RangeRadar2 = props.globals.getNode("instrumentation/radar/radar2-range");
var OurAlt = props.globals.getNode("position/altitude-ft");
var OurHdg = props.globals.getNode("orientation/heading-deg");
var OurRoll = props.globals.getNode("orientation/roll-deg");
var OurPitch = props.globals.getNode("orientation/pitch-deg");
var EcmOn = props.globals.getNode("instrumentation/ecm/on-off", 1);

var az_fld = AzField.getValue();
var swp_fac      = nil; # Scan azimuth deviation, normalized (-1 --> 1).
var swp_deg      = nil; # Scan azimuth deviation, in degree.
var swp_deg_last = 0; # Used to get sweep direction.
var swp_spd      = 1.7; 
var swp_dir      = nil; # Sweep direction, 0 to left, 1 to right.
var swp_dir_last = 0;
var ddd_screen_width = 0.0844; # 0.0844m : length of the max azimuth range on the DDD screen.
var range_radar2 = 0;
var my_radarcorr = 0;
var wcs_mode = "pulse-srch";
var nearest_rng  = 0;
var nearest_u    = nil;

var our_true_heading = 0;
var our_alt = 0;

var Mp = props.globals.getNode("ai/models");
var mp_i      = 0;
var mp_count   = 0;
var mp_list = [];
var tgts_list = [];
var cnt = 0;

# ECM warnings.
var EcmAlert1 = props.globals.getNode("instrumentation/ecm/alert-type1", 1);
var EcmAlert2 = props.globals.getNode("instrumentation/ecm/alert-type2", 1);
var ecm_alert1      = 0;
var ecm_alert2      = 0;
var ecm_alert1_last = 0;
var ecm_alert2_last = 0;
var u_ecm_signal  = 0;
var u_ecm_signal_norm  = 0;
var u_radar_standby = 0;
var u_ecm_type_num = 0;

init = func() {
	var our_ac_name = getprop("sim/aircraft");
	my_radarcorr = radardist.my_maxrange( our_ac_name ); # in kilometers
}

# Main loop ###############
var rdr_loop = func() {
	var display_rdr = DisplayRdr.getBoolValue();
	if ( display_rdr ) {
		az_scan();
	} elsif ( size(tgts_list) > 0 ) {
		foreach( u; tgts_list ) {
			u.set_display(0);
		}
	}
}

var az_scan = func() {
	# Done each 0.05 sec. Called from instruments.nas

	# Antena az scan.
	var fld_frac = az_fld / 120;
	var fswp_spd = swp_spd / fld_frac;
	swp_fac = math.sin(cnt * fswp_spd) * fld_frac;
	SwpFac.setValue(swp_fac);
	swp_deg = az_fld / 2 * swp_fac;
	swp_dir = swp_deg < swp_deg_last ? 0 : 1;
	if ( az_fld == nil ) { az_fld = 74 }
	l_az_fld = - az_fld / 2;
	r_az_fld = az_fld / 2;

	var fading_speed = 0.015;

	our_true_heading = OurHdg.getValue();
	our_alt = OurAlt.getValue();

	if (swp_dir != swp_dir_last) {
		# Transient when changing az scan field 
		az_fld = AzField.getValue();
		range_radar2 = RangeRadar2.getValue();
		if ( range_radar2 == 0 ) { range_radar2 = 0.00000001 }
		# Reset nearest_range_score
		nearest_rng = nil;

		# Antena scan direction change. Max every 2 seconds. Reads the whole MP_list.
		tgts_list = [];
		var raw_list = Mp.getChildren();
		foreach( var c; raw_list ) {
			var type = c.getName();
			var HaveRadarNode = c.getNode("radar");
			if (type == "multiplayer" or type == "tanker" and HaveRadarNode != nil) {
				var u = Target.new(c);
				u_ecm_signal  = 0;
				u_ecm_signal_norm  = 0;
				u_radar_standby = 0;
				u_ecm_type_num = 0;
				if ( u.Range != nil) {
					var u_rng = u.get_range();
					if (u_rng < range_radar2 ) {
						##### We should take own aircraft roll and pitch here, and save later HUD pitch issues.
						u.get_deviation(our_true_heading);
						if ( u.deviation > l_az_fld  and  u.deviation < r_az_fld ) {
							append(tgts_list, u);
						} else {
							u.set_display(0);
						}
						ecm_on = EcmOn.getValue();
						# Test if target has a radar. Compute if we are illuminated. This propery used by ECM
						# over MP should be standardized, like "ai/models/multiplayer[0]/radar/radar-standby"
						if ( ecm_on and u.get_rdr_standby() == 0) {
							rwr(u);	# TODO: overide display when alert.
						}
					} else {
						u.set_display(0);
					}
				}
			}
		}


		# Summarize ECM alerts.
		if ( ecm_alert1 == 0 and ecm_alert1_last == 0 ) { EcmAlert1.setBoolValue(0) }
		if ( ecm_alert2 == 0 and ecm_alert1_last == 0 ) { EcmAlert2.setBoolValue(0) }
		ecm_alert1_last = ecm_alert1; # And avoid alert blinking at each loop.
		ecm_alert2_last = ecm_alert2;
		ecm_alert1 = 0;
		ecm_alert2 = 0;
	}


	foreach( u; tgts_list ) {
		var u_display = 0;
		var u_fading = u.get_fading() - fading_speed;
		if ( u_fading < 0 ) { u_fading = 0 }
		if (( swp_dir and swp_deg_last < u.deviation and u.deviation <= swp_deg )
			or ( ! swp_dir and swp_deg <= u.deviation and u.deviation < swp_deg_last )) {
			var horizon = u.get_horizon( our_alt );
			var u_rng = u.get_range();
			if ( u_rng < horizon and radardist.radis(u.string, my_radarcorr)) {
				# Compute mp position in our DDD display. (Bearing/horizontal + Range/Vertical).
				u.set_relative_bearing( ddd_screen_width / az_fld * u.deviation );
				var factor_range_radar = 0.0657 / range_radar2; # 0.0657m : length of the distance range on the DDD screen.
				u.set_ddd_draw_range_nm( factor_range_radar * u_rng );
				u_fading = 1;
				u_display = 1;
				# Compute mp position in our TID display. (PPI like display, normaly targets are displayed only when locked.)
				factor_range_radar = 0.15 / range_radar2; # 0.15m : length of the radius range on the TID screen.
				u.set_tid_draw_range_nm( factor_range_radar * u_rng );
				# Compute first digit of mp altitude rounded to nearest thousand. (labels).
				u.set_rounded_alt( rounding1000( u.get_altitude() ) / 1000 );
				# Check if u = nearest echo.
				if ( nearest_rng == nil or u_rng < nearest_rng) {
					nearest_u = u;
					nearest_rng = u_rng;
				}
			}
			u.set_display(u_display);
		}
		u.set_fading(u_fading);
	}	
	swp_deg_last = swp_deg;
	swp_dir_last = swp_dir;
	cnt += 0.05;
}


var hud_nearest_tgt = func() {
	# Computes nearest_u position in the HUD
	if ( nearest_u != nil ) {
		if ( wcs_mode == "tws-auto" and nearest_u.get_display() ) {
			var u_dev_brad = (90 - nearest_u.get_deviation(our_true_heading)) * D2R;
			var u_elev = nearest_u.get_elevation();
			var u_elev_brad = (90 - u_elev) * D2R;
			# Deviation length on the HUD, raw (at level flight):
			var raw_horiz_dev = 0.7186 / ( math.sin(u_dev_brad) / math.cos(u_dev_brad) );# 0.7186m : distance eye <-> virtual HUD screen.
			var raw_vert_dev = 0.7186 / ( math.sin(u_elev_brad) / math.cos(u_elev_brad) );
			# Angle between HUD center <-> target pos on the HUD segment and Horizon, at level flight. -90° left, 0° up, 90° right, +/- 180° down 
			var raw_combined_dev_deg = math.atan2( raw_horiz_dev, raw_vert_dev ) * R2D;
			# Corrected with own a/c roll:
			var combined_dev_deg = raw_combined_dev_deg - OurRoll.getValue();
			# Lenght HUD center <-> target pos on the HUD segment:
			var raw_combined_dev_length = math.sqrt( (raw_horiz_dev*raw_horiz_dev) + (raw_vert_dev*raw_vert_dev) );
			# Deviation due to own a/c pitch:
			#### TODO: Fix the pitch issue when inverted flight.
			var pitch = OurPitch.getValue();
			var pitchb_rad = ( 90 - pitch ) * D2R;
			var pitch_dev = 0.7186 / (math.sin(pitchb_rad) / math.cos(pitchb_rad));

			# Deviation length on the HUD, final:
			var vert_dev = (math.sin( ( 90 - combined_dev_deg) * D2R ) * raw_combined_dev_length) - pitch_dev;
			var horiz_dev = math.cos( ( 90 - combined_dev_deg) * D2R ) * raw_combined_dev_length;

			if ( vert_dev > 0.105 ) { vert_dev = 0.105 }
			if ( vert_dev < -0.105 ) { vert_dev = -0.105 }
			if ( horiz_dev > 0.105 ) { horiz_dev = 0.105 }
			if ( horiz_dev < -0.105 ) { horiz_dev = -0.105 }

			HudTgtHDev.setValue(horiz_dev);
			HudTgtVDev.setValue(vert_dev);
			HudTgtHDisplay.setBoolValue(1);
			######### TODO: offset sweep to follow the target ##########
		} else {
			HudCombinedDevDeg.setValue(0);
			HudTgtHDev.setValue(0);
			HudTgtVDev.setValue(0);
			HudTgtHDisplay.setBoolValue(0);
		}
	}
}

# ECM: Radar Warning Receiver
rwr = func(u) {
	var u_name = radardist.get_aircraft_name(u.string);
	var u_maxrange = radardist.my_maxrange(u_name); # in kilometer, 0 is unknown or no radar.
	var horizon = u.get_horizon( our_alt );
	var u_rng = u.get_range();
	var u_carrier = u.check_carrier_type();
	if ( u_maxrange > 0  and u_rng < horizon ) {
		# Test if we are in its radar field (hard coded 74°) or if we have a MPcarrier.
		# Compute the signal strength.
		var our_deviation_deg = deviation_normdeg(u.get_heading(), u.get_reciprocal_bearing());
		if ( our_deviation_deg < 0 ) { our_deviation_deg *= -1 }
		if ( our_deviation_deg < 37 or u_carrier == 1 ) {
			u_ecm_signal = (((-our_deviation_deg/20)+2.5)*(!u_carrier )) + (-u_rng/20) + 2.6 + (u_carrier*1.8);
			u_ecm_type_num = radardist.get_ecm_type_num(u_name);
		}
	}
	# Compute global threat situation for undiscriminant warning lights
	# and discrete (normalized) definition of threat strength.
	if ( u_ecm_signal > 1 and u_ecm_signal < 3 ) {
		EcmAlert1.setBoolValue(1);
		ecm_alert1 = 1;
		u_ecm_signal_norm = 2;
	} elsif ( u_ecm_signal >= 3 ) {
		EcmAlert2.setBoolValue(1);
		ecm_alert2 = 1;
		u_ecm_signal_norm = 1;
	}
	u.EcmSignal.setValue(u_ecm_signal);
	u.EcmSignalNorm.setIntValue(u_ecm_signal_norm);
	u.EcmTypeNum.setIntValue(u_ecm_type_num);
}

		
# Utilities.
var deviation_normdeg = func(our_heading, target_bearing) {
	var dev_norm = our_heading - target_bearing;
	while (dev_norm < -180) dev_norm += 360;
	while (dev_norm > 180) dev_norm -= 360;
	return(dev_norm);
}

var rounding1000 = func(n) {
	var a = int( n / 1000 );
	var l = ( a + 0.5 ) * 1000;
	n = (n >= l) ? ((a + 1) * 1000) : (a * 1000);
	return( n );
}

# Controls
wcs_mode_sel = func(mode) {
	foreach (var n; props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode").getChildren()) {
		n.setBoolValue(n.getName() == mode);
		wcs_mode = mode;
	}
	if ( wcs_mode == "pulse-srch" ) {
		AzField.setValue(120);
		ddd_screen_width = 0.0844;
	} else {
		AzField.setValue(60);
		ddd_screen_width = 0.0422;
	}
}

# Target class
var Target = {
	new : func (c) {
		var obj = { parents : [Target]};
		obj.RdrProp = c.getNode("radar");
		obj.Heading = c.getNode("orientation/true-heading-deg");
		obj.Alt = c.getNode("position/altitude-ft");
		obj.AcType = c.getNode("sim/model/ac-type");

		obj.InRange = obj.RdrProp.getNode("in-range");
		obj.Range = obj.RdrProp.getNode("range-nm");
		obj.RangeScore = obj.RdrProp.getNode("range-score", 1);
		obj.Bearing = obj.RdrProp.getNode("bearing-deg");
		obj.RelBearing = obj.RdrProp.getNode("ddd-relative-bearing", 1);
		obj.Elevation = obj.RdrProp.getNode("elevation-deg");
		obj.Carrier = obj.RdrProp.getNode("carrier", 1);
		obj.EcmSignal = obj.RdrProp.getNode("ecm-signal", 1);
		obj.EcmSignalNorm = obj.RdrProp.getNode("ecm-signal-norm", 1);
		obj.EcmTypeNum = obj.RdrProp.getNode("ecm_type_num", 1);
		obj.Display = obj.RdrProp.getNode("display", 1);
		obj.Fading = obj.RdrProp.getNode("ddd-echo-fading", 1);
		obj.DddDrawRangeNm = obj.RdrProp.getNode("ddd-draw-range-nm", 1);
		obj.TidDrawRangeNm = obj.RdrProp.getNode("tid-draw-range-nm", 1);
		obj.RoundedAlt = obj.RdrProp.getNode("rounded-alt-ft", 1);

		obj.RadarStandby = c.getNode("sim/multiplay/generic/int[2]");

		obj.type = c.getName();
		obj.index = c.getIndex();
		obj.string = "ai/models/" ~ obj.type ~ "[" ~ obj.index ~ "]";
		obj.deviation = nil;

		return obj;
	},
	get_heading : func {
		return me.Heading.getValue();
	},
	get_bearing : func {
		return me.Bearing.getValue();
	},
	set_relative_bearing : func(n) {
		me.RelBearing.setValue(n);
	},
	get_reciprocal_bearing : func {
		return geo.normdeg(me.get_bearing() + 180);
	},
	get_deviation : func(true_heading_ref) {
		me.deviation =  - deviation_normdeg(true_heading_ref, me.get_bearing());
		return me.deviation;
	},
	get_altitude : func {
		return me.Alt.getValue();
	},
	get_elevation : func {
		return me.Elevation.getValue();
	},
	get_range : func {
		return me.Range.getValue();
	},
	get_horizon : func(own_alt) {
		if ( own_alt < 0 ) { own_alt = 0.001 }
		var tgt_alt = me.get_altitude();
		if ( tgt_alt < 0 ) { tgt_alt = 0.001 }
		return radardist.radar_horizon( own_alt, tgt_alt );
	},
	check_carrier_type : func {
		var type = "none";
		var carrier = 0;
		if ( me.AcType != nil ) { type = me.AcType.getValue() }
		if ( type == "MP-Nimitz" or type == "MP-Eisenhower" ) { carrier = 1 }
		me.Carrier.setBoolValue(carrier);
		return carrier;
	},
	get_rdr_standby : func {
		var s = 0;
		if ( me.RadarStandby != nil ) {
			s = me.RadarStandby.getValue();
			if (s == nil) { s = 0 } elsif (s != 1) { s = 0 }
		}
		return s;
	},
	get_display : func() {
		return me.Display.getValue();
	},
	set_display : func(n) {
		me.Display.setBoolValue(n);
	},
	get_fading : func {
		var fading = me.Fading.getValue(); 
		if ( fading == nil ) { fading = 0 }
		return fading;
	},
	set_fading : func(n) {
		me.Fading.setValue(n);
	},
	set_ddd_draw_range_nm : func(n) {
		me.DddDrawRangeNm.setValue(n);
	},
	set_hud_draw_horiz_dev : func(n) {
		me.HudDrawHorizDev.setValue(n);
	},
	set_tid_draw_range_nm : func(n) {
		me.TidDrawRangeNm.setValue(n);
	},
	set_rounded_alt : func(n) {
		me.RoundedAlt.setValue(n);
	},
	list : [],
};

# Notes:

# HUD field of view = 2 * math.atan2( 0.0764, 0.7186) * globals.R2D; # ~ 12.1375°
# where 0.071 : virtual screen half width, 0.7186 : distance eye -> screen
