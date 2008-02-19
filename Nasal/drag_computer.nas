#----------------------------------------------------------------------------
# Drag Computer     
#----------------------------------------------------------------------------

#Constants
TransitionMach = 1.0;
HiMach = 1.3;

LoMachDrag = 0.5;
TransitionMachDrag = 1.0;
HiMachDrag = 0.0;

HiDragFactor = (HiMachDrag - TransitionMachDrag) / (HiMach - TransitionMach);
HiMachDragOrigin = TransitionMachDrag - TransitionMach * HiDragFactor;

SpeedBrakesIncrement = 0.2;

# Functions


speedBrakesOut = func

 {
  
   SpeedBrakes += SpeedBrakesIncrement;
   if (SpeedBrakes > 1.0) SpeedBrakes = 1.0;
   setprop ("/controls/flight/speedbrake", SpeedBrakes);

 }


speedBrakesIn = func

 {
  
   SpeedBrakes -= SpeedBrakesIncrement;
   if (SpeedBrakes < 0.0) SpeedBrakes = 0.0;
   setprop ("/controls/flight/speedbrake", SpeedBrakes);

 }


computeDrag = func 

{
  gearExtension = getprop ("/gear/gear[1]/position-norm");

  if (gearExtension != nil)
    {
      if (gearExtension > 0.8)
        LoMachDrag = 1.0;
      else
        LoMachDrag = 0.5;
	}

  LoDragFactor = (TransitionMachDrag - LoMachDrag) / TransitionMach;
    
  if (CurrentMach == nil) CurrentMach = 0.0; 


     if (CurrentMach <= TransitionMach)           
		 setprop ("/f-14/drag", 
		          CurrentMach * LoDragFactor + LoMachDrag);
	   
	 elsif (CurrentMach <= HiMach)	   
		 setprop ("/f-14/drag", 
		          CurrentMach * HiDragFactor + TransitionMachDrag);
	   
	 else 
	   setprop ("/f-14/drag", 0.0);

      
} # end computeDrag
