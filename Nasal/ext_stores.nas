# Automaticaly empties (or loads) corresponding Yasim tanks when deselecting
# (or selecting) external tanks in the Fuel and Payload Menu, or when jettisoning
# external tanks.

var station = func(i) {
	var sta = "sim/weight[" ~ i ~ "]";
	var sta_node = props.globals.getNode(sta);
	var sta_selected_node = sta_node.getNode("selected");
	var sta_selected = sta_selected_node.getValue();
	if ( i == 2) {
		# Station[2] --> Yasim tank[6].
		update_ext_tank("consumables/fuel/tank[6]", sta_selected);
	} elsif ( i == 7 ) {
		# Station[7] --> Yasim tank[7].
		update_ext_tank("consumables/fuel/tank[7]", sta_selected);
	}
}

var update_ext_tank = func(tank, selected) {
	var tank_node = props.globals.getNode(tank);
	if (selected == "none") {
		tank_node.getNode("level-gal_us", 1).setValue(0);
		tank_node.getNode("level-lbs", 1).setValue(0);
		tank_node.getNode("selected", 1).setBoolValue(0);
	} else {
		tank_node.getNode("level-gal_us", 1).setValue(297.6190304);
		tank_node.getNode("level-lbs", 1).setValue(2000);
		tank_node.getNode("selected", 1).setBoolValue(1);
	}
}





setlistener("sim/weight[2]/selected", func { station(2); });
setlistener("sim/weight[7]/selected", func { station(7); });




# Emergency jettison:
# -------------------
var emerg_jettison_button = props.globals.getNode("sim/model/f-14b/controls/armament/emerg-jettison-switch");

var emerg_jettison = func {
	if ( ! emerg_jettison_button.getBoolValue() ) {
		emerg_jettison_button.setBoolValue(1);
		setprop("sim/model/f-14b/instrumentation/warnings/master-caution", 1);
		if (getprop("sim/weight[2]/selected") == "2000 lbs Fuel Tank") {
			setprop("sim/weight[2]/selected", "none");
			setprop("controls/armament/station[2]/jettison-all", 1);
		}
		if (getprop("sim/weight[7]/selected") == "2000 lbs Fuel Tank") {
			setprop("sim/weight[7]/selected", "none");
			setprop("controls/armament/station[7]/jettison-all", 1);
		}
	} else {
		emerg_jettison_button.setBoolValue(0);
	}
}

# Puts the jettisoned tanks models on the ground after impact (THX Vivian Mezza).
var droptank_node = props.globals.getNode("sim/ai/aircraft/impact/droptank", 1);

var droptanks = func {
	if (WOW) { setprop("sim/model/f-14b/controls/armament/tanks-ground-sound", 1) }
	var droptank = droptank_node.getValue();
	var node = props.globals.getNode(cmdarg().getValue(), 1);
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

setlistener( "sim/ai/aircraft/impact/droptank", func { droptanks(); });
