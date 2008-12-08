# 30 - 88 Mz
# 108 - 174 Mz
# 225 - 400 Mz
# 20 preset channels

# Modes:     0= off,
#            1= T/R,
#            2= T/R+Guard,
#            3= DF,
#            4= test

# Functions: 0= Guard 243 Mhz disable all other funct,
#            1= Man: permits manual tunning
#            2= G: should tunes to the guard freq in the band the receiver was last tuned, not used yet
#            3= Preset: displays the selected Channel
#            4= Read: displays the frequency instead of the preset channel number
#                    permits preset channel frequency manual tunning.
#            5= Load: place the displayed freq in the memory for the selected preset channel.

var Radio        = props.globals.getNode("sim/model/f-14b/instrumentation/an-arc-182v");
var Mode         = Radio.getNode("mode");
var Function     = Radio.getNode("function");
var Volume       = Radio.getNode("volume");
var Brightness   = Radio.getNode("brightness");
var Preset       = Radio.getNode("preset");
var Presets      = Radio.getNode("presets");
var Selected_F   = Radio.getNode("frequencies/selected-mhz");
var Load_State   = Radio.getNode("load-state", 1);
var Nav1_Freq    = props.globals.getNode("instrumentation/nav[0]/frequencies/selected-mhz");
var Nav1_Volume  = props.globals.getNode("instrumentation/nav[0]/volume");
var Comm1_Volume = props.globals.getNode("instrumentation/comm[0]/volume");
var Comm1_Freq   = props.globals.getNode("instrumentation/comm[0]/frequencies/selected-mhz");
var Comm1_Freq_stdby = props.globals.getNode("instrumentation/comm[0]/frequencies/standby-mhz");

var comm1_f = 0.0;
var comm1_f_stb = 0.0;
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
	if (mode > 4) {
		mode = 4;
	} elsif (mode < 0) {
		mode = 0;	
	}
	Mode.setValue(mode);
	if (mode == 1 or mode == 2) {
		cur_f = Selected_F.getValue();
		Nav1_Freq.setValue(0);
		Comm1_Freq.setValue(cur_f/1000);
		Nav1_Volume.setValue(0);
		Comm1_Volume.setValue(volume);
	} elsif (mode == 3) {
		if (old_mode == 4) {
			Selected_F.setValue(mode_stby);
		}
		Nav1_Freq.setValue(cur_f/1000);
		Comm1_Freq.setValue(0);
		Nav1_Volume.setValue(volume);
		Comm1_Volume.setValue(0);
	} elsif (mode == 4) {
		if (old_mode == 3) {
			cur_f = Selected_F.getValue();
			mode_stby = cur_f;
			Selected_F.setValue(888888); 
			Nav1_Freq.setValue(0);
			Comm1_Freq.setValue(0);
			Nav1_Volume.setValue(0);
			Comm1_Volume.setValue(0);
		}
	} else {	 
		Selected_F.setValue(0);
		Nav1_Freq.setValue(0);
		Comm1_Freq.setValue(0);
		Nav1_Volume.setValue(0);
		Comm1_Volume.setValue(0);
	}
}


var set_function = func(step) {
	mode = Mode.getValue();
	function = Function.getValue();
	var old_function = function;
	function += step;
	if (function > 5) {
		function = 5;
	} elsif (function < 0) {
		function = 0;	
	}
	Function.setValue(function);
	if (function == 0 and old_function == 1) {
		comm1_f = Comm1_Freq.getValue();
		Comm1_Freq.setValue(243.0);
		Comm1_Freq_stdby.setValue(comm1_f);
		Selected_F.setValue(243.0*1000);
	} elsif  (function == 1 and old_function == 0) {
		comm1_f_stb = Comm1_Freq_stdby.getValue();
		Comm1_Freq_stdby.setValue(243.0);
		Comm1_Freq.setValue(comm1_f_stb);
		Selected_F.setValue(comm1_f_stb*1000);
	} elsif ( function == 5 and mode != 0 and mode != 4) {
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

var set_channel = func(step) {
	mode = Mode.getValue();
	function = Function.getValue();
	if ((mode != 0 and mode != 4) and (function == 3 or function == 4)) {
		preset = Preset.getValue();
		preset += step;
		if (preset > 20) {
			preset = 20;
		} elsif (preset < 0) {
			preset = 0;	
		}
		Preset.setValue(preset);
		var path = "frequency["~preset~"]";
		preset_freq = Presets.getNode(path).getValue();
		Selected_F.setValue(preset_freq*1000);
		if (mode == 1 or mode == 2) {
			Comm1_Freq.setValue(preset_freq);
		} elsif (mode == 3) {
			Nav1_Freq.setValue(preset_freq);
		}
	}
}

var adj_freq = func(step) {
	mode = Mode.getValue();
	function = Function.getValue();
	if ((mode == 1 or mode == 2 or mode == 3)  and (function == 1 or function == 4)) {
		cur_f = Selected_F.getValue();
		var result = cur_f + step;
		result = test_boundaries(step, result);
		Selected_F.setValue(result);
	}
}

var test_boundaries = func(step, result) {
	if (step > 0) {
		if (result > 88000 and result < 108000) {
			result = 108000;
		} elsif (result > 174000 and result < 225000) {
			result = 225000;
		} elsif (result > 400000) {
			result = 400000;
		}
	} else {
		if (result < 225000 and result > 174000) {
			result = 174000;
		} elsif (result < 108000 and result > 88000) {
			result = 88000;
		} elsif (result < 30000) {
			result = 30000;
		}
	}
	return(result);
}

var set_volume = func(step) {
	volume = Volume.getValue();
	mode = Mode.getValue();
	volume += step;
	if (volume < 0) { volume = 0 }
	if (volume > 1) { volume = 1 }
	Volume.setValue(volume);
	if (mode == 3) {
		Nav1_Volume.setValue(volume);
		Comm1_Volume.setValue(0);
	} elsif  (mode != 0) {
		Nav1_Volume.setValue(0);
		Comm1_Volume.setValue(volume);
	} else {
		Nav1_Volume.setValue(0);
		Comm1_Volume.setValue(0);
	}
}

var init = func() {
	mode = Mode.getValue();
	preset = Preset.getValue();
	var path = "frequency["~preset~"]";
	preset_freq = Presets.getNode(path).getValue();
	Selected_F.setValue(preset_freq*1000);
	if (mode == 1 or mode == 2) {
		Comm1_Freq.setValue(preset_freq);
	} elsif (mode == 3) {
		Nav1_Freq.setValue(preset_freq);
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
aircraft.data.add(Preset, Mode, Function, p0, p1, p2, p3, p4, p5,
	p6, p7, p8, p9, p10, p11, p12, p13, p14, p14, p15, p16, p17, p18, p19);
