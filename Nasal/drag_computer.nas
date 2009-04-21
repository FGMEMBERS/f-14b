#----------------------------------------------------------------------------
# Drag Computer     
#----------------------------------------------------------------------------

#Constants
var TransitionMach     = 1;
var HiMach             = 1.3;
var LoMachDrag         = 0.5;
var TransitionMachDrag = 1;
var HiMachDrag         = 0;

var HiDragFactor = (HiMachDrag - TransitionMachDrag) / (HiMach - TransitionMach);
var HiMachDragOrigin = TransitionMachDrag - TransitionMach * HiDragFactor;

var SpeedBrakesIncrement = 0.2;
var SpeedBrakes = 0;
var gearExtension = nil;


# Functions
var speedBrakesOut = func {
	SpeedBrakes += SpeedBrakesIncrement;
	if ( SpeedBrakes > 1 ) { SpeedBrakes = 1 }
	setprop ("controls/flight/speedbrake", SpeedBrakes);
}


var speedBrakesIn = func {
	SpeedBrakes -= SpeedBrakesIncrement;
	if ( SpeedBrakes < 0 ) { SpeedBrakes = 0 }
	setprop ("controls/flight/speedbrake", SpeedBrakes);
}


var computeDrag = func {
	gearExtension = getprop ("gear/gear[1]/position-norm");
	if ( gearExtension != nil ) {
		if ( gearExtension > 0.8 ) {
			LoMachDrag = 1;
		} else {
			LoMachDrag = 0.5;
		}
	}
	LoDragFactor = ( TransitionMachDrag - LoMachDrag ) / TransitionMach;
	if ( CurrentMach == nil ) { CurrentMach = 0.0 }
	if ( CurrentMach <= TransitionMach ) {
		setprop ("f-14/drag", CurrentMach * LoDragFactor + LoMachDrag);
	} elsif (CurrentMach <= HiMach) {
		setprop ("f-14/drag", CurrentMach * HiDragFactor + TransitionMachDrag);
	} else {
		setprop ("f-14/drag", 0);
	}
}
