# Automaticaly empties (or loads) corresponding Yasim tanks when deselecting
# (or selecting) external tanks in the Fuel and Payload Menu, or when jettisoning
# external tanks.

var station_2_last_select_state = getprop("sim/weight[2]/selected");
var station_7_last_select_state = getprop("sim/weight[7]/selected");

var station = func(i) {
	var sta = "sim/weight[" ~ i ~ "]";
	var sta_node = props.globals.getNode(sta);
	var sta_selected_node = sta_node.getNode("selected");
	var sta_selected = sta_selected_node.getValue();
	if ((i == 2) and (station_2_last_select_state != sta_selected )) {
		# Station[2] --> Yasim tank[8].
		update_ext_tank("consumables/fuel/tank[8]", sta_selected);
	} elsif ((i == 7) and (station_2_last_select_state != sta_selected)) {
		# Station[7] --> Yasim tank[9].
		update_ext_tank("consumables/fuel/tank[9]", sta_selected);
	}
}

var update_ext_tank = func(tank, selected) {
	#print ("update_ext_tank()");
	var tank_node = props.globals.getNode(tank);
	if (selected == "none") {
		tank_node.getNode("level-gal_us", 1).setValue(0);
		tank_node.getNode("level-lbs", 1).setValue(0);
		tank_node.getNode("selected", 1).setBoolValue(0);
	} else {
		tank_node.getNode("level-gal_us", 1).setValue(267);
		tank_node.getNode("level-lbs", 1).setValue(1714.219);
		tank_node.getNode("selected", 1).setBoolValue(1);
	}
}





setlistener("sim/weight[2]/selected", func { station(2); });
setlistener("sim/weight[7]/selected", func { station(7); });




# Emergency jettison:
# -------------------
#var emerg_jettison_button = props.globals.getNode("sim/model/f-14b/controls/armament/emerg-jettison-switch");

var emerg_jettison = func {
	#if ( ! emerg_jettison_button.getBoolValue() ) {
		#emerg_jettison_button.setBoolValue(1);
		setprop("sim/model/f-14b/instrumentation/warnings/master-caution", 1);
		if (getprop("sim/weight[2]/selected") == "1800 lbs Fuel Tank") {
			setprop("sim/weight[2]/selected", "none");
			setprop("controls/armament/station[2]/jettison-all", 1);
		}
		if (getprop("sim/weight[7]/selected") == "1800 lbs Fuel Tank") {
			setprop("sim/weight[7]/selected", "none");
			setprop("controls/armament/station[7]/jettison-all", 1);
		}
	#} else {
		#emerg_jettison_button.setBoolValue(0);
	#}
}

# Puts the jettisoned tanks models on the ground after impact (THX Vivian Mezza).
var droptank_node = props.globals.getNode("sim/ai/aircraft/impact/droptank", 1);

var droptanks = func(n) {
	if (WOW) { setprop("sim/model/f-14b/controls/armament/tanks-ground-sound", 1) }
	var droptank = droptank_node.getValue();
	var node = props.globals.getNode(n.getValue(), 1);
	#print (" droptank ", droptank, " lon " , node.getNode("impact/longitude-deg").getValue(),);
	geo.put_model("Aircraft/f-14b/Models/Stores/Ext-Tanks/exttank-submodel.xml",
		node.getNode("impact/latitude-deg").getValue(),
		node.getNode("impact/longitude-deg").getValue(),
		node.getNode("impact/elevation-m").getValue()+ 0.4,
		node.getNode("impact/heading-deg").getValue(),
		0,
		0
		);
}

setlistener( "sim/ai/aircraft/impact/droptank", droptanks );
