#----------------------------------------------------------------------------
# Sweep angle computer     
# For display purposes only ! No variable sweep on YaSim
#----------------------------------------------------------------------------

#Constants
MachLo = 0.7;
MachHi = 1.4;
MachSweepRange = MachHi - MachLo;
OverSweepAngle = 65.0;
SweepRate = 2.0;    # degrees per second
SweepVsMachLo = 20.0; 
SweepVsMachHi = 60.0;

# Functions

toggleOversweep = func

 {
   if (WOW and ! OverSweep)
     {
	   # Flaps/sweep interlock      
       #do not move the wings until auxiliary flaps are in 
       if (getprop ("/controls/flight/auxFlaps") > 0.05) return;
	   OverSweep = true;
       AutoSweep = false;
       WingSweep = 1.2;
	  
     }
   elsif (OverSweep)
    {
	  AutoSweep = true;
      WingSweep = 0.0;
      OverSweep = false;
	}
 }

computeSweep = func 
{
   if (AutoSweep) {

      current_mach = getprop ("/velocities/mach");
           
      # Flaps/sweep interlock      
      #do not move the wings until auxiliary flaps are in 
      
      if (getprop ("/controls/flight/auxFlaps") > 0.05) return;
      
      # Sweep vs. Mach motion
      
      if (current_mach <= MachLo) WingSweep = 0.0;       
      elsif (current_mach < MachHi) 
            WingSweep = (current_mach - MachLo) / MachSweepRange;         
      else WingSweep = 1.0;
      
   } # end if (AutoSweep)
 
} # end computeSweep
