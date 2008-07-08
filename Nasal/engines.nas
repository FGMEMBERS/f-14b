
#----------------------------------------------------------------------------
# AICS (Air Inlet Control System)
#----------------------------------------------------------------------------

computeAICS = func

  {

    if (CurrentMach < 0.5)
     {
      ramp1 = 0.0;
      ramp3 = 0.0;
      ramp2 = 0.0;
     }
    elsif (CurrentMach < 1.2)
     {
      ramp1 = (CurrentMach - 0.5) * 0.3 / 0.7;
      ramp3 = (CurrentMach - 0.5) * 0.2 / 0.7;
      ramp2 = 0.0;
     }
    elsif (CurrentMach < 2.0)
     {
      ramp1 = (CurrentMach - 1.2) * 0.7 / 0.8 + 0.3;
      ramp3 = (CurrentMach - 1.2) + 0.2;
      ramp2 = (CurrentMach - 1.2) / 0.8;
     }
    else 
     {
      ramp1 = 1.0;
      ramp3 = 1.0;
      ramp2 = 1.0;
     }

    setprop ("/engines/AICS/ramp1", ramp1);
    setprop ("/engines/AICS/ramp2", ramp2);
    setprop ("/engines/AICS/ramp3", ramp3);

  }

#----------------------------------------------------------------------------
# Nozzle opening
#----------------------------------------------------------------------------

# Constant
NozzleSpeed = 1.0;

computeNozzles = func

  {
    engine1Burner = getprop ("engines/engine[0]/afterburner");
    if (engine1Burner == nil) engine1Burner = 0.0;
    engine2Burner = getprop ("engines/engine[1]/afterburner");
    if (engine2Burner == nil) engine2Burner = 0.0;

    if (CurrentMach < 0.45)
      maxSeaLevelIdlenozzle = 1.0;
    elsif (CurrentMach >= 0.45 and CurrentMach < 0.8)
      maxSeaLevelIdlenozzle = 1.0 * (0.8 - CurrentMach) / 0.35;
    else 
      maxSeaLevelIdlenozzle = 0.0;

    if (Throttle < ThrottleIdle)
      {
       if (getprop ("gear/gear[0]/position-norm") == 1.0) #gear is down
        {
         if (WOW) idleNozzleTarget = 1.0;
         else idleNozzleTarget = 0.26;
        } # if gear is down
       else
        {
         if (CurrentAlt <= 30000.0)
          idleNozzleTarget = 1.0 + (0.15 - maxSeaLevelIdlenozzle) * CurrentAlt / 30000.0;
         else 
          idleNozzleTarget = 0.15;
        } 

        Nozzle1Target = idleNozzleTarget;
        Nozzle2Target = idleNozzleTarget;

       } # if throttle idle
      else
       {
         
         Nozzle1Target = engine1Burner;
         Nozzle2Target = engine2Burner;

       }

  } # end computeNozzles

#----------------------------------------------------------------------------
# APC - Approach Power Compensator
#----------------------------------------------------------------------------
# 123 kts 10,3 deg AoA
# engaged by:    - Throttle Mode Lever
#                - keystroke "a" (toggle)
# disengaged by: - Throttle Mode Lever
#                - keystroke "a" (toggle)
#                - WoW
#                - throttle levers at ~ idle or MIL
#                - autopilot emer disengage padle

var APCengaged = props.globals.getNode("sim/model/f-14b/systems/apc/engaged");
var engaded = 0;
var SpeedSlope = (146 - 114) / 16000.0; # 0.001555556 

var gear_down = props.globals.getNode("controls/gear/gear-down");
var disengaged_light = props.globals.getNode("sim/model/f-14b/systems/apc/self-disengaged-light");

var computeAPC = func {
	if (APCengaged.getBoolValue()) { 
		# override throttles
		if ( WOW or ! gear_down.getBoolValue()) {
			# test throttles in range
			APC_off()
		}
	} else {
		# duplicate throttles
	}
}

var toggleAPC = func {
	engaged = APCengaged.getBoolValue();
	if ( ! engaged ) APC_on() else APC_off();
}

var APC_on = func {
	if ( ! WOW and gear_down.getBoolValue()) {
		setprop ("/autopilot/locks/speed", "speed-with-throttle");
		speedtarget = (getprop ("/yasim/gross-weight-lbs") - 41780.0) * SpeedSlope + 114.0;
		setprop ("/autopilot/settings/target-speed-kt", speedtarget);
		APCengaged.setBoolValue(1);
		disengaged_light.setBoolValue(0);
		print ("APC on()");
	}
}

var APC_off = func {
	setprop ("/autopilot/locks/speed", "");
	setprop ("/autopilot/settings/target-speed-kt", 0.0);
	APCengaged.setBoolValue(0);
	disengaged_light.setBoolValue(1);
	settimer(func { disengaged_light.setBoolValue(0); }, 10);	
	print ("APC off()");
}





