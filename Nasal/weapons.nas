var MasterArmLever = props.globals.getNode( "sim/model/f-14b/controls/armament/master-arm-lever" );
var MasterArmSwitch = props.globals.getNode( "sim/model/f-14b/controls/armament/master-arm-switch" );



var master_arm_lever_toggle = func {
	var master_arm_lever = MasterArmLever.getBoolValue();
	var master_arm_switch = MasterArmSwitch.getValue();
	if ( master_arm_lever and master_arm_switch > 1 ) {
			MasterArmSwitch.setValue( 1 );
	}
	MasterArmLever.setBoolValue( ! master_arm_lever );
}

var master_arm_switch = func(a) {
	var master_arm_lever = MasterArmLever.getBoolValue();
	var master_arm_switch = MasterArmSwitch.getValue();
	if (a == 1) {
		if (master_arm_switch == 0) {
			MasterArmSwitch.setDoubleValue(1);
		} elsif (master_arm_switch == 1 and master_arm_lever) {
			MasterArmSwitch.setDoubleValue(2);
		}
	} else {
		if (master_arm_switch == 1) {
			MasterArmSwitch.setDoubleValue(0);
		} elsif (master_arm_switch == 2) {
			MasterArmSwitch.setDoubleValue(1);
		}
	}
}
