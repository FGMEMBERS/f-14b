# This generic func is deactivated cause we don't need it and we have a better
# use for "h" keyboard shortcut.
aircraft.HUD.cycle_color = func {}

var pilot_g_alpha      = props.globals.getNode("sim/rendering/redout/alpha", 1);
var hud_intens_control = props.globals.getNode("sim/model/f-14b/controls/hud/intens");
var hud_alpha          = props.globals.getNode("sim[0]/hud/color/alpha", 1);
var view               = props.globals.getNode("sim/current-view/name");

aircraft.data.add("sim/model/f-14b/controls/hud/intens", "sim/hud/current-color");

hud_alpha.setDoubleValue(0);

var update_hud = func {
	var v = view.getValue();
	if (v == "Cockpit View") {
		var h_intens = hud_intens_control.getValue();
		var h_alpha  = hud_alpha.getValue();
		var g_alpha  = pilot_g_alpha.getValue();
		hud_alpha.setDoubleValue(h_intens - g_alpha);

	} else {
		hud_alpha.setDoubleValue(0);
	}
}


