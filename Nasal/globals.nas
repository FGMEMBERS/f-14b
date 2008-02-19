## Global constants ##
true = 1;
false = 0;

deltaT = 1.0;

#----------------------------------------------------------------------------
# sweep computer
#----------------------------------------------------------------------------

#Variables

AutoSweep = true;
OverSweep = false;
WingSweep = 0.0; #Normalised wing sweep

#----------------------------------------------------------------------------
# flap computer
#----------------------------------------------------------------------------

# Variables

FlapsCommand = 0;

#----------------------------------------------------------------------------
# Nozzle opening
#----------------------------------------------------------------------------

# Variables
Nozzle1Target = 0.0;
Nozzle2Target = 0.0;
Nozzle1 = 0.0;
Nozzle2 = 0.0;

#----------------------------------------------------------------------------
# Spoilers
#----------------------------------------------------------------------------

# Variables
LeftSpoilersTarget = 0.0;
RightSpoilersTarget = 0.0;
InnerLeftSpoilersTarget = 0.0;
InnerRightSpoilersTarget = 0.0;

# create a property for direct lift control (DLC)
setprop ("/controls/flight/DLC", 0.0);
DLCactive = false;

# create properties for ground spoilers 
#setprop ("/controls/flight/ground-spoilers-armed", false);
GroundSpoilersDeployed = false;

# Latching mechanism in order not to deploy ground spoilers if the aircraft
# is on ground and the spoilers are armed
GroundSpoilersLatchedClosed = true;

# create a property to control spoilers in the YaSim flight model
setprop ("/controls/flight/yasim-spoilers", 0.0);

#----------------------------------------------------------------------------
# flap computer
#----------------------------------------------------------------------------

# Variables

SpeedBrakes = 0.0;

#----------------------------------------------------------------------------
# SAS
#----------------------------------------------------------------------------

OldPitchInput = 0.0;
SASpitch = 0.0;
SASroll = 0.0;

#----------------------------------------------------------------------------
# General aircraft values
#----------------------------------------------------------------------------

# Constants
ThrottleIdle = 0.05;

# Variables
CurrentMach = 0.0;
CurrentAlt = 0.0;
WOW = true;
Alpha = 0.0;
Throttle = 0.0;
ElevatorTrim = 0.0;

# Set properties

setprop ("/controls/flight/auxFlaps", 0.0);
setprop ("/controls/flight/flapscommand", 0.0);


