# f-14b.nas

#===========================================================================
# Utilities 
#===========================================================================

# strobes ===========================================================

strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("sim/model/lighting/strobe", [0.03, 1.9+rand()/5], strobe_switch);

#============================================================================
# Flight control system 
#============================================================================

#----------------------------------------------------------------------------
# timedMotions
#----------------------------------------------------------------------------

CurrentLeftSpoiler = 0.0;
CurrentRightSpoiler = 0.0;
CurrentInnerLeftSpoiler = 0.0;
CurrentInnerRightSpoiler = 0.0;


SpoilerSpeed = 1.0; # full extension in 1 second

DoorsTargetPosition = 0.0;
DoorsPosition = 0.0;
DoorsSpeed = 0.2;
setprop ("/f-14/doors-position", DoorsPosition);


RefuelProbeTargetPosition = 0.0;
RefuelProbePosition = 0.0;
RefuelProbeSpeed = 0.5;
setprop ("/f-14/refuelling-probe-position", RefuelProbePosition);

currentSweep = 0.0;
SweepSpeed = 0.3;

toggleAccess = func 

  {

    if (DoorsTargetPosition == 0.0) DoorsTargetPosition = 1.0;
    else DoorsTargetPosition = 0.0;
    
  }

toggleProbe = func 

  {

    if (RefuelProbeTargetPosition == 0.0) RefuelProbeTargetPosition = 1.0;
    else RefuelProbeTargetPosition = 0.0;

  }

timedMotions = func

 {
   
  
   if (deltaT == nil) deltaT = 0.0;
   
   
   #---------------------------------
   if (CurrentLeftSpoiler > LeftSpoilersTarget )
    {
     CurrentLeftSpoiler -= SpoilerSpeed * deltaT;
     if (CurrentLeftSpoiler < LeftSpoilersTarget) CurrentLeftSpoiler = LeftSpoilersTarget;
    }
    elsif (CurrentLeftSpoiler < LeftSpoilersTarget)
    {
     CurrentLeftSpoiler += SpoilerSpeed * deltaT;
     if (CurrentLeftSpoiler > LeftSpoilersTarget) CurrentLeftSpoiler = LeftSpoilersTarget;
    } #end if (CurrentLeftSpoiler > LeftSpoilersTarget )

    #---------------------------------
    if (CurrentRightSpoiler > RightSpoilersTarget )
    {
     CurrentRightSpoiler -= SpoilerSpeed * deltaT;
     if (CurrentRightSpoiler < RightSpoilersTarget) CurrentRightSpoiler = RightSpoilersTarget;
    }
    elsif (CurrentRightSpoiler < RightSpoilersTarget)
    {
     CurrentRightSpoiler += SpoilerSpeed * deltaT;
     if (CurrentRightSpoiler > RightSpoilersTarget) CurrentRightSpoiler = RightSpoilersTarget;
    } #end if (CurrentRightSpoiler > RightSpoilersTarget )
   
   #---------------------------------
   if (CurrentInnerLeftSpoiler > InnerLeftSpoilersTarget )
    {
     CurrentInnerLeftSpoiler -= SpoilerSpeed * deltaT;
     if (CurrentInnerLeftSpoiler < InnerLeftSpoilersTarget) CurrentInnerLeftSpoiler = InnerLeftSpoilersTarget;
    }
   elsif (CurrentInnerLeftSpoiler < InnerLeftSpoilersTarget)
    {
     CurrentInnerLeftSpoiler += SpoilerSpeed * deltaT;
     if (CurrentInnerLeftSpoiler > InnerLeftSpoilersTarget) CurrentInnerLeftSpoiler = InnerLeftSpoilersTarget;
    } #end if (CurrentInnerLeftSpoiler > LeftInnerSpoilersTarget )

    #---------------------------------
    if (CurrentInnerRightSpoiler > InnerRightSpoilersTarget )
    {
     CurrentInnerRightSpoiler -= SpoilerSpeed * deltaT;
     if (CurrentInnerRightSpoiler < InnerRightSpoilersTarget) CurrentInnerRightSpoiler = InnerRightSpoilersTarget;
    }
    elsif (CurrentInnerRightSpoiler < InnerRightSpoilersTarget)
    {
     CurrentInnerRightSpoiler += SpoilerSpeed * deltaT;
     if (CurrentInnerRightSpoiler > InnerRightSpoilersTarget) CurrentInnerRightSpoiler = InnerRightSpoilersTarget;
    } #end if (CurrentInnerRightSpoiler > InnerRightSpoilersTarget )

    #---------------------------------
    if (RefuelProbePosition > RefuelProbeTargetPosition)
    {
     RefuelProbePosition -= RefuelProbeSpeed * deltaT;
     if (RefuelProbePosition < RefuelProbeTargetPosition) RefuelProbePosition = RefuelProbeTargetPosition;
    }
    elsif (RefuelProbePosition < RefuelProbeTargetPosition)
    {
     RefuelProbePosition += RefuelProbeSpeed * deltaT;
     if (RefuelProbePosition > RefuelProbeTargetPosition) RefuelProbePosition = RefuelProbeTargetPosition;
    } #end if (RefuelProbePosition > RefuelProbeTargetPosition )


    #---------------------------------
    if (DoorsPosition > DoorsTargetPosition)
    {
     DoorsPosition -= DoorsSpeed * deltaT;
     if (DoorsPosition < DoorsTargetPosition) DoorsPosition = DoorsTargetPosition;
    }
    elsif (DoorsPosition < DoorsTargetPosition)
    {
     DoorsPosition += DoorsSpeed * deltaT;
     if (DoorsPosition > DoorsTargetPosition) DoorsPosition = DoorsTargetPosition;
    } #end if (DoorsPosition > DoorsTargetPosition )

    #---------------------------------
    if (Nozzle1 > Nozzle1Target)
    {
     Nozzle1 -= NozzleSpeed * deltaT;
     if (Nozzle1 < Nozzle1Target) Nozzle1 = Nozzle1Target;
    }
    elsif (Nozzle1 < Nozzle1Target)
    {
     Nozzle1 += NozzleSpeed * deltaT;
     if (Nozzle1 > Nozzle1Target) Nozzle1 = Nozzle1Target;
    } #end if (Nozzle1 > Nozzle1Target)

    #---------------------------------
    if (Nozzle2 > Nozzle2Target)
    {
     Nozzle2 -= NozzleSpeed * deltaT;
     if (Nozzle2 < Nozzle2Target) Nozzle2 = Nozzle2Target;
    }
    elsif (Nozzle2 < Nozzle2Target)
    {
     Nozzle2 += NozzleSpeed * deltaT;
     if (Nozzle2 > Nozzle2Target) Nozzle2 = Nozzle2Target;

    } #end if (Nozzle2 > Nozzle2Target)

    #---------------------------------
    if (currentSweep > WingSweep)
    {
     currentSweep -= SweepSpeed * deltaT;
     if (currentSweep < WingSweep) currentSweep = WingSweep;
    }
    elsif (currentSweep < WingSweep)
    {
     currentSweep += SweepSpeed * deltaT;
     if (currentSweep > WingSweep) currentSweep = WingSweep;

    } #end if (Nozzle2 > Nozzle2Target)

   setprop ("/surface-positions/left-spoilers", CurrentLeftSpoiler);
   setprop ("/surface-positions/right-spoilers", CurrentRightSpoiler);
   setprop ("/surface-positions/inner-left-spoilers", CurrentInnerLeftSpoiler);
   setprop ("/surface-positions/inner-right-spoilers", CurrentInnerRightSpoiler);
   setprop ("engines/engine[0]/nozzle-pos-norm", Nozzle1);
   setprop ("engines/engine[1]/nozzle-pos-norm", Nozzle2);
   setprop ("/f-14/doors-position", DoorsPosition);
   setprop ("/f-14/refuelling-probe-position", RefuelProbePosition);
   setprop ("/surface-positions/wing-sweep", currentSweep);
 }

#----------------------------------------------------------------------------
# FCS update
#----------------------------------------------------------------------------

registerFCS = func {settimer (updateFCS, 0);}

updateFCS = func
  {

    #Fectch most commonly used values
    CurrentMach = getprop ("/velocities/mach");
    CurrentAlt = getprop ("/position/altitude-ft");
    WOW = getprop ("/gear/gear[1]/wow") or getprop ("/gear/gear[2]/wow");
    Alpha = getprop ("/orientation/alpha-deg");
    Throttle = getprop ("/controls/engines/engine/throttle");
	ElevatorTrim = getprop ("/controls/flight/elevator-trim");
	deltaT = getprop ("sim/time/delta-sec");
    
    #update functions
    computeSweep ();
	computeDrag ();
    computeFlaps ();
    computeSpoilers ();
    computeNozzles ();
    computeSAS ();
	computeAdverse ();
	computeNWS ();
    computeAICS ();
    timedMotions ();
    registerFCS ();
  }

updateFCS ();

registerBurner = func {settimer (updateBurner, 0.04);}

Burner = 0;
setprop ("f-14/burner", Burner);

updateBurner = func 
  {

    Burner +=1;
    if (Burner == 3) Burner = 0;
    setprop ("f-14/burner", Burner); 
    registerBurner ();

 } #end updateBurner



 updateBurner ();
