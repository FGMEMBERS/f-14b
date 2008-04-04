



var hud_alpha    = props.globals.getNode("sim[0]/hud/color/alpha");
var redout_alpha = props.globals.getNode("/sim/rendering/redout/alpha");
var h_alpha      = 0.0;

# Dumps the hud by a function of redout #######
var update_hud = func {

	var r_alpha  = redout_alpha.getValue();
	var h_alpha_new = h_alpha - ( h_alpha * r_alpha );

	hud_alpha.setDoubleValue( h_alpha_new );

}

var init_hud = func {
	h_alpha  = hud_alpha.getValue();
}
