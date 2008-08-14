##### Multiplayer and AI properties watcher.
# Cycles through the list of multiplayers, carriers, tankers and triggers
# radar; ECM/RWR and impact scripts if those features are enabled in our aircraft
# -set.xml file.

# This routine has then to be inited periodicaly called by some our aircraft
# nasal file.  


var watch_i         = 0;
var list_count      = 0;
var radar_enabled   = nil;
var ecm_rwr_enabled = nil;
var impact_enabled  = nil;

var mp_node = props.globals.getNode("ai/models");
var watch_list = [];

var init = func {
	var our_ac_name = getprop("sim/aircraft");
	var mp_system_string = "sim/model/" ~ our_ac_name ~"/mp-systems/";
	var mp_systems_node  = props.globals.getNode(mp_system_string);
	# Check which feature are enabled for our aircraft to avoid computing useless things.
	radar_enabled    = mp_systems_node.getNode("radar-enabled").getValue();
	ecm_rwr_enabled  = mp_systems_node.getNode("ecm-rwr-enabled").getValue();
	combat_enabled   = mp_systems_node.getNode("combat-enabled").getValue();
}


var watch_aimp_models = func {
	# Create an ordered list of carriers; multiplayers and tankers.
	if ( watch_i == 0 ) { list_count = get_list() }
	var target_name = watch_list[watch_i][0];
	var target_index = watch_list[watch_i][1];
	var target_string = "ai/models/" ~ target_name ~ "[" ~ target_index ~ "]";
	# TODO: we should know by ourself how to call the radar function.
	if (radar_enabled) { f14_radar.target_draw(target_string) }


	if (watch_i == (list_count - 1)) {
		watch_i = 0;
	} else {
		watch_i += 1;
	}
}


var get_list = func {
	watch_list = [];
	var raw_list = mp_node.getChildren();
	foreach( var c; raw_list ) {
		var type = c.getName();
		if (type == "carrier" or type == "multiplayer" or type == "tanker") {
			append(watch_list, [type, c.getIndex()]);
		}
	}
	return size(watch_list);
}


