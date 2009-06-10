# AWG-9 Radar routines.
# RWR (Radar Warning Receiver) is computed in the radar loop for better performance

var ElapsedSec        = props.globals.getNode("sim/time/elapsed-sec");
var SwpFac            = props.globals.getNode("sim/model/f-14b/instrumentation/awg-9/sweep-factor", 1);
var DisplayRdr        = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/display-rdr");
var HudTgtHDisplay    = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/target-display", 1);
var HudTgt            = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/target", 1);
var HudTgtTDev        = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/target-total-deviation", 1);
var HudTgtTDeg        = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/target-total-angle", 1);
var HudTgtClosureRate = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/closure-rate", 1);
var AzField           = props.globals.getNode("instrumentation/radar/az-field", 1);
var RangeRadar2       = props.globals.getNode("instrumentation/radar/radar2-range");
var RadarStandby      = props.globals.getNode("instrumentation/radar/radar-standby");
var RadarStandbyMP    = props.globals.getNode("sim/multiplay/generic/int[2]");
var OurAlt            = props.globals.getNode("position/altitude-ft");
var OurHdg            = props.globals.getNode("orientation/heading-deg");
var OurRoll           = props.globals.getNode("orientation/roll-deg");
var OurPitch          = props.globals.getNode("orientation/pitch-deg");
var EcmOn             = props.globals.getNode("instrumentation/ecm/on-off", 1);

var az_fld            = AzField.getValue();
var l_az_fld          = 0;
var r_az_fld          = 0;
var swp_fac           = nil;    # Scan azimuth deviation, normalized (-1 --> 1).
var swp_deg           = nil;    # Scan azimuth deviation, in degree.
var swp_deg_last      = 0;      # Used to get sweep direction.
var swp_spd           = 1.7; 
var swp_dir           = nil;    # Sweep direction, 0 to left, 1 to right.
var swp_dir_last      = 0;
var ddd_screen_width  = 0.0844; # 0.0844m : length of the max azimuth range on the DDD screen.
var range_radar2      = 0;
var my_radarcorr      = 0;
var our_radar_stanby  = 0;
var wcs_mode          = "pulse-srch";
var tmp_nearest_rng   = nil;
var tmp_nearest_u     = nil;
var nearest_rng       = 0;
var nearest_u         = nil;

var our_true_heading  = 0;
var our_alt           = 0;

var Mp = props.globals.getNode("ai/models");
var mp_i              = 0;
var mp_count          = 0;
var mp_list           = [];
var tgts_list         = [];
var cnt               = 0;

# ECM warnings.
var EcmAlert1 = props.globals.getNode("instrumentation/ecm/alert-type1", 1);
var EcmAlert2 = props.globals.getNode("instrumentation/ecm/alert-type2", 1);
var ecm_alert1        = 0;
var ecm_alert2        = 0;
var ecm_alert1_last   = 0;
var ecm_alert2_last   = 0;
var u_ecm_signal      = 0;
var u_ecm_signal_norm = 0;
var u_radar_standby   = 0;
var u_ecm_type_num    = 0;

init = func() {
	var our_ac_name = getprop("sim/aircraft");
	my_radarcorr = radardist.my_maxrange( our_ac_name ); # in kilometers

	}

# Main loop ###############
# Done each 0.05 sec. Called from instruments.nas
var rdr_loop = func() {
	var display_rdr = DisplayRdr.getBoolValue();
	if ( display_rdr ) {
		az_scan();
		our_radar_stanby = RadarStandby.getValue();
		var bs = getprop("sim/aircraft");
		if ( bs == "f-14b-bs") {
			#our_radar_stanby = 1;  # Back seater's radar doesn't emit.
		}
		RadarStandbyMP.setIntValue(our_radar_stanby); # Tell over MP if
			# our radar is scaning or is in stanby.
	} elsif ( size(tgts_list) > 0 ) {
		foreach( u; tgts_list ) {
			u.set_display(0);
		}
	}
}

var az_scan = func() {

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
		# Antena scan direction change. Max every 2 seconds. Reads the whole MP_list.
		# TODO: Transient when changing az scan field 
		az_fld = AzField.getValue();
		range_radar2 = RangeRadar2.getValue();
		if ( range_radar2 == 0 ) { range_radar2 = 0.00000001 }
		# Reset nearest_range score
		nearest_u = tmp_nearest_u;
		nearest_rng = tmp_nearest_rng;
		tmp_nearest_rng = nil;
		tmp_nearest_u = nil;

		tgts_list = [];
		var raw_list = Mp.getChildren();
		foreach( var c; raw_list ) {
			# FIXME: At that time a multiplayer node may have been deleted while still
			# existing as a displayable target in the radar targets nodes.
			var type = c.getName();
			if (!c.getNode("valid", 1).getValue()) {
				continue;
			}
			var HaveRadarNode = c.getNode("radar");
			if (type == "multiplayer" or type == "tanker" and HaveRadarNode != nil) {
				var u = Target.new(c);
				u_ecm_signal      = 0;
				u_ecm_signal_norm = 0;
				u_radar_standby   = 0;
				u_ecm_type_num    = 0;
				if ( u.Range != nil ) {
					var u_rng = u.get_range();
					if (u_rng < range_radar2  and u.not_acting == 0 ) {
						u.get_deviation(our_true_heading);
						if ( u.deviation > l_az_fld  and  u.deviation < r_az_fld ) {
							append(tgts_list, u);
						} else {
							u.set_display(0);
						}
						ecm_on = EcmOn.getValue();
						# Test if target has a radar. Compute if we are illuminated. This propery used by ECM
						# over MP, should be standardized, like "ai/models/multiplayer[0]/radar/radar-standby".
						if ( ecm_on and u.get_rdr_standby() == 0) {
							rwr(u);	# TODO: override display when alert.
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
			u.get_bearing();
			u.get_heading();
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
				# Compute closure rate in Kts.
				u.get_closure_rate();
				# Check if u = nearest echo.
				if ( tmp_nearest_rng == nil or u_rng < tmp_nearest_rng) {
					tmp_nearest_u = u;
					tmp_nearest_rng = u_rng;
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
		if ( wcs_mode == "tws-auto" and nearest_u.get_display() and nearest_u.deviation > l_az_fld  and  nearest_u.deviation < r_az_fld ) {
			var u_target = nearest_u.type ~ "[" ~ nearest_u.index ~ "]";			
			var our_pitch = OurPitch.getValue();
			var u_dev_rad = (90 - nearest_u.get_deviation(our_true_heading)) * D2R;
			var u_elev_rad = (90 - nearest_u.get_total_elevation(our_pitch)) * D2R;
			# Deviation length on the HUD (at level flight), 0.6686m = distance eye <-> virtual HUD screen.
			var h_dev = 0.6686 / ( math.sin(u_dev_rad) / math.cos(u_dev_rad) );
			var v_dev = 0.6686 / ( math.sin(u_elev_rad) / math.cos(u_elev_rad) );
			# Angle between HUD center/top <-> HUD center/target position.
			# -90° left, 0° up, 90° right, +/- 180° down. 
			var dev_deg =  math.atan2( h_dev, v_dev ) * R2D;
			# Correction with own a/c roll.
			var combined_dev_deg = dev_deg - OurRoll.getValue();
			# Lenght HUD center <-> target pos on the HUD:
			var combined_dev_length = math.sqrt((h_dev*h_dev)+(v_dev*v_dev));

			# clamp and squeeze the top of the display area so the target follow the egg shaped HUD limits.
			var clamp = 0.105;
			var abs_combined_dev_deg = math.abs( combined_dev_deg );
			if ( abs_combined_dev_deg >= 0 and abs_combined_dev_deg < 90 ) {
				var coef = ( 90 - abs_combined_dev_deg ) * 0.00075;
				if ( coef > 0.050 ) { coef = 0.050 }
				clamp -= coef; 
			}
			if ( combined_dev_length > clamp ) {
				combined_dev_length = clamp;
				Clamp_Blinker.blink();
			} else {
				Clamp_Blinker.cont();
			}
			# Clamp closure rate from -200 to +1,000 Kts.
			var cr = nearest_u.ClosureRate.getValue();
			if (cr < -200) { cr = 200 } elsif (cr > 1000) { cr = 1000 }

			HudTgtClosureRate.setValue(cr);
			HudTgtTDeg.setValue(combined_dev_deg);
			HudTgtTDev.setValue(combined_dev_length);
			HudTgtHDisplay.setBoolValue(1);
			HudTgt.setValue(u_target);
			return;
			######### TODO: offset sweep to follow the target ##########
		}
	}
	HudTgtClosureRate.setValue(0);
	HudTgtTDeg.setValue(0);
	HudTgtTDev.setValue(0);
	HudTgtHDisplay.setBoolValue(0);
}
# HUD clamped target blinker
Clamp_Blinker = aircraft.light.new("sim/model/f-14b/lighting/warn-fast-lights-switch", [0.1, 0.1]);
setprop("sim/model/f-14b/lighting/warn-fast-lights-switch/enabled", 1);


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

wcs_mode_toggle = func() {
	# Temporarely toggles between the first 2 available modes.
	foreach (var n; props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode").getChildren()) {
		if ( n.getBoolValue() ) { wcs_mode = n.getName() }
	}
	if ( wcs_mode == "pulse-srch" ) {
		setprop("sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode/pulse-srch", 0);
		setprop("sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode/tws-auto", 1);
		wcs_mode = "tws-auto";
		AzField.setValue(60);
		ddd_screen_width = 0.0422;
	} elsif ( wcs_mode == "tws-auto" ) {
		setprop("sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode/tws-auto", 0);
		setprop("sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode/pulse-srch", 1);
		wcs_mode = "pulse-srch";
		AzField.setValue(120);
		ddd_screen_width = 0.0844;
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
		obj.type = c.getName();
		obj.Callsign = c.getNode("callsign");
		obj.index = c.getIndex();
		obj.string = "ai/models/" ~ obj.type ~ "[" ~ obj.index ~ "]";
		obj.shortstring = obj.type ~ "[" ~ obj.index ~ "]";
		
		# Remote back-seater don't emit and are invisible. FIXME: This is going to be handled by radardist ASAP.		
		obj.not_acting = 0;
		var remote_bs_string = c.getNode("sim/multiplay/generic/string[1]").getValue();
		if ( remote_bs_string != nil ) {
		var l = split(";", remote_bs_string);
			if ( size(l) > 0 ) {
				if ( l[0] == "f-14b-bs" ) {
					obj.not_acting = 1;
				}
			}
		}

		var bs = getprop("sim/aircraft");
		obj.InstrTgts = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/targets", 1);
		if ( bs == "f-14b-bs") {
			if  ( BS_instruments.Pilot != nil ) {
				# Local back-seater has a different radar-awg-9 folder.
				obj.InstrTgts = BS_instruments.Pilot.getNode("sim/model/f-14b/instrumentation/radar-awg-9/targets", 1);
				# Local back-seater does not see its pilot's aircraft.
				var target_callsign = obj.Callsign.getValue();
				var p_callsign = BS_instruments.Pilot.getNode("callsign").getValue();
				if ( target_callsign == p_callsign ) {
					obj.not_acting = 1;
				}
			}
		}	

		obj.TgtsFiles = obj.InstrTgts.getNode(obj.shortstring, 1);

		obj.Range          = obj.RdrProp.getNode("range-nm");
		obj.Bearing        = obj.RdrProp.getNode("bearing-deg");
		obj.Elevation      = obj.RdrProp.getNode("elevation-deg");
		obj.BBearing       = obj.TgtsFiles.getNode("bearing-deg", 1);
		obj.BHeading       = obj.TgtsFiles.getNode("true-heading-deg", 1);
		obj.RangeScore     = obj.TgtsFiles.getNode("range-score", 1);
		obj.RelBearing     = obj.TgtsFiles.getNode("ddd-relative-bearing", 1);
		obj.Carrier        = obj.TgtsFiles.getNode("carrier", 1);
		obj.EcmSignal      = obj.TgtsFiles.getNode("ecm-signal", 1);
		obj.EcmSignalNorm  = obj.TgtsFiles.getNode("ecm-signal-norm", 1);
		obj.EcmTypeNum     = obj.TgtsFiles.getNode("ecm_type_num", 1);
		obj.Display        = obj.TgtsFiles.getNode("display", 1);
		obj.Fading         = obj.TgtsFiles.getNode("ddd-echo-fading", 1);
		obj.DddDrawRangeNm = obj.TgtsFiles.getNode("ddd-draw-range-nm", 1);
		obj.TidDrawRangeNm = obj.TgtsFiles.getNode("tid-draw-range-nm", 1);
		obj.RoundedAlt     = obj.TgtsFiles.getNode("rounded-alt-ft", 1);
		obj.TimeLast       = obj.TgtsFiles.getNode("closure-last-time", 1);
		obj.RangeLast      = obj.TgtsFiles.getNode("closure-last-range-nm", 1);
		obj.ClosureRate    = obj.TgtsFiles.getNode("closure-rate-kts", 1);

		obj.TimeLast.setValue(ElapsedSec.getValue());
		obj.RangeLast.setValue(obj.Range.getValue());

		obj.RadarStandby = c.getNode("sim/multiplay/generic/int[2]");

		obj.deviation = nil;

		return obj;
	},
	get_heading : func {
		var n = me.Heading.getValue();
		me.BHeading.setValue(n);
		return n;	},
	get_bearing : func {
		var n = me.Bearing.getValue();
		me.BBearing.setValue(n);
		return n;
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
	get_total_elevation : func(own_pitch) {
		me.deviation =  - deviation_normdeg(own_pitch, me.Elevation.getValue());
		return me.deviation;
	},
	get_range : func {
		return me.Range.getValue();
	},
	get_horizon : func(own_alt) {
		var tgt_alt = me.get_altitude();
		if ( tgt_alt != nil ) {
			if ( own_alt < 0 ) { own_alt = 0.001 }
			if ( debug.isnan(tgt_alt)) {
				print("####### nan ########");
				return(0);
			}
			if ( tgt_alt < 0 ) { tgt_alt = 0.001 }
			return radardist.radar_horizon( own_alt, tgt_alt );
		} else {
			return(0);
		}
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
	get_fading : func() {
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
	get_closure_rate : func() {
		var dt = ElapsedSec.getValue() - me.TimeLast.getValue();
		var rng = me.Range.getValue();
		var t_distance = me.RangeLast.getValue() - rng;
		var cr = t_distance/dt*3600;
		me.ClosureRate.setValue(cr);
		me.RangeLast.setValue(rng);
		return(cr);
	},
	list : [],
};

# Notes:

# HUD field of view = 2 * math.atan2( 0.0764, 0.7186) * globals.R2D; # ~ 12.1375°
# where 0.071 : virtual screen half width, 0.7186 : distance eye -> screen
