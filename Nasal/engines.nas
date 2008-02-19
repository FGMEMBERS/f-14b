
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
