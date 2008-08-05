##### Radar properties for display of multiplayer aircraft

var SPEED         = 3;   # Number of targets worked without pause.
# Pause duration is defined in f14_instruments.main_loop().

var counter = 0;

# Displayed range node.
var range_radar_node = props.globals.getNode("instrumentation/radar/range");

# Get our radar max range.
var my_radarcorr = 0;
var init = func { 
	my_radarcorr = radardist.my_maxrange("f-14b"); # in kilometers
	#print("my_radarcorr = "~ my_radarcorr);
}



var target_draw = func (target) {
	var t_node          = props.globals.getNode(target);
	var t_radar_node    = t_node.getNode("radar");
	var t_in_range_node = t_radar_node.getNode("in-range");# not computed for carrier ???
	# Checks if target datas are valid
	var t_in_range      = t_in_range_node.getValue();
	var t_display_node  = t_radar_node.getNode("display", 1);
	# Radar stuff:
	# TODO: test if radar stuff is needed.
	if (! t_in_range) {
		# What does exactly t_in_range mean ???
		t_display_node.setBoolValue(0);
	} else {
		var t_position_node      = t_node.getNode("position");
		var t_range_node         = t_radar_node.getNode("range-nm");
		var t_range              = t_range_node.getValue();
		var t_bearing_node       = t_radar_node.getNode("bearing-deg");
		var t_bearing            = t_bearing_node.getValue();
		var t_alt_node           = t_position_node.getNode("altitude-ft");
		var t_alt                = t_alt_node.getValue();
		var t_draw_range_nm_node = t_radar_node.getNode("draw-range-nm", 1);
		var t_rounded_alt_node   = t_radar_node.getNode("rounded-alt-ft", 1);
		var range_radar = range_radar_node.getValue();
		# Last sanity and raw range check.
		if ((t_bearing == nil) or (t_alt == nil) or (t_range > range_radar)) {
			t_display_node.setBoolValue(0);
		} else {
			# Checks if mp within radar field (74°) and if detectable (radardist.nas).
			var true_heading = getprop("orientation/heading-deg");
			var deviation_deg = true_heading - t_bearing;
			while (deviation_deg < -180)
				deviation_deg += 360;
			while (deviation_deg > 180)
				deviation_deg -= 360;
			if (( deviation_deg < -37 ) or ( deviation_deg > 37 ) or ! radardist.radis(target, my_radarcorr)) {
				#print(target);
				t_display_node.setBoolValue(0);
			} else {
				# Computes mp position in display
				var factor_range_radar = 0.15 / range_radar;
				var draw_radar = factor_range_radar * t_range;
				t_draw_range_nm_node.setValue(draw_radar);
				# Computes first digit of mp altitude rounded to nearest thousand
				var rounded_alt = rounding1000(t_alt) / 1000;			
				t_rounded_alt_node.setValue(rounded_alt);
				t_display_node.setBoolValue(1);
			}
		}
	}
	# TODO: ECM/RWR stuff.
	# test if ECM/RWR stuff is needed.
	# TODO: Impact stuff
	# test if Impact stuff is needed.
}


var rounding1000 = func(n) {
	var a = int( n / 1000 );
	var l = ( a + 0.5 ) * 1000;
	n = (n >= l) ? ((a + 1) * 1000) : (a * 1000);
	return( n );
}

var range_control = func(n) {
	# 5, 10, 20, 50, 100, 200
	var range_radar = range_radar_node.getValue();
	if ( n == 1 ) {
		if ( range_radar == 5 ) {
			range_radar = 10;
		} elsif ( range_radar == 10 ) {
			range_radar = 20;
		} elsif ( range_radar == 20 ) {
			range_radar = 50;
		} elsif ( range_radar == 50 ) {
			range_radar = 100;
		} else {
			range_radar = 200;
		}
	} else {
		if ( range_radar == 200 ) {
			range_radar = 100;
		} elsif ( range_radar == 100 ) {
			range_radar = 50;
		} elsif ( range_radar == 50 ) {
			range_radar = 20;
		} elsif ( range_radar == 20 ) {
			range_radar = 10;
		} else {
			range_radar = 5;
		}
	}
	range_radar_node.setValue(range_radar);
}
