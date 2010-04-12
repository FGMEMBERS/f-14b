var AcModel = props.globals.getNode("sim/model/f-14b");
var SwCoolOffLight   = AcModel.getNode("controls/armament/acm-panel-lights/sw-cool-off-light");
var MslPrepOffLight  = AcModel.getNode("controls/armament/acm-panel-lights/msl-prep-off-light");
var StickSelector    = AcModel.getNode("controls/armament/stick-selector");
var ArmSwitch        = AcModel.getNode("controls/armament/master-arm-switch");
var ArmLever         = AcModel.getNode("controls/armament/master-arm-lever");
var GrSwitch         = AcModel.getNode("controls/armament/gun-rate-switch");
var GunRunning       = AcModel.getNode("systems/gun/running");
var GunCountAi       = props.globals.getNode("ai/submodels/submodel[3]/count");
var GunCount         = AcModel.getNode("systems/gun/rounds");
var GunReady         = AcModel.getNode("systems/gun/ready");
var GunStop          = AcModel.getNode("systems/gun/stop", 1);
var GunRateHighLight = AcModel.getNode("controls/armament/acm-panel-lights/gun-rate-high-light" );


aircraft.data.add(StickSelector, ArmLever, ArmSwitch );


# Init
var init = func() {
    update_gun_ready();
	setlistener("controls/armament/trigger", func(Trig) {
        update_gun_ready();
		if ( Trig.getBoolValue()) {
 	        GunStop.setBoolValue(0);
			fire_gun();
		} else {
 	        GunStop.setBoolValue(1);
        }
	}, 0, 1);
}

var fire_gun = func {
	var grun   = GunRunning.getValue();
    var gready = GunReady.getBoolValue();
    var gstop  = GunStop.getBoolValue();
    if (gstop) {
		GunRunning.setBoolValue(0);
		return;
	}
	if (gready and !grun) {
		GunRunning.setBoolValue(1);
		grun = 1;
	}
	if (gready and grun) {
		var real_gcount = GunCountAi.getValue();
        var new_gcount = real_gcount*5;
        if (new_gcount < 5 ) {
            new_gcount = 0;
            GunRunning.setBoolValue(0);
            GunReady.setBoolValue(0);
            GunCount.setValue(new_gcount);
            return;
        }
		GunCount.setValue(new_gcount);
	    settimer(fire_gun, 0.1);
	}
}

var update_gun_ready = func() {
	var ready = 0;
	if (StickSelector.getValue() == 1
        and ArmSwitch.getValue() == 2
        and GunCount.getValue() > 0) {
		ready = 1;
	}
	GunReady.setBoolValue(ready);
}


# Timers for weapons system start and stop animations.
var system_start = func {
	settimer (func { GunRateHighLight.setBoolValue(1); }, 0.3);
    update_gun_ready();
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
	var master_arm_lever = ArmLever.getBoolValue();
	var master_arm_switch = ArmSwitch.getValue();
	if ( master_arm_lever and master_arm_switch > 1 ) {
			ArmSwitch.setValue( 1 );
	}
	ArmLever.setBoolValue( ! master_arm_lever );
	if (master_arm_switch == 2) {
		ArmSwitch.setDoubleValue(1);
		system_stop();
	}
}

var master_arm_switch = func(a) {
	var master_arm_lever = ArmLever.getBoolValue();
	var master_arm_switch = ArmSwitch.getValue();
	if (a == 1) {
		if (master_arm_switch == 0) {
			ArmSwitch.setDoubleValue(1);
		} elsif (master_arm_switch == 1 and master_arm_lever) {
			ArmSwitch.setDoubleValue(2);
			system_start();
		}
	} else {
		if (master_arm_switch == 1) {
			ArmSwitch.setDoubleValue(0);
		} elsif (master_arm_switch == 2) {
			ArmSwitch.setDoubleValue(1);
			system_stop();
		}
	}
}




var arm_selector = func() {
    update_gun_ready();
	# update selected WPS type.
	# if applicable get number of selected MSL.
}
