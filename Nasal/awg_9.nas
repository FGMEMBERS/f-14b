# AWG-9 Radar routines.

var SwpFac  = props.globals.getNode("sim/model/f-14b/instrumentation/awg-9/sweep-factor", 1);
var DisplayRdr  = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/display-rdr");
var AzField = props.globals.getNode("instrumentation/radar/az-field", 1);
var RangeRadar2 = props.globals.getNode("instrumentation/radar/radar2-range");
var RadarAzField = props.globals.getNode("instrumentation/radar/az-field", 1);
var OurAlt = props.globals.getNode("position/altitude-ft");
var OurHdg = props.globals.getNode("orientation/heading-deg");
var EcmOn = props.globals.getNode("instrumentation/ecm/on-off", 1);

var swp_fac = nil; # Scan azimuth deviation, normalized (-1 --> 1).
var swp_deg = nil; # Scan azimuth deviation, in degree.
var swp_deg_last = 0; # Used to get sweep direction.
var swp_spd = 1.7; 
var swp_dir = nil; # Sweep direction, 0 to left, 1 to right.
var swp_dir_last = 0;
var my_radarcorr = 0;

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
	# Done each 0.05 sec. Called from Instruments.nas

	# Antena az scan.
	swp_fac = math.sin(cnt * swp_spd);
	SwpFac.setValue(swp_fac);
	var az_fld = AzField.getValue();
	swp_deg = az_fld / 2 * swp_fac;
	swp_dir = swp_deg < swp_deg_last ? 0 : 1;
	var azfld = RadarAzField.getValue();
	if ( azfld == nil ) { azfld = 74 }
	l_azfld = - azfld / 2;
	r_azfld = azfld / 2;
	var fading_speed = 0.015;

	var our_true_heading = OurHdg.getValue();
	var our_alt = OurAlt.getValue();

	if (swp_dir != swp_dir_last) {
		# Antena scan direction change. Max every 2 seconds. Reads the whole MP_list.
		tgts_list = [];
		var raw_list = Mp.getChildren();
		foreach( var c; raw_list ) {
			var type = c.getName();
			if (type == "multiplayer" or type == "tanker") {
				var u = Target.new(c);
				var u_ecm_signal  = 0;
				var u_ecm_signal_norm  = 0;
				var u_radar_standby = 0;
				var u_ecm_type_num = 0;
				if ( u.get_in_range() and u.Range != nil) {
					var u_rng = u.get_range();
					var u_carrier = u.check_carrier_type();
					u.get_deviation(our_true_heading);
					if ( u.deviation > l_azfld  and  u.deviation < r_azfld ) {
						append(tgts_list, u);
					} else {
						u.set_display(0);
					}
					# Test if target has a radar. Compute if we are illuminated.
					# This propery used by ECM over MP should be standardized,
					# like "ai/models/multiplayer[0]/radar/radar-standby"
					ecm_on = EcmOn.getValue();
					if ( ecm_on and u.get_rdr_standby() == 0) {
						# TODO: overide display when alert.
						var u_name = radardist.get_aircraft_name(u.string);
						var u_maxrange = radardist.my_maxrange(u_name); # in kilometer, 0 is unknown or no radar.
						var horizon = u.get_horizon( our_alt );
						if ( u_maxrange > 0  and u_rng < horizon ) {
							# Test if we are in its radar field (hard coded 74°) or if we have a MPcarrier.
							# Compute the signal strength.
							var our_deviation_deg = deviation_normdeg(u.get_heading(), u.get_reciprocal_bearing());
							if ( our_deviation_deg < 0 ) { our_deviation_deg *= -1 }
							if ( our_deviation_deg < 37 or u_carrier == 1 ) {
								u_ecm_signal = ( (((-our_deviation_deg/20)+2.5)*(!u_carrier )) + (-u_rng/20) + 2.6 + (u_carrier*1.8));
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
				}
			}
		}
		if ( ecm_alert1 == 0 and ecm_alert1_last == 0 ) { EcmAlert1.setBoolValue(0) }
		if ( ecm_alert2 == 0 and ecm_alert1_last == 0 ) { EcmAlert2.setBoolValue(0) }
		# Avoid alert blinking at each loop.
		ecm_alert1_last = ecm_alert1;
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
			range_radar2 = RangeRadar2.getValue();
			if ( range_radar2 == 0 ) { range_radar2 = 0.00000001 }
			if ( u_rng < horizon and radardist.radis(u.string, my_radarcorr) and u_rng <= range_radar2) {

				# Compute mp position in our DDD display. (Bearing/horizontal + Range/Vertical).
				u.set_relative_bearing( 0.0844 / az_fld * u.deviation ); # 0.0844m : length of the azimuth range on the DDD screen.
				var factor_range_radar = 0.0657 / range_radar2; # 0.0657m : length of the distance range on the DDD screen.
				u.set_ddd_draw_range_nm( factor_range_radar * u_rng );
				u_fading = 1;
				u_display = 1;

				# Compute mp position in our TID display. (PPI like display, normaly targets are display only when locked.)
				# 0.15 is the length of the radius range on the TID screen.
				factor_range_radar = 0.15 / range_radar2;
				u.set_tid_draw_range_nm( factor_range_radar * u_rng );
				# Compute first digit of mp altitude rounded to nearest thousand. (labels).
				u.set_rounded_alt( rounding1000( u.get_altitude() ) / 1000 );

			}
			u.set_display(u_display);
		}
		u.set_fading(u_fading);
	}
	swp_deg_last = swp_deg;
	swp_dir_last = swp_dir;
	cnt += 0.05;
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
		obj.Bearing = obj.RdrProp.getNode("bearing-deg");
		obj.RelBearing = obj.RdrProp.getNode("ddd-relative-bearing", 1);
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
	get_in_range : func {
		var in_range = me.InRange.getValue(); 
		if ( in_range == nil ) { in_range = 0 }
		return in_range;
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
	set_tid_draw_range_nm : func(n) {
		me.TidDrawRangeNm.setValue(n);
	},
	set_rounded_alt : func(n) {
		me.RoundedAlt.setValue(n);
	},
	list : [],
};
