var ExtTanks = props.globals.getNode("sim/model/f-14b/systems/external-loads/external-tanks");
var WeaponsSet = props.globals.getNode("sim/model/f-14b/systems/external-loads/external-load-set");
var WeaponsWeight = props.globals.getNode("sim/model/f-14b/systems/external-loads/weapons-weight", 1);
var PylonsWeight = props.globals.getNode("sim/model/f-14b/systems/external-loads/pylons-weight", 1);
var S0 = nil;
var S1 = nil;
var S2 = nil;
var S3 = nil;
var S4 = nil;
var S5 = nil;
var S6 = nil;
var S7 = nil;
var S8 = nil;
var S9 = nil;
var droptank_node = props.globals.getNode("sim/ai/aircraft/impact/droptank", 1);

var ext_loads_dlg = gui.Dialog.new("dialog","Aircraft/f-14b/Dialogs/external-loads.xml");


var ext_loads_init = func() {
	S0 = Station.new(0, 0);
	S1 = Station.new(1, 0);
	S2 = Station.new(2, 1);
	S3 = Station.new(3, 2);
	S4 = Station.new(4, 3);
	S5 = Station.new(5, 4);
	S6 = Station.new(6, 5);
	S7 = Station.new(7, 6);
	S8 = Station.new(8, 7);
	S9 = Station.new(9, 7);
	setprop("sim/menubar/default/menu[5]/item[0]/enabled", 0);
}


var ext_loads_set = func(s) {
	# Clean, FAD, FAD light, FAD heavy, Bombcat
	WeaponsSet.setValue(s);
	if ( s == "Clean" ) {
		PylonsWeight.setValue(0);
		WeaponsWeight.setValue(0);
		S0.set_type("-");
		S1.set_type("-");
		S1.set_weight_lb(0);
		S3.set_type("-");
		S3.set_weight_lb(0);
		S4.set_type("-");
		S4.set_weight_lb(0);
		S5.set_type("-");
		S5.set_weight_lb(0);
		S6.set_type("-");
		S6.set_weight_lb(0);
		S8.set_type("-");
		S9.set_type("-");
		S9.set_weight_lb(0);
	} elsif ( s == "FAD" ) {
		PylonsWeight.setValue(53 + 340 + 1200 + 53 + 340);
		WeaponsWeight.setValue(191 + 510 + 1020 + 1020 + 1020 + 1020 + 510 + 191);
		S0.set_type("AIM-9");
		S1.set_type("AIM-7");
		S1.set_weight_lb(53 + 340 + 191 + 510); # AIM-9rail, wing pylon, AIM-9M, AIM-7M 
		S3.set_type("AIM-54");
		S3.set_weight_lb(300 + 1020); # central pylon, AIM-54 
		S4.set_type("AIM-54");
		S4.set_weight_lb(300 + 1020); # central pylon, AIM-54 
		S5.set_type("AIM-54");
		S5.set_weight_lb(300 + 1020); # central pylon, AIM-54 
		S6.set_type("AIM-54");
		S6.set_weight_lb(300 + 1020); # central pylon, AIM-54 
		S8.set_type("AIM-7");
		S9.set_type("AIM-9");
		S9.set_weight_lb(53 + 340 + 191 + 510); # AIM-9rail, wing pylon, AIM-9M, AIM-7M 
	} elsif ( s == "FAD light" ) {
		PylonsWeight.setValue(53 + 340 + 53 + 53 + 53 + 340);
		WeaponsWeight.setValue(191 + 510 + 510 + 510 + 510 + 510 + 510 + 191);
		S0.set_type("AIM-9");
		S1.set_type("AIM-9");
		S1.set_weight_lb(53 + 340 + 191 + 53 + 191); # AIM-9rail, wing pylon, AIM-9M, AIM-9rail, AIM-9M 
		S3.set_type("AIM-7");
		S3.set_weight_lb(510); # AIM-7 
		S4.set_type("AIM-7");
		S4.set_weight_lb(510); # AIM-7 
		S5.set_type("AIM-7");
		S5.set_weight_lb(510); # AIM-7 
		S6.set_type("AIM-7");
		S6.set_weight_lb(510); # AIM-7 
		S8.set_type("AIM-9");
		S9.set_type("AIM-9");
		S9.set_weight_lb(53 + 340 + 191 + 53 + 191); # AIM-9rail, wing pylon, AIM-9M, AIM-9rail, AIM-9M 
	} elsif ( s == "FAD heavy" ) {
		PylonsWeight.setValue(53 + 340 + 90 + 1200 + 53 + 340 + 90);
		WeaponsWeight.setValue(191 + 1020 + 1020 + 1020 + 1020 + 1020 + 1020 + 191);
		S0.set_type("AIM-9");
		S1.set_type("AIM-54");
		S1.set_weight_lb(53 + 340 + 191 + 90 + 1020); # AIM-9rail, wing pylon, AIM-9M, AIM-54launcher, AIM-54 
		S3.set_type("AIM-54");
		S3.set_weight_lb(300 + 1020); # central pylon, AIM-54 
		S4.set_type("AIM-54");
		S4.set_weight_lb(300 + 1020); # central pylon, AIM-54 
		S5.set_type("AIM-54");
		S5.set_weight_lb(300 + 1020); # central pylon, AIM-54 
		S6.set_type("AIM-54");
		S6.set_weight_lb(300 + 1020); # central pylon, AIM-54 
		S8.set_type("AIM-54");
		S9.set_type("AIM-9");
		S9.set_weight_lb(53 + 340 + 191 + 90 + 1020); # AIM-9rail, wing pylon, AIM-9M, AIM-54launcher, AIM-54 
	} elsif ( s == "Bombcat" ) {
		PylonsWeight.setValue(53 + 340 + 90 + 1200 + 53 + 340 + 90);
		WeaponsWeight.setValue(191 + 510 + 1000 + 1000 + 1000 + 1000 + 510 + 191);
		S0.set_type("AIM-9");
		S1.set_type("AIM-7");
		S1.set_weight_lb(53 + 340 + 191 + 510); # AIM-9rail, wing pylon, AIM-9M, AIM-7M 
		S3.set_type("MK-83");
		S3.set_weight_lb(300 + 1000); # central pylon, MK-83 
		S4.set_type("MK-83");
		S4.set_weight_lb(300 + 1000); # central pylon, MK-83 
		S5.set_type("MK-83");
		S5.set_weight_lb(300 + 1000); # central pylon, MK-83 
		S6.set_type("MK-83");
		S6.set_weight_lb(300 + 1000); # central pylon, MK-83 
		S8.set_type("AIM-7");
		S9.set_type("AIM-9");
		S9.set_weight_lb(53 + 340 + 191 + 510); # AIM-9rail, wing pylon, AIM-9M, AIM-7M 
	}
}

# Empties (or loads) corresponding Yasim tanks when de-selecting (or selecting)
# external tanks in the External Loads Menu, or when jettisoning external tanks.
# See fuel-system.nas for Left_External.set_level(), Left_External.set_selected()
# and such.

var toggle_ext_tank_selected = func() {
	var ext_tanks = ! ExtTanks.getBoolValue();
	ExtTanks.setBoolValue( ext_tanks );
	if ( ext_tanks ) {
		S2.set_type("external tank");
		S7.set_type("external tank");
		S2.set_weight_lb(250);            # lbs, empty tank weight.
		S7.set_weight_lb(250);
		Left_External.set_level(267);     # US gals, tank fuel contents.
		Right_External.set_level(267);
		Left_External.set_selected(1);
		Right_External.set_selected(1);
	} else {
		S2.set_type("-");
		S7.set_type("-");
		S2.set_weight_lb(0);
		S7.set_weight_lb(0);
		Left_External.set_level(0);
		Right_External.set_level(0);
		Left_External.set_selected(0);
		Right_External.set_selected(0);
	}
}


# Emergency jettison:
# -------------------

var emerg_jettison = func {
	setprop("sim/model/f-14b/instrumentation/warnings/master-caution", 1);
	if (S2.get_type() == "external tank") {
		S2.set_type("-");
		S2.set_weight_lb(0);
		setprop("controls/armament/station[2]/jettison-all", 1);
		Left_External.set_level(0);
		Left_External.set_selected(0);
	}
	if (S7.get_type() == "external tank") {
		S7.set_type("-");
		S7.set_weight_lb(0);
		setprop("controls/armament/station[7]/jettison-all", 1);
		Right_External.set_level(0);
		Right_External.set_selected(0);
	}
	ExtTanks.setBoolValue(0);
}

# Puts the jettisoned tanks models on the ground after impact (THX Vivian Mezza).

var droptanks = func(n) {
	if (WOW) { setprop("sim/model/f-14b/controls/armament/tanks-ground-sound", 1) }
	var droptank = droptank_node.getValue();
	var node = props.globals.getNode(n.getValue(), 1);
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



Station = {
	new : func (number, weight_number){
		var obj = {parents : [Station] };
		obj.prop = props.globals.getNode("sim/model/f-14b/systems/external-loads/").getChild ("station", number , 1);
		obj.type = obj.prop.getNode("type", 1);
		obj.weight = props.globals.getNode("sim").getChild ("weight", weight_number , 1);
		obj.weight_lb = obj.weight.getNode("weight-lb");
		append(Station.list, obj);
		return obj;
	},
	set_type : func (t) {
		me.type.setValue(t);
	},
	get_type : func () {
		return me.type.getValue();	
	},
	add_weight_lb : func (t) {
		w = me.weight_lb.getValue();
		me.weight_lb.setValue( w + t );
	},
	set_weight_lb : func (t) {
		me.weight_lb.setValue(t);	
	},
	get_weight_lb : func () {
		return me.weight_lb.getValue();	
	},
	list : [],
};
