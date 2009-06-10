# f-14b Armament system.

var MasterArmLever = props.globals.getNode( "sim/model/f-14b/controls/armament/master-arm-lever" );
var MasterArmSwitch = props.globals.getNode( "sim/model/f-14b/controls/armament/master-arm-switch" );
var GunRateHighLight = props.globals.getNode( "sim/model/f-14b/controls/armament/acm-panel-lights/gun-rate-high-light" );
var SwCoolOffLight = props.globals.getNode( "sim/model/f-14b/controls/armament/acm-panel-lights/sw-cool-off-light" );
var MslPrepOffLight = props.globals.getNode( "sim/model/f-14b/controls/armament/acm-panel-lights/msl-prep-off-light" );
var SystemOnOff = props.globals.getNode( "sim/model/f-14b/controls/armament/system-on-off");
var StickSelector = props.globals.getNode( "sim/model/f-14b/controls/armament/stick-selector");

aircraft.data.add(StickSelector, MasterArmLever, MasterArmSwitch );

var system_start = func {
	settimer (func { GunRateHighLight.setBoolValue(1); }, 0.3);
	settimer (func { SwCoolOffLight.setBoolValue(1); }, 0.6);
	settimer (func { MslPrepOffLight.setBoolValue(1); }, 2);
}
var system_stop = func {
	GunRateHighLight.setBoolValue(0);
	settimer (func { SwCoolOffLight.setBoolValue(0); }, 0.6);
	settimer (func { MslPrepOffLight.setBoolValue(0); }, 1.2);
}


# Controls
var master_arm_lever_toggle = func {
	var master_arm_lever = MasterArmLever.getBoolValue();
	var master_arm_switch = MasterArmSwitch.getValue();
	if ( master_arm_lever and master_arm_switch > 1 ) {
			MasterArmSwitch.setValue( 1 );
	}
	MasterArmLever.setBoolValue( ! master_arm_lever );
	if (master_arm_switch == 2) {
		MasterArmSwitch.setDoubleValue(1);
		system_stop();
	}
}

var master_arm_switch = func(a) {
	var master_arm_lever = MasterArmLever.getBoolValue();
	var master_arm_switch = MasterArmSwitch.getValue();
	if (a == 1) {
		if (master_arm_switch == 0) {
			MasterArmSwitch.setDoubleValue(1);
		} elsif (master_arm_switch == 1 and master_arm_lever) {
			MasterArmSwitch.setDoubleValue(2);
			system_start();
		}
	} else {
		if (master_arm_switch == 1) {
			MasterArmSwitch.setDoubleValue(0);
		} elsif (master_arm_switch == 2) {
			MasterArmSwitch.setDoubleValue(1);
			system_stop();
		}
	}
}

var arm_selector = func(n) {
	var master_arm_switch = MasterArmSwitch.getValue();
	# update selected WPS type.
	# if applicable get number of selected MSL.
}
