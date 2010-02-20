###############################################################################
## $Id$
##
##  Nasal for dual control of the f-14b over the multiplayer network.
##
##  Copyright (C) 2009  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Renaming (almost :)
var DCT = dual_control_tools;

# Pilot/copilot aircraft identifiers. Used by dual_control.
var pilot_type   = "Aircraft/f-14b/Models/f-14b.xml";
var copilot_type = "Aircraft/f-14b/Models/f-14b-bs.xml";

var copilot_view = "Back-seat View";

props.globals.initNode("/sim/remote/pilot-callsign", "", "STRING");


# MP enabled properties.
# NOTE: These must exist very early during startup - put them
#       in the -set.xml file.


# Useful local property paths.

# Slow state properties for replication.


# Pilot MP property mappings and specific copilot connect/disconnect actions.


# Used by dual_control to set up the mappings for the pilot.
var pilot_connect_copilot = func (copilot) {

	return 
		[
			# Process received properties.

			# Process properties to send.
		];
}


var pilot_disconnect_copilot = func {
}

# Copilot MP property mappings and specific pilot connect/disconnect actions.


# Used by dual_control to set up the mappings for the copilot.
var copilot_connect_pilot = func (pilot) {
	# Initialize Nasal wrappers for copilot pick anaimations.
	set_copilot_wrappers(pilot);

	return
		[
			# Process received properties.

			# Process properties to send.
		];

}

var copilot_disconnect_pilot = func {
}

# Copilot Nasal wrappers
var set_copilot_wrappers = func (pilot) {
	var p = "sim/current-view/name";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "instrumentation/altimeter/indicated-altitude-ft";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "instrumentation/altimeter/setting-inhg";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "orientation/heading-deg";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "orientation/heading-magnetic-deg";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/controls/radar-awg-9/brightness";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/controls/radar-awg-9/on-off";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/instrumentation/radar-awg-9/display-rdr";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/instrumentation/awg-9/sweep-factor";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/controls/TID/brightness";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/controls/TID/on-off";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode/pulse-srch";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode/tws-auto";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "instrumentation/radar/az-field";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "instrumentation/radar/radar2-range";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "instrumentation/ecm/on-off";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/controls/rio-ecm-display/mode-ecm-nav";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/controls/HSD/on-off";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "sim/model/f-14b/instrumentation/hsd/needle-deflection";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "instrumentation/nav[1]/radials/selected-deg";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	p = "instrumentation/radar/radar2-range";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));

}

