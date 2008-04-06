

var h_alpha      = 0.0;

# Dumps the hud by a function of redout #######
var update_hud = func {

	var r_alpha  = getprop("sim[0]/rendering/redout/alpha");
	var h_alpha_new = h_alpha - ( h_alpha * r_alpha );

	setprop("sim[0]/hud/color/alpha", h_alpha_new);

}

var init_hud = func {
	h_alpha  = getprop("sim[0]/hud/color/alpha");
}
