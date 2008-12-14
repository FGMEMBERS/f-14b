# Chronograph #############

# One button elapsed counter 

var chrono_onoff = props.globals.getNode("sim/model/f-14b/instrumentation/clock/chronometer-on");
var reset_state = props.globals.getNode("sim/model/f-14b/instrumentation/clock/reset-state", 1);
var elapsed_sec = props.globals.getNode("sim/model/f-14b/instrumentation/clock/elapsed-sec", 1);
var indicated_sec = props.globals.getNode("instrumentation/clock/indicated-sec");

aircraft.data.add("/instrumentation/clock/offset-sec");

chrono_onoff.setBoolValue( 0 );
reset_state.setBoolValue( 1 );
elapsed_sec.setValue( 0 );
var offset = 0;

var click = func {
	var on = chrono_onoff.getBoolValue();
	var reset = reset_state.getBoolValue();
	if ( ! on ) {
		if ( ! reset ) {
			# had been former started and stoped, now, has to be reset.
			offset = 0;
			elapsed_sec.setValue( 0 );
			reset_state.setBoolValue( 1 );
		} else {
			# is not started but allready reset, start it.
			chrono_onoff.setBoolValue( 1 );
			reset_state.setBoolValue( 0 );
			offset = indicated_sec.getValue();
		}
	} else {
		# stop it
		chrono_onoff.setBoolValue( 0 );
		reset_state.setBoolValue( 0 );
	}
}

var update_chrono = func {
	# also called from main loop.
	var on = chrono_onoff.getBoolValue();
	if ( on ) {
		var i_sec = indicated_sec.getValue();
		var e_sec = i_sec -offset;
		elapsed_sec.setValue( e_sec );
	}
}
