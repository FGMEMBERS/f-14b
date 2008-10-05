# f-14b radar controls and utilities.

var RangeRadar2 = props.globals.getNode("instrumentation/radar/radar2-range");

var radar_range_control = func(n) {
	# 5, 10, 20, 50, 100, 200
	var range_radar = RangeRadar2.getValue();
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
	RangeRadar2.setValue(range_radar);
}
