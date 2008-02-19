#----------------------------------------------------------------------------
# Adverse aerodynamic phenomena simulation (spin, roll inversion ...)
#----------------------------------------------------------------------------

computeAdverse = func

 {

   if (Alpha < 25.0)
    {
      setprop ("/controls/flight/adverse/pitch", 0.5 * SASpitch + ElevatorTrim);
      setprop ("/controls/flight/adverse/roll", 0.5 * SASroll);
	  setprop ("/controls/flight/adverse/yaw",  0.0);
	}
   else
    {
	  setprop ("/controls/flight/adverse/pitch", - 1.0);
      setprop ("/controls/flight/adverse/roll", getprop ("/orientation/yaw-rate-degps") / 60 );
	 # setprop ("/controls/flight/adverse/yaw", - getprop ("/orientation/roll-rate-degps") / 60.0 );
	  setprop ("/controls/flight/adverse/yaw", 0.0);


	}

 }

