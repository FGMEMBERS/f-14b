# 225 - 400 Mz
# 20 preset channels

# Modes:     0 = Off,
#            1 = Main, Main tranceiver is energized permitting normal transmission
#                and reception.
#            2 = Both, Energizes both the main tranceiver and the guard receiver.
#            3 = DF, Function Direction Finder not enabled on this radio.

# Functions: 0 = Preset: Enables the Chan Set Knob
#            1 = Manual: permits manual tunning. Preset selections not available.
#            2 = Guard, main tranceiver energized and shifted to guard frequency (243 Mhz)
#                permitting transmission and reception.

# Button Load: place the current tunned freq in the memory for the selected preset channel.
# Button Read: switch between frequency and preset channel number display.

var Radio        = props.globals.getNode("sim/model/f-14b/instrumentation/an-arc-159v1");
var Mode         = Radio.getNode("mode");
var Function     = Radio.getNode("function");
var Volume       = Radio.getNode("volume");
var Brightness   = Radio.getNode("brightness");
var Preset       = Radio.getNode("preset");
var Presets      = Radio.getNode("presets");
var Selected_F   = Radio.getNode("frequencies/selected-mhz");
var Load_State   = Radio.getNode("load-state", 1);
var Comm2_Volume = props.globals.getNode("instrumentation/comm[1]/volume");
var Comm2_Freq   = props.globals.getNode("instrumentation/comm[1]/frequencies/selected-mhz");
var Comm2_Freq_stdby = props.globals.getNode("instrumentation/comm[1]/frequencies/standby-mhz");

var comm2_f = 0.0;
var comm2_f_stb = 0.0;
var cur_f = 0.0;
var mode = 0.0;
var preset = 0;
var preset_freq = 0.0;
var mode_stby = 0;

var set_mode = func(step) {
	mode = Mode.getValue();
	var old_mode = mode;
	volume = Volume.getValue();
	mode += step;
	if (mode > 3) {
		mode = 3;
	} elsif (mode < 0) {
		mode = 0;	
	}
	Mode.setValue(mode);
	if ((mode == 1 and old_mode == 0) ) {
		# from OFF to MAIN
		preset = Preset.getValue();
		var path = "frequency["~preset~"]";
		preset_freq = Presets.getNode(path).getValue();
		Selected_F.setValue(preset_freq*1000);
		cur_f = Selected_F.getValue();
		Comm2_Freq.setValue(cur_f/1000);
		Comm2_Volume.setValue(volume);
	} elsif (mode == 0) {
		# from MAIN to OFF
		Selected_F.setValue(0);
		Comm2_Freq.setValue(0);
		Comm2_Volume.setValue(0);
	}
}


var set_function = func(step) {
	mode = Mode.getValue();
	function = Function.getValue();
	var old_function = function;
	function += step;
	if (function > 2) {
		function = 2;
	} elsif (function < 0) {
		function = 0;	
	}
	Function.setValue(function);
	if  (function == 1 and old_function == 2) {
		# from GUARD to MANUAL 
		comm2_f = Comm2_Freq_stdby.getValue();
		Comm2_Freq.setValue(comm2_f);
		Selected_F.setValue(comm2_f*1000);
		Comm2_Freq_stdby.setValue(0.0);
	} elsif ( function == 2 and old_function == 1 and mode > 0 ) {
		# from MANUAL to GUARD
		comm2_f = Selected_F.getValue()/1000;
		Comm2_Freq.setValue(243.0);
		Comm2_Freq_stdby.setValue(comm2_f);
		Selected_F.setValue(243.0*1000);
	}
}

var set_channel = func(step) {
	mode = Mode.getValue();
	function = Function.getValue();
	preset = Preset.getValue();
	preset += step;
	if (preset > 19) {
		preset = 19;
	} elsif (preset < 0) {
		preset = 0;	
	}
	Preset.setValue(preset);
	var path = "frequency["~preset~"]";
	preset_freq = Presets.getNode(path).getValue();
	if ((mode == 1 or mode == 2) and function == 0) {
		Selected_F.setValue(preset_freq*1000);
		Comm2_Freq.setValue(preset_freq);
	}
}

var adj_freq = func(step) {
	mode = Mode.getValue();
	function = Function.getValue();
	if ((mode == 1 or mode == 2 or mode == 3)  and (function == 1 or function == 2)) {
		cur_f = Selected_F.getValue();
		var result = cur_f + step;
		result = test_boundaries(step, result);
		Selected_F.setValue(result);
	}
}

var test_boundaries = func(step, result) {
	if (result > 400000) {
		result = 400000;
	} elsif (result < 225000) {
		result = 225000;
	}
	return(result);
}

var load_freq = func() {
	mode = Mode.getValue();
	function = Function.getValue();
	if ( function == 0 and mode > 0 ) {
		cur_f = Selected_F.getValue();
		preset = Preset.getValue();
		var path = "frequency["~preset~"]";
		Presets.getNode(path).setValue(cur_f/1000);
		Load_State.setValue(1);
		settimer(func {
			Load_State.setValue(0);
			set_function(-1);
		}, 0.5);
	}
}

var set_volume = func(step) {
	volume = Volume.getValue();
	mode = Mode.getValue();
	volume += step;
	if (volume < 0) { volume = 0 }
	if (volume > 1) { volume = 1 }
	Volume.setValue(volume);
	Comm2_Volume.setValue(volume);
}


var init = func() {
	mode = Mode.getValue();
	function = Function.getValue();
	preset = Preset.getValue();
	var path = "frequency["~preset~"]";
	preset_freq = Presets.getNode(path).getValue();
	if (function == 2) {
		# 243 Mhz
		Comm2_Freq.setValue(243.0);
		Selected_F.setValue(243.0*1000);
	} else {
		Comm2_Freq.setValue(preset_freq);
		Selected_F.setValue(preset_freq*1000);
	}
	if (mode == 0) {
		Comm2_Freq.setValue(0.0);
		Comm2_Freq_stdby.setValue(0.0);
	}
}


var p0 = Radio.getNode("presets/frequency[0]");
var p1 = Radio.getNode("presets/frequency[1]");
var p2 = Radio.getNode("presets/frequency[2]");
var p3 = Radio.getNode("presets/frequency[3]");
var p4 = Radio.getNode("presets/frequency[4]");
var p5 = Radio.getNode("presets/frequency[5]");
var p6 = Radio.getNode("presets/frequency[6]");
var p7 = Radio.getNode("presets/frequency[7]");
var p8 = Radio.getNode("presets/frequency[8]");
var p9 = Radio.getNode("presets/frequency[9]");
var p10 = Radio.getNode("presets/frequency[10]");
var p11 = Radio.getNode("presets/frequency[11]");
var p12 = Radio.getNode("presets/frequency[12]");
var p13 = Radio.getNode("presets/frequency[13]");
var p14 = Radio.getNode("presets/frequency[14]");
var p15 = Radio.getNode("presets/frequency[15]");
var p16 = Radio.getNode("presets/frequency[16]");
var p17 = Radio.getNode("presets/frequency[17]");
var p18 = Radio.getNode("presets/frequency[18]");
var p19 = Radio.getNode("presets/frequency[19]");
aircraft.data.add(Preset, Mode, Function, Comm2_Freq, Comm2_Freq_stdby, p0, p1, p2, p3, p4, p5,
	p6, p7, p8, p9, p10, p11, p12, p13, p14, p14, p15, p16, p17, p18, p19);
