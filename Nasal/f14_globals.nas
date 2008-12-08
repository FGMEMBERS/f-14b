## Global constants ##
var true = 1;
var false = 0;

var deltaT = 1.0;

#----------------------------------------------------------------------------
# sweep computer
#----------------------------------------------------------------------------

#Variables

var AutoSweep = true;
var OverSweep = false;
var WingSweep = 0.0; #Normalised wing sweep

#----------------------------------------------------------------------------
# flap computer
#----------------------------------------------------------------------------

# Variables

var FlapsCommand = 0;

#----------------------------------------------------------------------------
# Nozzle opening
#----------------------------------------------------------------------------

# Variables
var Nozzle1Target = 0.0;
var Nozzle2Target = 0.0;
var Nozzle1 = 0.0;
var Nozzle2 = 0.0;

#----------------------------------------------------------------------------
# Spoilers
#----------------------------------------------------------------------------

# Variables
var LeftSpoilersTarget = 0.0;
var RightSpoilersTarget = 0.0;
var InnerLeftSpoilersTarget = 0.0;
var InnerRightSpoilersTarget = 0.0;

# create a property for direct lift control (DLC)
setprop ("/controls/flight/DLC", 0.0);
var DLCactive = false;
var DLC_Engaged = props.globals.getNode("controls/flight/DLC-engaged");

# create properties for ground spoilers 
#setprop ("/controls/flight/ground-spoilers-armed", false);
var GroundSpoilersDeployed = false;

# Latching mechanism in order not to deploy ground spoilers if the aircraft
# is on ground and the spoilers are armed
var GroundSpoilersLatchedClosed = true;

# create a property to control spoilers in the YaSim flight model
setprop ("/controls/flight/yasim-spoilers", 0.0);


#----------------------------------------------------------------------------
# SAS
#----------------------------------------------------------------------------

var OldPitchInput = 0.0;
var SASpitch = 0.0;
var SASroll = 0.0;

#----------------------------------------------------------------------------
# General aircraft values
#----------------------------------------------------------------------------

# Constants
var ThrottleIdle = 0.05;

# Variables
var CurrentMach = 0.0;
var CurrentAlt = 0.0;
var CurrentIAS = 0.0;
var WOW = true;
var Alpha = 0.0;
var Throttle = 0.0;
var ElevatorTrim = 0.0;

# Set properties

setprop ("/controls/flight/auxFlaps", 0.0);
setprop ("/controls/flight/flapscommand", 0.0);


