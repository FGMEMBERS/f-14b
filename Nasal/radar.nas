##### Radar properties for display of multiplayer aircraft

var SPEED   = 5; # Number of targets worked without pause. 
var counter = 0;

var display = func {
	var r_init = getprop("controls/switches/radar_init");

	if (r_init == 0) {
		setprop("controls/switches/radar_init", 1);
		setprop("controls/switches/radar_i", 0);
		setprop("controls/switches/radar_t", 0);
	}

	if (r_init == 1) {
		var i = getprop("controls/switches/radar_i");
		if ( i <= 12 ) {
			var target = "ai/models/multiplayer[" ~ i ~ "]/";
		} else {
			var target = "ai/models/tanker[" ~ ( i - 13 ) ~ "]/";
		}
		if ( props.globals.getNode( target ) != nil ) {
			target_draw(target);
		}
		var i = i + 1;
		if (i == 17) {
			var i = 0;
		}
		setprop("controls/switches/radar_i", i);
		counter += 1;
		if ( counter < SPEED ) {
			display();
		} else {
			counter = 0;
		}
	}
}

var target_draw = func (target) {
	var t_node          = props.globals.getNode(target);
	var t_radar_node    = t_node.getNode("radar");
	var t_in_range_node = t_radar_node.getNode("in-range");
	# Checks if target datas are valid
	var t_in_range      = t_in_range_node.getValue();
	var t_display_node  = t_radar_node.getNode("display", 1);
	if (! t_in_range) {
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
		var range_radar          = getprop("instrumentation/radar/range");
		# Last sanity check.
		if ((t_bearing == nil) or (t_alt == nil) or (t_range > range_radar)) {
			t_display_node.setBoolValue(0);
		} else {
			# Checks if mp within radar field (74°).
			var true_heading = getprop("orientation/heading-deg");
			var deviation_deg = true_heading - t_bearing;
			while (deviation_deg < -180)
				deviation_deg += 360;
			while (deviation_deg > 180)
				deviation_deg -= 360;
			if (( deviation_deg < -37 ) or ( deviation_deg > 37 )) {
				t_display_node.setBoolValue(0);
			} else {
				# Computes mp position in display
				var factor_range_radar = 0.15 / range_radar;
				var draw_radar = factor_range_radar * t_range;
				t_draw_range_nm_node.setValue(draw_radar);
				# Computes mp altitude divided by 1000 rounded to units.
				var rounded_alt = rounding1000(t_alt) / 1000;			
				t_rounded_alt_node.setValue(rounded_alt);
				t_display_node.setBoolValue(1);
			}
		}
	}
}


var rounding1000 = func(n) {
	var a = int( n / 1000 );
	var l = ( a + 0.5 ) * 1000;
	n = (n >= l) ? ((a + 1) * 1000) : (a * 1000);
	return( n );
}

var range_control = func(n) {
	# 2.5, 5, 10, 25, 50, 100, 150, 200
	var range_radar = getprop("instrumentation/radar/range");
	if ( n == 1 ) {
		if ( range_radar == 2.5 ) {
			range_radar = 5;
		} elsif ( range_radar == 5 ) {
			range_radar = 10;
		} elsif ( range_radar == 10 ) {
			range_radar = 25;
		} elsif ( range_radar == 25 ) {
			range_radar = 50;
		} elsif ( range_radar == 50 ) {
			range_radar = 100;
		} elsif ( range_radar == 100 ) {
			range_radar = 150;
		} else {
			range_radar = 200;
		}
	} else {
		if ( range_radar == 200 ) {
			range_radar = 150;
		} elsif ( range_radar == 150 ) {
			range_radar = 100;
		} elsif ( range_radar == 100 ) {
			range_radar = 50;
		} elsif ( range_radar == 50 ) {
			range_radar = 25;
		} elsif ( range_radar == 25 ) {
			range_radar = 10;
		} elsif ( range_radar == 10 ) {
			range_radar = 5;
		} else {
			range_radar = 2.5;
		}
	}
	setprop("instrumentation/radar/range", range_radar);
}
