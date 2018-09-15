#
# F-15 Radar routines. 
# The F-15 doesn't have an awg_9, however this isn't an accurate simulation
# of the radar so it works fine.
# The scan and update is optimised. The AI list is only scanned when targets added or removed
# and the update visibility is performed in a partitioned manner, with one partition per frame
# ---------------------------
# RWR (Radar Warning Receiver) is computed in the radar loop for better performance
# AWG-9 Radar computes the nearest target for AIM-9.
# Provides the 'tuned carrier' tacan channel support for ARA-63 emulation
# ---------------------------
# Richard Harrison (rjh@zaretto.com) 2014-11-23. Based on F-14b by xii
# - 2015-07 : Modified to have target selection - nearest_u is retained
#             however active_u is the currently active target which mostly
#             should be the same as nearest_u - but use active_u instead in 
#             most of the code. nearest_u is kept for compatibility.
# 

#var this_model = "f15";
var this_model = "f-14b";

var ElapsedSec        = props.globals.getNode("sim/time/elapsed-sec");
var SwpFac            = props.globals.getNode("sim/model/"~this_model~"/instrumentation/awg-9/sweep-factor", 1);
var DisplayRdr        = props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/display-rdr",1);
var HudTgtHDisplay    = props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/hud/target-display", 1);
var HudTgt            = props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/hud/target", 1);
var HudTgtTDev        = props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/hud/target-total-deviation", 1);
var HudTgtTDeg        = props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/hud/target-total-angle", 1);
var HudTgtClosureRate = props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/hud/closure-rate", 1);
var HudTgtDistance = props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/hud/distance", 1);
var AzField           = props.globals.getNode("instrumentation/radar/az-field", 1);
var RangeRadar2       = props.globals.getNode("instrumentation/radar/radar2-range",1);
var RadarStandby      = props.globals.getNode("instrumentation/radar/radar-standby",1);
var RadarStandbyMP    = props.globals.getNode("sim/multiplay/generic/int[2]",1);
var OurAlt            = props.globals.getNode("position/altitude-ft",1);
var OurHdg            = props.globals.getNode("orientation/heading-deg",1);
var OurRoll           = props.globals.getNode("orientation/roll-deg",1);
var OurPitch          = props.globals.getNode("orientation/pitch-deg",1);
var OurIAS            = props.globals.getNode("fdm/jsbsim/velocities/vtrue-kts",1);
var EcmOn             = props.globals.getNode("instrumentation/ecm/on-off", 1);
var WcsMode           = props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/wcs-mode",1);
var SWTgtRange        = props.globals.getNode("sim/model/"~this_model~"/systems/armament/aim9/target-range-nm",1);
var RadarServicable   = props.globals.getNode("instrumentation/radar/serviceable",1);
var SelectTargetCommand =props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/select-target",1);

var myRadarStrength_rcs = 3.2;
#var awg9_trace = 0;
SelectTargetCommand.setIntValue(0);

# variables for the partioned scanning.
# - instead of building the entire list of potential returns (tgts_list) each frame
#   the list is only built when the something changes in the ai/models, by 
#   listening to the model-added and model-removed properties.
# - to improve the peformance further the visibility check is only performed every 10 seconds. This may seem slow but I don't think it
#   is unrealistic , especially during a hard turn; but realistically it will take a certain amount of time for the real radar to 
#   stabilise the returns. I don't have figures for this but it seems plausible that even when lined up with a return it could take
#   a good few seconds for the processing to find it. 
#   TODO: possibly reduce the scan_visibility_check_interval to a lower value
# - also once built the list of potential returns only has a chunk updated each frame, based on the scan_partition_size
#   so with a lot of targets it could take a number of seconds to update all of these, however it should be a reasonable optimisation

var scan_tgt_idx = 0;
var scan_hidden_by_rcs = 0;
var scan_hidden_by_radar_mode = 0;
var scan_hidden_by_terrain = 0;
var scan_visible_count = 0;

var scan_id = 0;
var scan_update_visibility = 1;
var scan_next_tgt_check = ElapsedSec.getValue() + 2;
var scan_update_tgt_list = 1;
var ScanPartitionSize = props.globals.getNode("instrumentation/radar/scan_partition_size", 1);
var ScanVisibilityCheckInterval = props.globals.getNode("instrumentation/radar/scan_partition_size", 1);
var ScanId = props.globals.getNode("instrumentation/radar/scan_id", 1);
var ScanTgtUpdateCount = props.globals.getNode("instrumentation/radar/scan_tgt_update", 1);
var ScanTgtCount = props.globals.getNode("instrumentation/radar/scan_tgt_count", 1);
var ScanTgtHiddenRCS = props.globals.getNode("instrumentation/radar/scan_tgt_hidden_rcs", 1);
var ScanTgtHiddenTERRAIN = props.globals.getNode("instrumentation/radar/scan_tgt_hidden_terrain", 1);
var ScanTgtVisible = props.globals.getNode("instrumentation/radar/scan_tgt_visible", 1);
ScanTgtUpdateCount.setIntValue(0);

ScanVisibilityCheckInterval.setIntValue(12); # seconds
ScanPartitionSize.setIntValue(10); # size of partition to run per frame.

# Azimuth field quadrants.
# 120 means +/-60, as seen in the diagram below.
#  _______________________________________
# |                   |                  |
# |               _.--+---.              |
# |           ,-''   0|    `--.          |
# |         ,'        |        `.        |
# |        /          |          \       |
# |    -60/'-.        |         _,\+60   |
# |      /    `-.     |     ,.-'   \     |
# |     ; -90    `-._ |_.-''      90     |
#....................::F..................
# |     :             |             ;    |
# |      \       TC   |            /     |
# |       \           |           /      |
# |        \          |          /       |
# |         `.   -180 | +180   ,'        |
# |           '--.    |    _.-'          |
# |               `---+--''              |
# |                   |                  |
#  `''''''''''''''''''|'''''''''''''''''''

#
# local variables related to the simulation of the radar.
var az_fld            = AzField.getValue();
var l_az_fld          = 0;
var r_az_fld          = 0;
var swp_fac           = nil;    # Scan azimuth deviation, normalized (-1 --> 1).
var swp_deg           = nil;    # Scan azimuth deviation, in degree.
var swp_deg_last      = 0;      # Used to get sweep direction.
var swp_spd           = 0.5; 
var swp_dir           = nil;    # Sweep direction, 0 to left, 1 to right.
var swp_dir_last      = 0;
var ddd_screen_width  = 0.0844; # 0.0844m : length of the max azimuth range on the DDD screen.
var range_radar2      = 0;
var my_radarcorr      = 0;
var our_radar_stanby  = 0;
var wcs_mode          = "pulse-srch";
var tmp_nearest_rng   = nil;
var tmp_nearest_u     = nil;
var nearest_rng       = 0;
var nearest_u         = nil;
var active_u = nil;
var active_u_callsign = nil; # currently active callsign
var our_true_heading  = 0;
var our_alt           = 0;

var Mp = props.globals.getNode("ai/models");
var mp_i              = 0;
var mp_count          = 0;
var mp_list           = [];
var tgts_list         = [];
var cnt               = 0;
# Dual-control vars: 
var we_are_bs         = 0;
var pilot_lock        = 0;

# ECM warnings.
var EcmAlert1 = props.globals.getNode("instrumentation/ecm/alert-type1", 1);
var EcmAlert2 = props.globals.getNode("instrumentation/ecm/alert-type2", 1);
var ecm_alert1        = 0;
var ecm_alert2        = 0;
var ecm_alert1_last   = 0;
var ecm_alert2_last   = 0;
var u_ecm_signal      = 0;
var u_ecm_signal_norm = 0;
var u_radar_standby   = 0;
var u_ecm_type_num    = 0;
var FD_TAN3DEG = 0.052407779283; # tan(3)
var sel_next_target = 0;
var sel_prev_target = 0;

var versionString = getprop("sim/version/flightgear");
var version = split(".", versionString);
var major = num(version[0]);
var minor = num(version[1]);
var pica  = num(version[2]);
var pickingMethod = 0;
if ((major == 2017 and minor == 2 and pica >= 1) or (major == 2017 and minor > 2) or major > 2017) {
    pickingMethod = 1;
}

#
#
# use listeners to define when to update the radar return list.
setlistener("/ai/models/model-added", func(v){
    if (!scan_update_tgt_list) {
        scan_update_tgt_list = 1;
    }
});

setlistener("/ai/models/model-removed", func(v){
    if (!scan_update_tgt_list) {
        scan_update_tgt_list = 1;
    }
});

init = func() {
	var our_ac_name = getprop("sim/aircraft");
    # map variants to the base
    if(our_ac_name == "f-14a") our_ac_name = "f-14b";
    if(our_ac_name == "f15d") our_ac_name = "f15c";
	if (our_ac_name == "f-14b-bs") { we_are_bs = 1; }
	if (our_ac_name == "f15-bs") we_are_bs = 1;

	my_radarcorr = radardist.my_maxrange( our_ac_name ); # in kilometers
}

# Radar main processing entry point
# Run at 20hz - invoked from main loop in instruments.nas
var rdr_loop = func() {

	var display_rdr = DisplayRdr.getBoolValue();

	if ( display_rdr and RadarServicable.getValue() == 1) {
		az_scan();
		our_radar_stanby = RadarStandby.getValue();
		if ( we_are_bs == 0) {
			RadarStandbyMP.setIntValue(our_radar_stanby); # Tell over MP if
			# our radar is scaning or is in stanby. Don't if we are a back-seater.
		}
	} elsif ( size(tgts_list) > 0 ) {
		foreach( u; tgts_list ) {
			u.set_display(0);
		}
        armament.contact = nil;
	}
}
#
# this is RWR for TEWS display for the F-15. For a less advanced EW system
# this method would probably just look at their radar.
var compute_rwr = func(radar_mode, u, u_rng){
    #
    # Decide if this mp item is a valid return (and within range).
    # - our radar switched on
    # - their radar switched on
    # - their transponder switched on 
    var their_radar_standby = u.get_rdr_standby();
    var their_transponder_id = u.get_transponder();
    var emitting = 0;
#    var em_by = "";
    # TEWS will see transpoders that are turned on; according to some
    # using the inverse square law and an estimated power of 200 watts
    # and an assumed high gain antenna the estimate is that the maximum
    # distance the transponder/IFF would be distinct enough is 61.18357nm
    if (their_transponder_id != nil and their_transponder_id > 0 and u_rng < 61.18357) {
        emitting = 1;
#em_by = em_by ~ "xpdr ";
    }
    # modes below 2 are on / emerg so they will show up on rwr
#F-15 radar modes;
# mode 3 = off
# mode 2 = stby
# mode 1 = opr
# mode 0 = emerg
    if (radar_mode < 2 and !u.get_behind_terrain()) {
        # in this sense it is actually us that is illuminating them, but for TEWS this is fine.
        var horizon = u.get_horizon( our_alt );
        var u_az_field = az_fld/2.0;
#print ("u_rng=",u_rng," horizon=",horizon);
         if (  u_rng < horizon ) {
            var our_deviation_deg = deviation_normdeg(u.get_heading(), u.get_bearing());
#print("     our_deviation_deg=",our_deviation_deg);
            
            if ( our_deviation_deg < 0 ) { our_deviation_deg *= -1 }
            if ( our_deviation_deg < u_az_field) {
#                em_by = em_by ~ "my_rdr ";
                emitting = 1; 
            }
        }
    }
    if (their_radar_standby != nil and their_radar_standby == 0){
      emitting = 1;
#em_by = em_by ~ "their_rdr ";
  }

#    print("TEWS: ",u.Callsign.getValue()," range ",u_rng, " by ", em_by, " our_mode=",radar_mode, " their_mode=",their_radar_standby, " their_transponder_id=",their_transponder_id, " emitting = ",emitting, " vis=",u.get_visible());

    u.set_RWR_visible(emitting and u.get_visible());
}
var sweep_frame_inc = 0.2;
var az_scan = func() {
    cnt += sweep_frame_inc;

	# Antena az scan. Angular speed is constant but angle covered varies (120 or 60 deg ATM).
	var fld_frac = az_fld / 120;                    # the screen (and the max scan angle) covers 120 deg, but we may use less (az_fld).
	var fswp_spd = swp_spd / fld_frac;              # So the duration (fswp_spd) of a complete scan will depend on the fraction we use.
    var rwr_done = 0;
	swp_fac = math.sin(cnt * fswp_spd) * fld_frac;  # Build a sinusoude, each step based on a counter incremented by the main UPDATE_PERIOD
	SwpFac.setValue(swp_fac);                       # Update this value on the property tree so we can use it for the sweep line animation.
	swp_deg = az_fld / 2 * swp_fac;                 # Now get the actual deviation of the antenae in deg,
	swp_dir = swp_deg < swp_deg_last ? 0 : 1;       # and the direction.
	#if ( az_fld == nil ) { az_fld = 74 } # commented 20110911 if really needed it shouls had been on top of the func.
	l_az_fld = - az_fld / 2;
	r_az_fld = az_fld / 2;

	var fading_speed = 0.015;   # Used for the screen animation, dots get bright when the sweep line goes over, then fade.

	our_true_heading = OurHdg.getValue();
	our_alt = OurAlt.getValue();

    var radar_active = 1;
    var radar_mode = getprop("instrumentation/radar/radar-mode");
    if (radar_mode == nil)
      radar_mode = 0;
    if (radar_mode >= 3)
      radar_active = 0;

#
#
# The radar sweep is simulated such that when the scan limit is reached it is reversed
# and the mp list is rescanned. This means the contents of the radar list will be 
# simulated in a realistic way - the target acquisition based on what's in the MP list will
# be ok; the values (distance etc) will be read from the target list so these will be accurate
# which isn't quite how radar works but it will be good enough for us.

    range_radar2 = RangeRadar2.getValue();
    
    if (1==1 or swp_dir != swp_dir_last)
    {
		# Antena scan direction change (at max: more or less every 2 seconds). Reads the whole MP_list.
		# TODO: Visual glitch on the screen: the sweep line jumps when changing az scan field.

		az_fld = AzField.getValue();
		if ( range_radar2 == 0 ) { range_radar2 = 0.00000001 }

		# Reset nearest_range score
		nearest_u = tmp_nearest_u;
		nearest_rng = tmp_nearest_rng;
		tmp_nearest_rng = nil;
		tmp_nearest_u = nil;

        if (scan_update_tgt_list)
        {
            scan_update_tgt_list=0;
            tgts_list = [];

            var raw_list = Mp.getChildren();
            var carrier_located = 0;

            if (active_u == nil or active_u.Callsign == nil or active_u.Callsign.getValue() == nil or active_u.Callsign.getValue() != active_u_callsign)
            {
                if (active_u != nil)
                    active_u = nil;
                armament.contact = active_u;
            }

            foreach( var c; raw_list )
            {
                var type = c.getName();

                if (c.getNode("valid") == nil or !c.getNode("valid").getValue()) {
                    continue;
                }
                if (type == "multiplayer" or type == "tanker" or type == "aircraft" 
                    or type == "ship" or type == "groundvehicle" or type == "aim-120" or type == "aim-7" or type == "aim-9") 
                {
                    append(tgts_list, Target.new(c));
                }
            }
            scan_tgt_idx = 0;
            scan_update_visibility = 1;
            ScanTgtUpdateCount.setIntValue(ScanTgtUpdateCount.getValue()+1);
            ScanTgtCount.setIntValue(size(tgts_list));
            awg_9.tgts_list = sort (awg_9.tgts_list, func (a,b) {a.get_range()-b.get_range()});

        }
    }
    var idx = 0;

    u_ecm_signal      = 0;
    u_ecm_signal_norm = 0;
    u_radar_standby   = 0;
    u_ecm_type_num    = 0;
    
    if (scan_tgt_idx >= size(tgts_list)) {
        scan_tgt_idx = 0;
        scan_id += 1;
        ScanId.setIntValue(scan_id);

        if (scan_update_visibility) {
            scan_update_visibility = 0;
        } else if (ElapsedSec.getValue() > scan_next_tgt_check) {
            scan_next_tgt_check = ElapsedSec.getValue()  + ScanVisibilityCheckInterval.getValue();
            scan_update_visibility = 1;
        }

        #
        # clear the values ready for the new scan
        u_ecm_signal      = 0;
        u_ecm_signal_norm = 0;
        u_radar_standby   = 0;
        u_ecm_type_num    = 0;
    }

    scan_tgt_end = scan_tgt_idx + ScanPartitionSize.getValue();

    if (scan_tgt_end >= size(tgts_list))
    {
        scan_tgt_end = size(tgts_list);
    }

    for (;scan_tgt_idx < scan_tgt_end; scan_tgt_idx += 1) {

        u = tgts_list[scan_tgt_idx];

		var u_display = 0;
		var u_fading = u.get_fading() - fading_speed;
        var u_rng = u.get_range();
        ecm_on = EcmOn.getValue();

        if (scan_update_visibility) {

            # check for visible by radar taking into account RCS, based on AWG-9 = 89NM for 3.2 rcs (guesstimate)
            # also then check to see if behind terrain.
            # - this test is more costly than the RCS check so perform that first.
            # for both of these tests the result is to set the target as not visible.
            # and simply continue with the rest of the loop.
            # we don't check our radar range here because the scan update visibility is
            # called infrequently so the list must not take into account something that may
           # change between invocations of the update.
            u.set_behind_terrain(0);
#var msg = "";
#pickingMethod = 0;
#var v1 = isNotBehindTerrain(u.propNode);
#pickingMethod = 1;
#var v2 = isNotBehindTerrain(u.propNode);
            if (rcs.isInRadarRange(u, 89, myRadarStrength_rcs) == 0) {
                u.set_display(0);
                u.set_visible(0);
                scan_hidden_by_rcs += 1;
#msg = "out of rcs range";
            } else if (isNotBehindTerrain(u.propNode) == 0) {
#msg = "behind terrain";
                u.set_behind_terrain(1);
                u.set_display(0);
                u.set_visible(0);
                scan_hidden_by_terrain += 1;
            } else {
#msg = "visible";
                scan_visible_count = scan_visible_count+1;
                u.set_visible(1);
                if (u_rng != nil and (u_rng > range_radar2))
                  u.set_display(0);
                else {
                  if (radar_mode == 2) {
#msg = msg ~ " in stby";
                      u.set_display(!u.get_rdr_standby());
                  }
                  if (radar_mode < 2)
                    u.set_display(1);
                  else {
#msg = "radar not transmitting";
                      u.set_display(0);
                  }
              }
            }
#if(awg9_trace)
#    print("UPDS: ",u.Callsign.getValue(),", ", msg, "vis= ",u.get_visible(), " dis=",u.get_display(), " rng=",u_rng, " rr=",range_radar2);
        }
#        else {
#
#            if (u_rng != nil and (u_rng > range_radar2)) {
#                tgts_list[scan_tgt_idx].set_display(0);
## still need to test for RWR warning indication even if outside of the radar range
#                if ( !rwr_done and ecm_on and tgts_list[scan_tgt_idx].get_rdr_standby() == 0) {
#                    rwr_done = rwr_warning_indication(tgts_list[scan_tgt_idx]); 
#                }
#                break;
#            }
#        }
# end of scan update visibility

# if target within radar range, and not acting (i.e. a RIO/backseat/copilot)
        if (u_rng != nil and (u_rng < range_radar2  and u.not_acting == 0 )) {
            u.get_deviation(our_true_heading);
        
            if (rcs.isInRadarRange(u, 89, myRadarStrength_rcs) == 0) {
#                if(awg9_trace)
#                  print(scan_tgt_idx,";",u.get_Callsign()," not visible by rcs");
                u.set_display(0);
                u.set_visible(0);
            }
            else{
#                if(awg9_trace)
#                  print(scan_tgt_idx,";",u.get_Callsign()," visible by rcs+++++++++++++++++++");
                u.set_visible(!u.get_behind_terrain());
            }
#
#
#
#
#
#0;MP1 within  azimuth 49.52579977807609 field=-60->60
#1;MP2 within  azimuth 126.4171942282486 field=-60->60
#1;MP2 within  azimuth -130.0592982116802 field=-60->60  (s->w quadrant)
#0;MP1 within  azimuth 164.2283073827575 field=-60->60
            if (radar_mode < 2 and u.deviation > l_az_fld  and  u.deviation < r_az_fld ){
                u.set_display(u.get_visible());
#                if(awg9_trace)
#                  print(scan_tgt_idx,";",u.get_Callsign()," within  azimuth ",u.deviation," field=",l_az_fld,"->",r_az_fld);
            }
            else {
#                if(awg9_trace)
#                  print(scan_tgt_idx,";",u.get_Callsign()," out of azimuth ",u.deviation," field=",l_az_fld,"->",r_az_fld);
                u.set_display(0);
            }
        }

# RWR 
        compute_rwr(radar_mode, u, u_rng);
        # Test if target has a radar. Compute if we are illuminated. This propery used by ECM
        # over MP, should be standardized, like "ai/models/multiplayer[0]/radar/radar-standby".
        if ( !rwr_done and ecm_on and u.get_rdr_standby() == 0) {
           rwr_done = rwr_warning_indication(u);             # TODO: override display when alert.
        }

        #
        # if not displayed then we can continue to the next in the list.
        if (!u.get_display())
          continue;

        if ( u_fading < 0 ) {
            u_fading = 0;
        }

        if (u.get_display() == 1) #( swp_dir and swp_deg_last < u.deviation and u.deviation <= swp_deg )
          #or ( ! swp_dir and swp_deg <= u.deviation and u.deviation < swp_deg_last ))
          {
              u.get_bearing();
              u.get_heading();
              var horizon = u.get_horizon( our_alt );
              var u_rng = u.get_range();

              #Leto: commented out for OPRF due to that list not being up to date, and plane has no doppler effect, so should see targets below horizon:
              #if ( u_rng < horizon and radardist.radis(u.string, my_radarcorr))  
              if (1==1) {

                  # Compute mp position in our DDD display. (Bearing/horizontal + Range/Vertical).
                  u.set_relative_bearing( ddd_screen_width / az_fld * u.deviation );
                  var factor_range_radar = 0.0657 / range_radar2; # 0.0657m : length of the distance range on the DDD screen.
                  u.set_ddd_draw_range_nm( factor_range_radar * u_rng );
                  u_fading = 1;
                  u_display = 1;

                  # Compute mp position in our TID display. (PPI like display, normaly targets are displayed only when locked.)
                  factor_range_radar = 0.15 / range_radar2; # 0.15m : length of the radius range on the TID screen.
                  u.set_tid_draw_range_nm( factor_range_radar * u_rng );

                  # Compute first digit of mp altitude rounded to nearest thousand. (labels).
                  u.set_rounded_alt( rounding1000( u.get_altitude() ) / 1000 );

                  # Compute closure rate in Kts.
                  u.get_closure_rate();

                  #
                  # ensure that the currently selected target
                  # remains the active one.
                  var callsign="**";

                  if (u.Callsign != nil)
                    callsign=u.Callsign.getValue();

                  if (u.airbone) {
                      if (active_u_callsign != nil and u.Callsign != nil and u.Callsign.getValue() == active_u_callsign) {
                          active_u = u; armament.contact = active_u;
                      }
                  }
                  idx=idx+1;
                  # Check if u = nearest echo.
                  if ( u_rng != 0 and (tmp_nearest_rng == nil or u_rng < tmp_nearest_rng)) {
                      if (u.airbone) {
                          tmp_nearest_u = u;
                          tmp_nearest_rng = u_rng;
                      }
                  }
              }
          }
        u.set_fading(u_fading);

        if (active_u != nil) {
            tmp_nearest_u = active_u;
        }
    }


    # if this is true then we have finished a complete scan; so 
    # update anything that requires this.
    if (scan_tgt_idx >= size(tgts_list)) {

        if (scan_update_visibility) {
            #
            # put some stats in the property tree.
            ScanTgtHiddenRCS.setIntValue(scan_hidden_by_rcs);
            ScanTgtHiddenTERRAIN.setIntValue(scan_hidden_by_terrain);
            ScanTgtVisible.setIntValue(scan_visible_count);

            scan_hidden_by_rcs = 0;
            scan_hidden_by_terrain = 0;
            scan_visible_count = 0;
            scan_hidden_by_radar_mode = 0;
        }

        # Summarize ECM alerts.
        # - this logic is to avoid the ECM alert flashing
        if ( ecm_alert1 == 0 and ecm_alert1_last == 0 ) { 
            EcmAlert1.setBoolValue(0)
        }
        if ( ecm_alert2 == 0 and ecm_alert1_last == 0 ) { 
            EcmAlert2.setBoolValue(0) 
        }
        ecm_alert1_last = ecm_alert1; # And avoid alert blinking at each loop.
        ecm_alert2_last = ecm_alert2;
        ecm_alert1 = 0;
        ecm_alert2 = 0;
    }

    #
    #
    # next / previous target selection. 
    var tgt_cmd = SelectTargetCommand.getValue();
    SelectTargetCommand.setIntValue(0);

    if (tgt_cmd != nil)
    {
        if (tgt_cmd > 0)
            awg_9.sel_next_target=1;
        else if (tgt_cmd < 0)
            awg_9.sel_prev_target=1;
    }

    if (awg_9.sel_prev_target)
    {
        var dist  = 0;
        if (awg_9.active_u != nil)
            dist = awg_9.active_u.get_range();

        var prv=nil;

        foreach (var u; tgts_list) 
        {
            if(u.Callsign.getValue() == active_u_callsign)
                break;

            if(u.get_display() == 1)
            {
                prv = u;
            }
        }

        if (prv == nil)
        {
            var passed = 0;
            foreach (var u; tgts_list) 
            {
                if(passed == 1 and u.get_display() == 1)
                    prv = u;
                if(u.Callsign.getValue() == active_u_callsign)
                    passed = 1;
            }
        }

        if (prv != nil)
        {
            active_u = nearest_u = tmp_nearest_u = prv; armament.contact = active_u;

            if (tmp_nearest_u.Callsign != nil)
                active_u_callsign = tmp_nearest_u.Callsign.getValue();
            else
                active_u_callsign = nil;
                
        }
        awg_9.sel_prev_target =0;
    }
    else if (awg_9.sel_next_target)
    {
        var dist  = 0;

        if (awg_9.active_u != nil)
        {
            dist = awg_9.active_u.get_range();
        }

        var nxt=nil;
        var passed = 0;
        foreach (var u; tgts_list) 
        {
            if(u.Callsign.getValue() == active_u_callsign)
            {
                passed = 1;
                continue;
            }

            if((passed == 1 or dist == 0) and u.get_display() == 1)
            {
                nxt = u;
                break;
            }
        }
        if (nxt == nil)
        {
            foreach (var u; tgts_list) 
            {
                if(u.Callsign.getValue() == active_u_callsign)
                {
                    continue;
                }

                if(u.get_display() == 1)
                {
                    nxt = u;
                    break;
                }
            }

        }

        if (nxt != nil)
        {
            active_u = nearest_u = tmp_nearest_u = nxt; armament.contact = active_u;
            if (tmp_nearest_u.Callsign != nil)
                active_u_callsign = tmp_nearest_u.Callsign.getValue();
            else
                active_u_callsign = nil;
        }
        awg_9.sel_next_target =0;
    }

	swp_deg_last = swp_deg;
	swp_dir_last = swp_dir;

    # finally ensure that the active target is still in the targets list.
    if (!containsV(tgts_list, active_u)) {
        active_u = nil; armament.contact = active_u;
    }
}

setprop("sim/mul"~"tiplay/gen"~"eric/strin"~"g[14]", "o"~""~"7");

var containsV = func (vector, content) {
    if (content == nil) {
        return 0;
    }
    foreach(var vari; vector) {
        if (vari.string == content.string) {
            return 1;
        }
    }
    return 0;
}

#
# The following 1 methods is from Mirage 2000-5 (modified by Pinto)
#
var isNotBehindTerrain = func(node) {
    var x = nil;
    var y = nil;
    var z = nil;

    if (node == nil) {
        print("isNotBehindTerrain, node is nil");
        return 3;
    }

    call(func {
        x = node.getNode("position/global-x").getValue();
        y = node.getNode("position/global-y").getValue();
        z = node.getNode("position/global-z").getValue(); },
        nil, var err = []);

    if(x == nil or y == nil or z == nil) {
        print("Failed to get position from node");#: ",node.string, " x=",x," y=",y," z=",z);
        return 2;
    }
    var SelectCoord = geo.Coord.new().set_xyz(x, y, z);
    var MyCoord = geo.aircraft_position();
        
    # There is no terrain on earth that can be between these altitudes
    # so shortcut the whole thing and return now.
    if(MyCoord.alt() > 8900 and SelectCoord.alt() > 8900){
#if(awg9_trace)
#print("inbt: both above 8900");
        return 1;
    }
    if (pickingMethod == 1) {
      var myPos = geo.aircraft_position();

      var xyz = {"x":myPos.x(),                  "y":myPos.y(),                 "z":myPos.z()};
      var dir = {"x":SelectCoord.x()-myPos.x(),  "y":SelectCoord.y()-myPos.y(), "z":SelectCoord.z()-myPos.z()};

      # Check for terrain between own aircraft and other:
      v = get_cart_ground_intersection(xyz, dir);
      if (v == nil) {
        return 1;
#        printf(":: No terrain, planes has clear view of each other");
      } else {
       var terrain = geo.Coord.new();
       terrain.set_latlon(v.lat, v.lon, v.elevation);
       var maxDist = myPos.direct_distance_to(SelectCoord);
       var terrainDist = myPos.direct_distance_to(terrain);
       if (terrainDist < maxDist) {
#         print("::terrain found between the planes");
         return 0;
       } else {
#          print("::the planes has clear view of each other");
          return 1;
       }
      }
    } else {
        var isVisible = 0;
        
        # Temporary variable
        # A (our plane) coord in meters
        var a = MyCoord.x();
        var b = MyCoord.y();
        var c = MyCoord.z();

        # B (target) coord in meters
        var d = SelectCoord.x();
        var e = SelectCoord.y();
        var f = SelectCoord.z();

        var difa = d - a;
        var difb = e - b;
        var difc = f - c;
        
#        print("a,b,c | " ~ a ~ "," ~ b ~ "," ~ c);
#        print("d,e,f | " ~ d ~ "," ~ e ~ "," ~ f);
        
        # direct Distance in meters
        var myDistance = math.sqrt( math.pow((d-a),2) + math.pow((e-b),2) + math.pow((f-c),2)); #calculating distance ourselves to avoid another call to geo.nas (read: speed, probably).
#        print("myDistance: " ~ myDistance);
        var Aprime = geo.Coord.new();
            
        # Here is to limit FPS drop on very long distance
        var L = 500;
        if (myDistance > 50000) {
            L = myDistance / 15;
        }
        var maxLoops = int(myDistance / L);
            
        isVisible = 1;
        # This loop will make travel a point between us and the target and check if there is terrain
        for (var i = 1 ; i <= maxLoops ; i += 1) {
            #calculate intermediate step
            #basically dividing the line into maxLoops number of steps, and checking at each step
            #to ascii-art explain it:
            #  |us|----------|step 1|-----------|step 2|--------|step 3|----------|them|
            #there will be as many steps as there is i
            #every step will be equidistant
              
            #also, if i == 0 then the first step will be our plane
              
            var x = ((difa/(maxLoops+1))*i)+a;
            var y = ((difb/(maxLoops+1))*i)+b;
              var z = ((difc/(maxLoops+1))*i)+c;
#              print("i:" ~ i ~ "|x,y,z | " ~ x ~ "," ~ y ~ "," ~ z);
              Aprime.set_xyz(x,y,z);
              var AprimeTerrainAlt = geo.elevation(Aprime.lat(), Aprime.lon());
            if (AprimeTerrainAlt == nil) {
                AprimeTerrainAlt = 0;
            }
              
            if (AprimeTerrainAlt > Aprime.alt()) {
                return 0;
            }
        }
        return isVisible;
    }
}


var hud_nearest_tgt = func() {
	# Computes nearest_u position in the HUD
	if ( active_u != nil ) {
		SWTgtRange.setValue(active_u.get_range());
		var our_pitch = OurPitch.getValue();
		#var u_dev_deg = (90 - active_u.get_deviation(our_true_heading));
		#var u_elev_deg = (90 - active_u.get_total_elevation(our_pitch));
		var u_dev_rad = (90 - active_u.get_deviation(our_true_heading)) * D2R;
		var u_elev_rad = (90 - active_u.get_total_elevation(our_pitch)) * D2R;
#if(awg9_trace)
#print("active_u ",wcs_mode, active_u.get_range()," Display", active_u.get_display(), "dev ",active_u.deviation," ",l_az_fld," ",r_az_fld);
		if (wcs_mode == "tws-auto"
			and active_u.get_display()
			and active_u.deviation > l_az_fld
			and active_u.deviation < r_az_fld) {
			var devs = aircraft.develev_to_devroll(u_dev_rad, u_elev_rad);
			var combined_dev_deg = devs[0];
			var combined_dev_length =  devs[1];
			var clamped = devs[2];
			if ( clamped ) {
				Diamond_Blinker.blink();
			} else {
				Diamond_Blinker.cont();
			}

			# Clamp closure rate from -200 to +1,000 Kts.
			var cr = active_u.ClosureRate.getValue();
            
			if (cr != nil)
            {
                if (cr < -200) 
                    cr = 200;
                else if (cr > 1000) 
                    cr = 1000;
    			HudTgtClosureRate.setValue(cr);
            }

			HudTgtTDeg.setValue(combined_dev_deg);
			HudTgtTDev.setValue(combined_dev_length);
			HudTgtHDisplay.setBoolValue(1);
            HudTgtDistance.setValue(active_u.get_range());

			var u_target = active_u.type ~ "[" ~ active_u.index ~ "]";

            var callsign = active_u.Callsign.getValue();
            var model = "";

            if (active_u.Model != nil)
                model = active_u.Model.getValue();

            var target_id = "";
            if(callsign != nil)
                target_id = callsign;
            else
                target_id = u_target;
            if (model != nil and model != "")
                target_id = target_id ~ " " ~ model;

            HudTgt.setValue(target_id);
			return;
		}
	}
	SWTgtRange.setValue(0);
	HudTgtClosureRate.setValue(0);
	HudTgtTDeg.setValue(0);
	HudTgtTDev.setValue(0);
	HudTgtHDisplay.setBoolValue(0);
}
# HUD clamped target blinker
Diamond_Blinker = aircraft.light.new("sim/model/"~this_model~"/lighting/hud-diamond-switch", [0.1, 0.1]);
setprop("sim/model/"~this_model~"/lighting/hud-diamond-switch/enabled", 1);

#
#
# Map of known names to radardist names.
# radardist should be updated.
var ac_map = {"C-137R" : "707",
              "C-137R-PAX" : "707",
              "E-8R" : "707",
              "EC-137R" : "707",
              "KC-137R" : "707",
              "KC-137R-RT" : "707",
              "KC135" : "707",
              "RC-137R" : "707",
              "MiG-21MF-75" : "MiG-21",
              "MiG-21bis" : "MiG-21",
              "MiG-21bis-AI" : "MiG-21",
              "MiG-21bis-Wingman" : "MiG-21",
              "Blackbird-SR71A" : "SR71-Blackbird",
              "Blackbird-SR71B" : "SR71-Blackbird",
              "Tornado-GR4" : "Tornado",
              "ac130" : "c310",
              "c130" : "c310",
              "c130k" : "c310",
              "kc130" : "c310",
              "F-15D" : "f15c",
              "F-15C" : "f15c", 
              "AJ37-Viggen" : "mirage2000",
              "AJS37-Viggen" : "mirage2000",
              "JA37Di-Viggen" : "mirage2000",
              "Typhoon" : "mirage2000"
             };

# ECM: Radar Warning Receiver
# control the lights that indicate radar warning, the F-14 has two lights, the F-15 one light
# other aircraft may or not have this function; or instead of lights maybe a warning tone.
rwr_warning_indication = func(u) {
#
# get the aircraft type using radardist method that extracts from the model using
# the path.
# then remove the .xml and additionally support extra craft using the ac_map mapping defined above.
# this will then give us the maximum range.
# although we will use our own RCS method to 
	var u_name = radardist.get_aircraft_name(u.string);
    u_name = string.truncateAt(u_name, ".xml");
    u_name = ac_map[u_name] or u_name;
	var u_maxrange = radardist.my_maxrange(u_name); # in kilometer, 0 is unknown or no radar.
	var horizon = u.get_horizon( our_alt );
	var u_rng = u.get_range();
	var u_carrier = u.check_carrier_type();
    var u_az_field = (u.get_az_field()/2.0)*1.2;
	if ( u_maxrange > 0  and u_rng < horizon ) {
#print("RWR: ",u_name, " rng=",u_rng, "u_maxrange=",u_maxrange, " horizon=",horizon, " az=",u_az_field);
		var our_deviation_deg = deviation_normdeg(u.get_heading(), u.get_reciprocal_bearing());

		if ( our_deviation_deg < 0 ) { our_deviation_deg *= -1 }
#print("     our_deviation_deg=",our_deviation_deg, " u_carrier=",u_carrier);
		if ( our_deviation_deg < u_az_field or u_carrier == 1 ) {
			u_ecm_signal = (((-our_deviation_deg/20)+2.5)*(!u_carrier )) + (-u_rng/20) + 2.6 + (u_carrier*1.8);
			u_ecm_type_num = radardist.get_ecm_type_num(u_name);
#print("     u_ecm_signal=",u_ecm_signal," u_ecm_type_num=",u_ecm_type_num);
		}
	}
#else print("RWR: out of range");
	# Compute global threat situation for undiscriminant warning lights
	# and discrete (normalized) definition of threat strength.
	if ( u_ecm_signal > 1 and u_ecm_signal < 3 ) {
		EcmAlert1.setBoolValue(1);
		ecm_alert1 = 1;
		u_ecm_signal_norm = 2;
	} elsif ( u_ecm_signal >= 3 ) {
		EcmAlert2.setBoolValue(1);
		ecm_alert2 = 1;
		u_ecm_signal_norm = 1;
	}
    #
    # Set these again once the lights are done as need these for the RWR display.
    u_ecm_signal = (-u_rng/20) + 2.6;
    u_ecm_type_num = radardist.get_ecm_type_num(u_name);
	
#print("     u_ecm_signal=",u_ecm_signal," u_ecm_type_num=",u_ecm_type_num);

    u.EcmSignal.setValue(u_ecm_signal);
	u.EcmSignal.setValue(u_ecm_signal);
	u.EcmSignalNorm.setIntValue(u_ecm_signal_norm);
	u.EcmTypeNum.setIntValue(u_ecm_type_num);
    return u_ecm_signal != 0;
}


# Utilities.
var deviation_normdeg = func(our_heading, target_bearing) {
	var dev_norm = our_heading - target_bearing;
	while (dev_norm < -180) dev_norm += 360;
	while (dev_norm > 180) dev_norm -= 360;
	return(dev_norm);
}



var rounding1000 = func(n) {
	var a = int( n / 1000 );
	var l = ( a + 0.5 ) * 1000;
	n = (n >= l) ? ((a + 1) * 1000) : (a * 1000);
	return( n );
}

# Controls
# ---------------------------------------------------------------------
var toggle_radar_standby = func() {
	if ( pilot_lock and ! we_are_bs ) { return }
	RadarStandby.setBoolValue(!RadarStandby.getBoolValue());
}

var range_control = func(n) {
	# 1(+), -1(-), 5, 10, 20, 50, 100, 200
	if ( pilot_lock and ! we_are_bs ) { return }
	var range_radar = RangeRadar2.getValue();
	if ( n == 1 ) {
		if ( range_radar == 5 ) { range_radar = 10 }
		elsif ( range_radar == 10 ) { range_radar = 20 }
		elsif ( range_radar == 20 ) { range_radar = 50 }
		elsif ( range_radar == 50 ) { range_radar = 100 }
		else { range_radar = 200 }
	} elsif (n == -1 ) {
		if ( range_radar == 200 ) { range_radar = 100 }
		elsif ( range_radar == 100 ) { range_radar = 50 }
		elsif ( range_radar == 50 ) { range_radar = 20 }
		elsif ( range_radar == 20 ) { range_radar = 10 }
		else { range_radar = 5  }
	} elsif (n == 5 ) { range_radar = 5 }
	elsif (n == 10 ) { range_radar = 10 }
	elsif (n == 20 ) { range_radar = 20 }
	elsif (n == 50 ) { range_radar = 50 }
	elsif (n == 100 ) { range_radar = 100 }
	elsif (n == 200 ) { range_radar = 200 }
	RangeRadar2.setValue(range_radar);
}

wcs_mode_sel = func(mode) {
	if ( pilot_lock and ! we_are_bs ) { return }
	foreach (var n; props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/wcs-mode").getChildren()) {
		n.setBoolValue(n.getName() == mode);
		wcs_mode = mode;
	}
	if ( wcs_mode == "pulse-srch" ) {
		AzField.setValue(120);
		ddd_screen_width = 0.0844;
	} else {
		AzField.setValue(60);
		ddd_screen_width = 0.0422;
	}
}

wcs_mode_toggle = func() {
	# Temporarely toggles between the first 2 available modes.
	#foreach (var n; props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/wcs-mode").getChildren()) {
	if ( pilot_lock and ! we_are_bs ) { return }
	foreach (var n; WcsMode.getChildren()) {
		if ( n.getBoolValue() ) { wcs_mode = n.getName() }
	}
	if ( wcs_mode == "pulse-srch" ) {
		WcsMode.getNode("pulse-srch").setBoolValue(0);
		WcsMode.getNode("tws-auto").setBoolValue(1);
		wcs_mode = "tws-auto";
		AzField.setValue(60);
		ddd_screen_width = 0.0422;
	} elsif ( wcs_mode == "tws-auto" ) {
		WcsMode.getNode("pulse-srch").setBoolValue(1);
		WcsMode.getNode("tws-auto").setBoolValue(0);
		wcs_mode = "pulse-srch";
		AzField.setValue(120);
		ddd_screen_width = 0.0844;
	}
}

wcs_mode_update = func() {
	# Used on pilot's side when WcsMode is updated by the back-seater.
	foreach (var n; WcsMode.getChildren()) {
		if ( n.getBoolValue() ) { wcs_mode = n.getName() }
	}
	if ( WcsMode.getNode("tws-auto").getBoolValue() ) {
		wcs_mode = "tws-auto";
		AzField.setValue(60);
		ddd_screen_width = 0.0422;
	} elsif ( WcsMode.getNode("pulse-srch").getBoolValue() ) {
		wcs_mode = "pulse-srch";
		AzField.setValue(120);
		ddd_screen_width = 0.0844;
	}

}


# Target class
# ---------------------------------------------------------------------
var Target = {
	new : func (c) {
		var obj = { parents : [Target]};
        obj.propNode = c;
		obj.RdrProp = c.getNode("radar");
		obj.Heading = c.getNode("orientation/true-heading-deg");
        obj.pitch   = c.getNode("orientation/pitch-deg");
        obj.roll   = c.getNode("orientation/roll-deg");
		obj.Alt = c.getNode("position/altitude-ft");
		obj.AcType = c.getNode("sim/model/ac-type");
		obj.type = c.getName();
		obj.Valid = c.getNode("valid");
		obj.Callsign = c.getNode("callsign");
        obj.TAS = c.getNode("velocities/true-airspeed-kt");
        obj.TransponderId = c.getNode("instrumentation/transponder/transmitted-id");

        if (obj.Callsign == nil or obj.Callsign.getValue() == "")
        {
            obj.unique = rand();
            var signNode = c.getNode("sign");
            if (signNode != nil)
                obj.Callsign = signNode;
        } else {
            obj.unique = obj.Callsign.getValue();
        }


        obj.Model = c.getNode("model-short");
        var model_short = c.getNode("sim/model/path");
        if(model_short != nil)
        {
            var model_short_val = model_short.getValue();
            if (model_short_val != nil and model_short_val != "")
            {
            var u = split("/", model_short_val); # give array
            var s = size(u); # how many elements in array
            var o = u[s-1];	 # the last element
            var m = size(o); # how long is this string in the last element
            var e = m - 4;   # - 4 chars .xml
            obj.ModelType = substr(o, 0, e); # the string without .xml
}
else
            obj.ModelType = "";
        }
else
{
            obj.ModelType = "";
        }

		obj.index = c.getIndex();
		obj.string = "ai/models/" ~ obj.type ~ "[" ~ obj.index ~ "]";
		obj.shortstring = obj.type ~ "[" ~ obj.index ~ "]";
        obj.TgTCoord  = geo.Coord.new();
        if (c.getNode("position/latitude-deg") != nil and c.getNode("position/longitude-deg") != nil) {
            obj.lat = c.getNode("position/latitude-deg");
            obj.lon = c.getNode("position/longitude-deg");
        } else {
            obj.lat = nil;
            if (c.getNode("position/global-x") != nil)
            {
                obj.x = me.propNode.getNode("position/global-x");
                obj.y = me.propNode.getNode("position/global-y");
                obj.z = me.propNode.getNode("position/global-z");
            } else {
                obj.x = nil;
            }
        }

        if (obj.type == "multiplayer" or obj.type == "tanker" or obj.type == "aircraft" and obj.RdrProp != nil) 
            obj.airbone = 1;
        else
            obj.airbone = 0;
		
		# Remote back-seaters shall not emit and shall be invisible. FIXME: This is going to be handled by radardist ASAP.
		obj.not_acting = 0;
		var Remote_Bs_String = c.getNode("sim/multiplay/generic/string[1]");
		if ( Remote_Bs_String != nil ) {
			var rbs = Remote_Bs_String.getValue();
			if ( rbs != nil ) {
				var l = split(";", rbs);
				if ( size(l) > 0 ) {
					if ( l[0] == "f15-bs" or l[0] == "f-14b-bs" ) {
						obj.not_acting = 1;
					}
				}
			}
		}

		# Local back-seater has a different radar-awg-9 folder and shall not see its pilot's aircraft.
		obj.InstrTgts = props.globals.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/targets", 1);
#		var bs = getprop("sim/aircraft");
#		if ( bs == "f15-bs") {
        if (we_are_bs) {
			if  ( BS_instruments.Pilot != nil ) {
				# Use a different radar-awg-9 folder.
				obj.InstrTgts = BS_instruments.Pilot.getNode("sim/model/"~this_model~"/instrumentation/radar-awg-9/targets", 1);
				# Do not see our pilot's aircraft.
				var target_callsign = obj.Callsign.getValue();
				var p_callsign = BS_instruments.Pilot.getNode("callsign").getValue();
				if ( target_callsign == p_callsign ) {
					obj.not_acting = 1;
				}
			}
		}	

		obj.TgtsFiles = obj.InstrTgts.getNode(obj.shortstring, 1);
        if (obj.RdrProp != nil)
		{
            obj.Range          = obj.RdrProp.getNode("range-nm");
            obj.Bearing        = obj.RdrProp.getNode("bearing-deg");
            obj.Elevation      = obj.RdrProp.getNode("elevation-deg");
            obj.TotalElevation = obj.RdrProp.getNode("total-elevation-deg", 1);
        }
        else
        {
            obj.Range          = nil;
            obj.Bearing        = nil;
            obj.Elevation      = nil;
            obj.TotalElevation = nil;
        }

        if (obj.TgtsFiles != nil)
        {
            obj.BBearing       = obj.TgtsFiles.getNode("bearing-deg", 1);
            obj.BHeading       = obj.TgtsFiles.getNode("true-heading-deg", 1);
            obj.RangeScore     = obj.TgtsFiles.getNode("range-score", 1);
            obj.RelBearing     = obj.TgtsFiles.getNode("ddd-relative-bearing", 1);
            obj.Carrier        = obj.TgtsFiles.getNode("carrier", 1);
            obj.EcmSignal      = obj.TgtsFiles.getNode("ecm-signal", 1);
            obj.EcmSignalNorm  = obj.TgtsFiles.getNode("ecm-signal-norm", 1);
            obj.EcmTypeNum     = obj.TgtsFiles.getNode("ecm_type_num", 1);
            obj.Display        = obj.TgtsFiles.getNode("display", 1);
            obj.Visible        = obj.TgtsFiles.getNode("visible", 1);
            obj.Behind_terrain = obj.TgtsFiles.getNode("behind-terrain", 1);
            obj.RWRVisible     = obj.TgtsFiles.getNode("rwr-visible", 1);
            obj.Fading         = obj.TgtsFiles.getNode("ddd-echo-fading", 1);
            obj.DddDrawRangeNm = obj.TgtsFiles.getNode("ddd-draw-range-nm", 1);
            obj.TidDrawRangeNm = obj.TgtsFiles.getNode("tid-draw-range-nm", 1);
            obj.RoundedAlt     = obj.TgtsFiles.getNode("rounded-alt-ft", 1);
            obj.TimeLast       = obj.TgtsFiles.getNode("closure-last-time", 1);
            obj.RangeLast      = obj.TgtsFiles.getNode("closure-last-range-nm", 1);
            obj.ClosureRate    = obj.TgtsFiles.getNode("closure-rate-kts", 1);
            obj.Visible.setBoolValue(0);
            obj.Display.setBoolValue(0);
        }
		obj.TimeLast.setValue(ElapsedSec.getValue());
        var cur_range = obj.get_range();
        if (cur_range != nil and obj.RangeLast != nil)
		    obj.RangeLast.setValue(obj.get_range());
		# Radar emission status for other users of radar2.nas.
		obj.RadarStandby = c.getNode("sim/multiplay/generic/int[2]");

		obj.deviation = nil;

		return obj;
	},
#
# radar azimuth
    get_az_field : func {
        return 60.0;
    },
	get_heading : func {
		var n = me.Heading.getValue();
        if (n != nil)
		    me.BHeading.setValue(n);
		return n;	},
	get_bearing : func {
        if (me.Bearing == nil)
            return 0;
		var n = me.Bearing.getValue();
        if (n != nil)
        {
    		me.BBearing.setValue(n);
        }
		return n;
	},
	set_relative_bearing : func(n) {
		me.RelBearing.setValue(n);
	},
	get_relative_bearing : func() {
		return me.RelBearing.getValue();
	},
	get_reciprocal_bearing : func {
		return geo.normdeg(me.get_bearing() + 180);
	},
	get_deviation : func(true_heading_ref) {
		me.deviation =  - deviation_normdeg(true_heading_ref, me.get_bearing());
		return me.deviation;
	},
	get_altitude : func {
		return me.Alt.getValue();
	},
	get_total_elevation : func(own_pitch) {
		me.deviation =  - deviation_normdeg(own_pitch, me.Elevation.getValue());
		me.TotalElevation.setValue(me.deviation);
		return me.deviation;
	},
	get_range : func {
        #
        # range on carriers (and possibly other items) is always 0 so recalc.
        if (me.Range == nil or me.Range.getValue() == 0)
        {
            var tgt_pos = me.get_Coord();
#                print("Recalc range - ",tgt_pos.distance_to(geo.aircraft_position()));
            if (tgt_pos != nil) {
                return tgt_pos.distance_to(geo.aircraft_position()) * M2NM; # distance in NM
            }
            if (me.Range != nil)
                return me.Range.getValue();
        }
        if (me.Range == nil)
            return 0;
        else
            return me.Range.getValue();
	},
	get_horizon : func(own_alt) {
		var tgt_alt = me.get_altitude();
		if ( tgt_alt != nil ) {
			if ( own_alt < 0 ) { own_alt = 0.001 }
			if ( debug.isnan(tgt_alt)) {
				print("####### nan ########");
				return(0);
			}
			if ( tgt_alt < 0 ) { tgt_alt = 0.001 }
			return radardist.radar_horizon( own_alt, tgt_alt );
		}
			return(0);
	},
	check_carrier_type : func {
		var type = "none";
		var carrier = 0;
		if ( me.AcType != nil ) { type = me.AcType.getValue() }
		if ( type == "MP-Nimitz" or type == "MP-Eisenhower" or type == "MP-Vinson" ) { carrier = 1 }
		me.Carrier.setBoolValue(carrier);
		return carrier;
	},
	get_rdr_standby : func {
		# FIXME: this one shouldn't be part of Target
		var s = 0;
		if ( me.RadarStandby != nil ) {
			s = me.RadarStandby.getValue();
        if (s == nil or s != 1) 
            return 0;
		}
		return s;
	},
	get_transponder : func {
        if (me.TransponderId != nil) 
            return me.TransponderId.getValue();
        return nil;
		},
	get_display : func() {
		return me.Display.getValue();
	},
	set_display : func(n) {
		me.Display.setBoolValue(n);
	},
	get_visible : func() {
		return me.Visible.getValue();
	},
	set_visible : func(n) {
		me.Visible.setBoolValue(n);
	},
	get_behind_terrain : func() {
		return me.Behind_terrain.getValue();
	},
	set_behind_terrain : func(n) {
		me.Behind_terrain.setBoolValue(n);
	},
	get_RWR_visible : func() {
		return me.RWRVisible.getValue();
	},
	set_RWR_visible : func(n) {
		me.RWRVisible.setBoolValue(n);
	},
	get_fading : func() {
		var fading = me.Fading.getValue(); 
		if ( fading == nil ) { fading = 0 }
		return fading;
	},
	set_fading : func(n) {
		me.Fading.setValue(n);
	},
	set_ddd_draw_range_nm : func(n) {
		me.DddDrawRangeNm.setValue(n);
	},
	set_hud_draw_horiz_dev : func(n) {
		me.HudDrawHorizDev.setValue(n);
	},
	set_tid_draw_range_nm : func(n) {
		me.TidDrawRangeNm.setValue(n);
	},
	set_rounded_alt : func(n) {
		me.RoundedAlt.setValue(n);
	},
    get_TAS: func(){
        if (me.TAS != nil)
        {
            return me.TAS.getValue();
        }
        return 0;
    },
    get_Coord: func(){
        if (me.lat != nil) {
            me.TgTCoord.set_latlon(me.lat.getValue(), me.lon.getValue(), me.Alt.getValue() * FT2M);
        } else {
            if (me.x != nil)
            {
                var x = me.x.getValue();
                var y = me.y.getValue();
                var z = me.z.getValue();

                me.TgTCoord.set_xyz(x, y, z);
            } else {
                return nil;#hopefully wont happen
            }
        }
        return geo.Coord.new(me.TgTCoord);#best to pass a copy
    },

	get_closure_rate : func() {
        #
        # calc closure using trig as the elapsed time method is not really accurate enough and jitters considerably
        if (me.TAS != nil)
        {
            var tas = me.TAS.getValue();
            var our_hdg = OurHdg.getValue();
            if(our_hdg != nil)
            {
                var myCoord = me.get_Coord();
                var bearing = 0;
                if(myCoord.is_defined())
                {
                    bearing = aircraft.ownship_pos.course_to(myCoord);
                    bearing_ = myCoord.course_to(aircraft.ownship_pos);
                }
                var vtrue_kts = OurIAS.getValue();
                if (vtrue_kts != nil)
                {
                    #
                    # Closure rate is a doppler thing. see figure 4 http://www.tscm.com/doppler.pdf
                    # closing velocity = OwnshipVelocity * cos(target_bearing) + TargetVelocity*cos(ownship_bearing);
                    var vec_ownship = vtrue_kts * math.cos( (bearing - our_hdg) / 57.29577950560105);
                    var vec_target = tas * math.cos( (bearing_ - me.get_bearing()) / 57.29577950560105);
                    return vec_ownship+vec_target;
                }
            }
        }
        else
            print("NO TAS ",me.type," ",u.get_range(),u.Model, u.Callsign.getValue());
        return 0;
#
# this is the old way of calculating closure; it's wrong because this isn't what it actually is in
# radar terms.
		var dt = ElapsedSec.getValue() - me.TimeLast.getValue();
		var rng = me.Range.getValue();
		var lrng = me.RangeLast.getValue();
		if ( debug.isnan(rng) or debug.isnan(lrng)) {
			print("####### get_closure_rate(): rng or lrng = nan ########");
			me.ClosureRate.setValue(0);
			me.RangeLast.setValue(0);
			return(0);
		}
		var t_distance = lrng - rng;
		var	cr = (dt > 0) ? t_distance/dt*3600 : 0;
		me.ClosureRate.setValue(cr);
		me.RangeLast.setValue(rng);
		return(cr);
	},
    isValid: func () {
      var valid = me.Valid.getValue();
      if (valid == nil) {
        valid = FALSE;
      }
      return valid;
    },
    getUnique: func {
        return me.unique;
    },
    get_type: func {
        var AIR = 0;
        var MARINE = 1;
        var SURFACE = 2;
        var ORDNANCE = 3;
        return AIR;
    },
    isPainted: func {
        return 1;
    },
    getFlareNode: func {
        return me.propNode.getNode("rotors/main/blade[3]/flap-deg");
    },
    getChaffNode: func () {
      return me.propNode.getNode("rotors/main/blade[3]/position-deg");
    },
    getElevation: func() {
        var e = 0;
        e = me.Elevation.getValue();
        if(e == nil or e == 0) {
            # AI/MP has no radar properties
            var self = geo.aircraft_position();
            me.get_Coord();
            if (me.coord != nil){
                var angleInv = armament.AIM.clamp(self.distance_to(me.coord)/self.direct_distance_to(me.coord), -1, 1);
                e = (self.alt()>me.coord.alt()?-1:1)*math.acos(angleInv)*R2D;
            }
        }
        return e;
    },
    get_Callsign: func {
        if (me.Callsign == nil) {
            return me.get_model();
        }
        return me.Callsign.getValue();
    },
    get_Pitch: func(){
        var n = me.pitch.getValue();
        return n;
    },
    get_Roll: func(){
        var n = me.roll.getValue();
        return n;
    },
    get_Speed: func(){
        return me.get_TAS();
    },
    get_model: func {
        return me.ModelType;
    },
	list : [],
};

# Notes:

# HUD field of view = 2 * math.atan2( 0.0764, 0.7186) * globals.R2D; # ~ 12.1375°
# where 0.071 : virtual screen half width, 0.7186 : distance eye -> screen
dump_tgt = func (u){
    print(scan_tgt_idx, " callsign ", u.get_Callsign(), " range ",u.get_range(), " display ", u.get_display(), " visible ",u.get_visible(), 
          " ddd-relative-bearing=", u.RelBearing,
          " ddd-echo-fading=", u.Fading,
          " ddd-draw-range-nm=",u.DddDrawRangeNm,
          " tid-draw-range-nm=",u.TidDrawRangeNm);
}

dump_tgt_list = func {
    for (scan_tgt_idx=0;scan_tgt_idx < size(tgts_list); scan_tgt_idx += 1) {
        var u = tgts_list[scan_tgt_idx];
        dump_tgt(u);
    }
}

