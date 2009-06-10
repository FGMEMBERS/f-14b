###############################################################################
## $Id$
##
##  Nasal for dual control of the f-14b over the multiplayer network.
##
##  Copyright (C) 2009  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################


var DCT = dual_control_tools;


# Pilot/copilot aircraft identifiers. Used by dual_control.
var pilot_type   = "Aircraft/f-14b/Models/f-14b.xml";
var copilot_type = "";

var copilot_view = "Back-seat View";

props.globals.initNode("/sim/remote/pilot-callsign", "", "STRING");

var pilot_connect_copilot = func (copilot) {
}


var pilot_disconnect_copilot = func {
}


var copilot_connect_pilot = func (pilot) {

	var p = "sim/current-view/name";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "instrumentation/altimeter/indicated-altitude-ft";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "instrumentation/altimeter/setting-inhg";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "orientation/heading-deg";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "orientation/heading-magnetic-deg";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "sim/model/f-14b/controls/radar-awg-9/brightness";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "sim/model/f-14b/controls/radar-awg-9/on-off";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "sim/model/f-14b/instrumentation/radar-awg-9/display-rdr";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "sim/model/f-14b/instrumentation/awg-9/sweep-factor";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "sim/model/f-14b/controls/TID/brightness";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "sim/model/f-14b/controls/TID/on-off";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode/pulse-srch";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "sim/model/f-14b/instrumentation/radar-awg-9/wcs-mode/tws-auto";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "instrumentation/radar/az-field";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "instrumentation/radar/radar2-range";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	var p = "instrumentation/ecm/on-off";
	pilot.getNode(p, 1).alias(props.globals.getNode(p));
	return[];

}

var copilot_disconnect_pilot = func {
}


var set_copilot_wrappers = func (pilot) {
}

