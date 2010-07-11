

var AcModel        = props.globals.getNode("sim/model/f-14b");
var OurHdg         = props.globals.getNode("orientation/heading-deg");
var OurRoll        = props.globals.getNode("orientation/roll-deg");
var OurPitch       = props.globals.getNode("orientation/pitch-deg");
var HudReticleDev  = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/reticle-total-deviation", 1);
var HudReticleDeg  = props.globals.getNode("sim/model/f-14b/instrumentation/radar-awg-9/hud/reticle-total-angle", 1);
var aim_9_model    = "Aircraft/f-14b/Models/Stores/aim-9/aim-9-";
var SwSoundOnOff   = AcModel.getNode("systems/armament/aim9/sound-on-off");
var SwSoundVol     = AcModel.getNode("systems/armament/aim9/sound-volume");
var vol_search     = 0.12;
var vol_weak_track = 0.20;
var vol_track      = 0.45;

var slugs_to_lbs = 32.1740485564;


var AIM9 = {
	new : func (p) {
		var m = { parents : [AIM9]};
		# Args: p = Pylon.

		m.status            = 0; # -1 = stand-by, 0 = searching, 1 = locked, 2 = fired.
		m.free              = 0; # 0 = status fired with lock, 1 = status fired but having lost lock.

		m.prop              = AcModel.getNode("systems/armament/aim9/").getChild("msl", 0 , 1);
		m.PylonIndex        = m.prop.getNode("pylon-index", 1).setValue(p);
		m.ID                = p;
		m.pylon_prop        = props.globals.getNode("sim/model/f-14b/systems/external-loads/").getChild("station", p);
		m.Tgt               = nil;
		m.TgtValid          = nil;
		m.TgtLon_prop       = nil;
		m.TgtLat_prop       = nil;
		m.TgtAlt_prop       = nil;
		m.update_track_time = 0;
		m.seeker_dev_e      = 0; # Seeker elevation, deg.
		m.seeker_dev_h      = 0; # Seeker horizon, deg.
		m.target_dev_e      = 0; # Target elevation, deg.
		m.target_dev_h      = 0; # Target horizon, deg.
		m.track_signal_e    = 0; # Seeker deviation change to keep constant angle (proportional navigation),
		m.track_signal_h    = 0; #   this is directly used as input signal for the steering command.
		m.t_coord = geo.Coord.new().set_latlon(0, 0);
		m.direct_dist_m     = nil;

		# AIM-9L specs:
		m.aim9_fov_diam     = getprop("sim/model/f-14b/systems/armament/aim9/fov-deg");
		m.aim9_fov          = m.aim9_fov_diam / 2;
		m.max_detect_rng    = getprop("sim/model/f-14b/systems/armament/aim9/max-detection-rng-nm");
		m.max_seeker_dev    = getprop("sim/model/f-14b/systems/armament/aim9/track-max-deg") / 2;
		m.force_lbs         = getprop("sim/model/f-14b/systems/armament/aim9/thrust-lbs");
		m.thrust_duration   = getprop("sim/model/f-14b/systems/armament/aim9/thrust-duration-sec");
		m.weight_launch_lbs = getprop("sim/model/f-14b/systems/armament/aim9/weight-launch-lbs");
		m.weight_whead_lbs  = getprop("sim/model/f-14b/systems/armament/aim9/weight-warhead-lbs");
		m.cd                = getprop("sim/model/f-14b/systems/armament/aim9/drag-coeff");
		m.eda               = getprop("sim/model/f-14b/systems/armament/aim9/drag-area");

		# Find the next index for "models/model" and create property node.
		# Find the next index for "ai/models/aim-9" and create property node.
		# (M. Franz, see Nasal/tanker.nas)
		var n = props.globals.getNode("models", 1);
		for (var i = 0; 1; i += 1)
			if (n.getChild("model", i, 0) == nil)
				break;
		m.model = n.getChild("model", i, 1);
		var n = props.globals.getNode("ai/models", 1);
		for (var i = 0; 1; i += 1)
			if (n.getChild("aim-9", i, 0) == nil)
				break;
		m.ai = n.getChild("aim-9", i, 1);

		m.ai.getNode("valid", 1).setBoolValue(1);
		var id_model = aim_9_model ~ m.ID ~ ".xml";
		m.model.getNode("path", 1).setValue(id_model);
		m.life_time = 0;

		# Create the AI position and orientation properties.
		m.latN   = m.ai.getNode("position/latitude-deg", 1);
		m.lonN   = m.ai.getNode("position/longitude-deg", 1);
		m.altN   = m.ai.getNode("position/altitude-ft", 1);
		m.hdgN   = m.ai.getNode("orientation/true-heading-deg", 1);
		m.pitchN = m.ai.getNode("orientation/pitch-deg", 1);
		m.rollN  = m.ai.getNode("orientation/roll-deg", 1);

		m.ac      = nil;
		m.coord   = nil;
		m.s_down  = nil;
		m.s_east  = nil;
		m.s_north = nil;
		m.alt     = nil;
		m.pitch   = nil;
		m.hdg     = nil;
		#m.last_coord = nil; # used to keep record of impact.
		#m.last_alt   = nil;

		SwSoundOnOff.setValue(1);

		settimer(func { SwSoundVol.setValue(vol_search); m.search() }, 1);
		return AIM9.active[m.ID] = m;

	},
	del: func {
		me.model.remove();
		me.ai.remove();
		delete(AIM9.active, me.ID);
	},
	release: func() {
		me.status = 2;
		me.animation_flags_props();

		# Get the A/C position and orientation values.
		me.ac = geo.aircraft_position();
		var ac_roll  = getprop("orientation/roll-deg");
		var ac_pitch = getprop("orientation/pitch-deg");
		var ac_hdg   = getprop("orientation/heading-deg");

		# Compute missile initial position relative to A/C center,
		# following Vivian's code in AIModel/submodel.cxx .
		var in = [0,0,0];
		var trans = [[0,0,0],[0,0,0],[0,0,0]];
		var out = [0,0,0];
		in[0] = me.pylon_prop.getNode("offsets/x-m").getValue() * M2FT;
		in[1] = me.pylon_prop.getNode("offsets/y-m").getValue() * M2FT;
		in[2] = me.pylon_prop.getNode("offsets/z-m").getValue() * M2FT;
		# Pre-process trig functions:
		cosRx = math.cos(-ac_roll * D2R);
		sinRx = math.sin(-ac_roll * D2R);
		cosRy = math.cos(-ac_pitch * D2R);
		sinRy = math.sin(-ac_pitch * D2R);
		cosRz = math.cos(ac_hdg * D2R);
		sinRz = math.sin(ac_hdg * D2R);
		# Set up the transform matrix:
		trans[0][0] =  cosRy * cosRz;
		trans[0][1] =  -1 * cosRx * sinRz + sinRx * sinRy * cosRz ;
		trans[0][2] =  sinRx * sinRz + cosRx * sinRy * cosRz;
		trans[1][0] =  cosRy * sinRz;
		trans[1][1] =  cosRx * cosRz + sinRx * sinRy * sinRz;
		trans[1][2] =  -1 * sinRx * cosRx + cosRx * sinRy * sinRz;
		trans[2][0] =  -1 * sinRy;
		trans[2][1] =  sinRx * cosRy;
		trans[2][2] =  cosRx * cosRy;
		# Multiply the input and transform matrices:
		out[0] = in[0] * trans[0][0] + in[1] * trans[0][1] + in[2] * trans[0][2];
		out[1] = in[0] * trans[1][0] + in[1] * trans[1][1] + in[2] * trans[1][2];
		out[2] = in[0] * trans[2][0] + in[1] * trans[2][1] + in[2] * trans[2][2];
		# Convert ft to degrees of latitude:
		out[0] = out[0] / (366468.96 - 3717.12 * math.cos(me.ac.lat() * D2R));
		# Convert ft to degrees of longitude:
		out[1] = out[1] / (365228.16 * math.cos(me.ac.lat() * D2R));
		# Set submodel initial position:
		var alat = me.ac.lat() + out[0];
		var alon = me.ac.lon() + out[1];
		var aalt = (me.ac.alt() * M2FT) + out[2];
		me.latN.setDoubleValue(alat);
		me.lonN.setDoubleValue(alon);
		me.altN.setDoubleValue(aalt);
		me.hdgN.setDoubleValue(ac_hdg);
		me.pitchN.setDoubleValue(ac_pitch);
		me.rollN.setDoubleValue(ac_roll);

		me.coord = geo.Coord.new().set_latlon(alat, alon);

		me.model.getNode("latitude-deg-prop", 1).setValue(me.latN.getPath());
		me.model.getNode("longitude-deg-prop", 1).setValue(me.lonN.getPath());
		me.model.getNode("elevation-ft-prop", 1).setValue(me.altN.getPath());
		me.model.getNode("heading-deg-prop", 1).setValue(me.hdgN.getPath());
		me.model.getNode("pitch-deg-prop", 1).setValue(me.pitchN.getPath());
		me.model.getNode("roll-deg-prop", 1).setValue(me.rollN.getPath());
		me.model.getNode("load", 1).remove();

		# Get initial velocity vector (aircraft):
		me.s_down = getprop("velocities/speed-down-fps");
		me.s_east = getprop("velocities/speed-east-fps");
		me.s_north = getprop("velocities/speed-north-fps");

		me.alt = aalt;
		me.pitch = ac_pitch;
		me.hdg = ac_hdg;

		me.smoke_prop.setBoolValue(1);
		SwSoundVol.setValue(0);
		settimer(func { HudReticleDeg.setValue(0) }, 2);
		interpolate(HudReticleDev, 0, 2);
		me.update();

	},
	update: func {
		var dt = getprop("sim/time/delta-sec");
		me.life_time += dt;

		# Cut rocket thrust after boost duration.
		var f_lbs = me.force_lbs;
		if (me.life_time > 2) {
			f_lbs = me.force_lbs * 0.3;
		}
		if (me.life_time > me.thrust_duration) {
			f_lbs = 0;
			me.smoke_prop.setBoolValue(0);
		}
		# Kill the AI after a while.
		if (me.life_time > 50) {
			return me.del();
		}

		# Get total speed.
		var d_east_ft  = me.s_east * dt;
		var d_north_ft = me.s_north * dt;
		var d_down_ft  = me.s_down * dt;
		var pitch_deg  = me.pitch;
		var hdg_deg    = me.hdg;
		var dist_h_ft  = math.sqrt((d_east_ft*d_east_ft)+(d_north_ft*d_north_ft));
		var total_s_ft = math.sqrt((dist_h_ft*dist_h_ft)+(d_down_ft*d_down_ft));

		# Get air density and speed of sound (fps):
		var alt_ft = me.altN.getValue();
		var rs = environment.rho_sndspeed(alt_ft);
		var rho = rs[0];
		var sound_fps = rs[1];

		# Adjust Cd by Mach number. The equations are based on curves
		# for a conventional shell/bullet (no boat-tail).
		var cdm = 0;
		var speed_m = (total_s_ft / dt) / sound_fps;
		if (speed_m < 0.7) {
			cdm = 0.0125 * speed_m + me.cd;
		} elsif (speed_m < 1.2 ){
			cdm = 0.3742 * math.pow(speed_m, 2) - 0.252 * speed_m + 0.0021 + me.cd;
		} else {
			cdm = 0.2965 * math.pow(speed_m, -1.1506) + me.cd;
		}

		# Add drag to the total speed using Standard Atmosphere (15C sealevel temperature);
		# rho is adjusted for altitude in environment.rho_sndspeed(altitude),
		# Acceleration = thrust/mass - drag/mass;
		var mass = me.weight_launch_lbs / slugs_to_lbs;
		var old_speed_fps = total_s_ft / dt;
		var acc = f_lbs / mass;

		var drag_acc = (cdm * 0.5 * rho * old_speed_fps * old_speed_fps * me.eda / mass);
		var speed_fps = old_speed_fps - drag_acc + acc;

		# Break down total speed to North, East and Down componcarrier-bindings.xmlents.
		var speed_down_fps = math.sin(pitch_deg * D2R) * speed_fps;
		var speed_horizontal_fps = math.cos(pitch_deg * D2R) * speed_fps;
		var speed_north_fps = math.cos(hdg_deg * D2R) * speed_horizontal_fps;
		var speed_east_fps = math.sin(hdg_deg * D2R) * speed_horizontal_fps;

		# Add gravity to the vertical speed (no ground interaction yet).
		speed_down_fps -= 32.1740485564 * dt;
		
		if ( me.status == 2 ) {
			var v = me.update_track();
			if ( ! v ) {
				# We exploded, but need a few more secs to spawn the explosion animation.
				settimer(func {
					me.del();
				}, 4 );
				return;
			}			
		}

		# Calculate altitude and elevation velocity vector (no incidence here).
		var alt_ft = me.altN.getValue() + (speed_down_fps * dt);
		pitch_deg = math.atan2( speed_down_fps, speed_horizontal_fps ) * R2D;

		# Apply steering command.
		pitch_deg += me.track_signal_e;
		hdg_deg += me.track_signal_h;

		# Get horizontal distance and set position and orientation.
		var dist_h_m = speed_horizontal_fps * dt * FT2M;
		me.last_coord = me.coord;
		me.coord.apply_course_distance(hdg_deg, dist_h_m);
		me.latN.setDoubleValue(me.coord.lat());
		me.lonN.setDoubleValue(me.coord.lon());
		me.altN.setDoubleValue(alt_ft);
		me.pitchN.setDoubleValue(pitch_deg);
		me.hdgN.setDoubleValue(hdg_deg);

		# record the velocities for the next loop.
		me.s_north = speed_north_fps;
		me.s_east = speed_east_fps;
		me.s_down = speed_down_fps;
		me.alt = alt_ft;
		#me.last_alt = me.alt;
		me.pitch = pitch_deg;
		me.hdg = hdg_deg;

		settimer(func me.update(), 0);
		
	},
	update_track: func() {
		if (me.status == 0) {
			# Status = searching.
			me.reset_seeker();
			SwSoundVol.setValue(vol_search);
			settimer(func me.search(), 0.1);
			return(1);
		}
		if ( me.status == -1 ) {
			# Status = stand-by.
			me.reset_seeker();
			SwSoundVol.setValue(0);
			return(1);
		}
		if (!me.Tgt.Valid.getValue()) {
			# Lost of lock due to target disapearing:
			# return to search mode.
			me.status = 0;
			me.reset_seeker();
			SwSoundVol.setValue(vol_search);
			settimer(func me.search(), 0.1);
			return(1);
		}
		# Time interval since lock time or last track loop.
		var time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
		var dt = time - me.update_track_time;
		me.update_track_time = time;
		var last_tgt_e = me.target_dev_e;
		var last_tgt_h = me.target_dev_h;
		if (me.status == 1) {		
			# Status = locked. Get target position relative to our aircraft.
			var curr_tgt_e = me.Tgt.get_total_elevation(OurPitch.getValue());
			var curr_tgt_h = me.Tgt.get_deviation(OurHdg.getValue());
		} else {
			# Status = launched. Get target position relative to the missile.
			var t_lon = me.TgtLon_prop.getValue();
			var t_lat = me.TgtLat_prop.getValue();
			var t_alt = me.TgtAlt_prop.getValue();
			me.t_coord.set_latlon(t_lat, t_lon, t_alt);
			var t_dist_m = me.coord.distance_to(me.t_coord);
			var t_alt_delta_m = (t_alt - me.alt) * FT2M;
			var t_elev_deg =  math.atan2( t_alt_delta_m, t_dist_m ) * R2D;
			var curr_tgt_e = t_elev_deg - me.pitch;
			var t_course = me.coord.course_to(me.t_coord);
			var curr_tgt_h = t_course - me.hdg;

			var dir_dist_m = math.sqrt((t_dist_m*t_dist_m)+(t_alt_delta_m*t_alt_delta_m));
			if ( me.direct_dist_m != nil ) {
				if ( dir_dist_m > me.direct_dist_m and me.direct_dist_m < 25 ) {
					var wh_mass = me.weight_whead_lbs / slugs_to_lbs;
					print("FOX2: me.direct_dist_m = ",  me.direct_dist_m, " time ",getprop("sim/time/elapsed-sec"));
					impact_report(me.coord, me.alt * FT2M, wh_mass, "missile"); # pos, alt, mass_slug,(speed_mps)
					var phrase = sprintf( "%01.0f", me.direct_dist_m) ~ "meters";
					if (getprop("sim/model/f-14b/systems/armament/mp-messaging")) {
						setprop("/sim/multiplay/chat", phrase);
					} else {
						setprop("/sim/messages/atc", phrase);
					}
					me.animate_explosion();
					return(0);
				}
			}
			me.direct_dist_m = dir_dist_m;
		}
		# Compute target deviation variation then  seeker move to keep this deviation constant..
		me.target_dev_e = curr_tgt_e;
		me.target_dev_h = curr_tgt_h;
		me.track_signal_e = curr_tgt_e - last_tgt_e;
		me.track_signal_h = curr_tgt_h - last_tgt_h;
		# Compute seeker total angular position clamped to seeker max total angular rotation.
		me.seeker_dev_e += me.track_signal_e;
		me.seeker_dev_e = me.clamp_min_max(me.seeker_dev_e, me.max_seeker_dev);
		me.seeker_dev_h += me.track_signal_h;
		me.seeker_dev_h = me.clamp_min_max(me.seeker_dev_h, me.max_seeker_dev);
		if ( me.status == 1 ) {
			# Compute HUD reticle position.
			var h_rad = (90 - curr_tgt_h) * D2R;
			var e_rad = (90 - curr_tgt_e) * D2R; 
			var devs = f14_hud.develev_to_devroll(h_rad, e_rad);
			var combined_dev_deg = devs[0];
			var combined_dev_length =  devs[1];
			var clamped = devs[2];
			if ( clamped ) {
				SW_reticle_Blinker.blink();
			} else {
				SW_reticle_Blinker.cont();
			}
			HudReticleDeg.setValue(combined_dev_deg);
			HudReticleDev.setValue(combined_dev_length);
		}
		# Check target signal inside seeker FOV.
		var e_d = me.seeker_dev_e - me.aim9_fov;
		var e_u = me.seeker_dev_e + me.aim9_fov;
		var h_l = me.seeker_dev_h - me.aim9_fov;
		var h_r = me.seeker_dev_h + me.aim9_fov;
		if ( curr_tgt_e < e_d or curr_tgt_e > e_u or curr_tgt_h < h_l or curr_tgt_h > h_r ) {
			if ( me.status == 1 ) {
				me.status = 0;
				me.Tgt = nil;# FIXME, move down when no more tests needed.
				SwSoundVol.setValue(vol_search);
			} elsif ( me.status == 2 ) {
				me.free = 1;
				me.reset_steering();
				return(1);
			}		
			# Target out of FOV, return to search loop.
			me.reset_seeker();
			me.reset_steering();
			settimer(func me.search(), 2);
			return(1);
		}
		if ( me.status != 2 and me.status != -1 ) {
			# We are not launched yet: update_track() loops by itself at 10 Hz.
			SwSoundVol.setValue(vol_track);
			settimer(func me.update_track(), 0.1);
		}
		return(1);
	},
	search: func {
		if ( me.status == -1 ) {
			# Stand by.
			SwSoundVol.setValue(0);
			return;
		} elsif ( me.status > 0 ) {
			# Locked or fired.
			return;
		}
		# search.
		if ( awg_9.nearest_u != nil and awg_9.nearest_u.Valid.getValue()) {
			var tgt = awg_9.nearest_u; # In the AWG-9 radar range and horizontal field.
			var rng = tgt.get_range();
			var total_elev  = tgt.get_total_elevation(OurPitch.getValue()); # deg.
			var total_horiz = tgt.get_deviation(OurHdg.getValue());         # deg.
			# Check if in range and in the (square shaped here) seeker FOV.
			var abs_total_elev = math.abs(total_elev);
			var abs_dev_deg = math.abs(total_horiz);
			if (rng < me.max_detect_rng and abs_total_elev < me.aim9_fov_diam and abs_dev_deg < me.aim9_fov_diam ) {
				me.status = 1;
				SwSoundVol.setValue(vol_weak_track);
				me.Tgt = tgt;
				var t_pos_str = me.Tgt.string ~ "/position";
				me.TgtLon_prop       = props.globals.getNode(t_pos_str).getChild("longitude-deg");
				me.TgtLat_prop       = props.globals.getNode(t_pos_str).getChild("latitude-deg");
				me.TgtAlt_prop       = props.globals.getNode(t_pos_str).getChild("altitude-ft");
				settimer(func me.update_track(), 2);
				return;
			}
		}
		SwSoundVol.setValue(vol_search);
		settimer(func me.search(), 0.1);
	},
	reset_steering: func {
		me.track_signal_e = 0;
		me.track_signal_h = 0;
	},
	reset_seeker: func {
		me.curr_tgt_e     = 0;
		me.curr_tgt_h     = 0;
		me.seeker_dev_e   = 0;
		me.seeker_dev_h   = 0;
		me.target_dev_e   = 0;
		me.target_dev_h   = 0;
		settimer(func { HudReticleDeg.setValue(0) }, 2);
		interpolate(HudReticleDev, 0, 2);
		me.reset_steering()
	},
	clamp_min_max: func (v, mm) {
		if ( v < -mm ) {
			v = -mm;
		} elsif ( v > mm ) {
			v = mm;
		}
	return(v);
	},
	animation_flags_props: func {
		# Create animation flags properties.
		var msl_path = "sim/model/f-14b/systems/armament/aim9/flags/msl-id-" ~ me.ID;
		me.msl_prop = props.globals.initNode( msl_path, 1, "BOOL" );
		var smoke_path = "sim/model/f-14b/systems/armament/aim9/flags/smoke-id-" ~ me.ID;
		me.smoke_prop = props.globals.initNode( smoke_path, 0, "BOOL" );
		var explode_path = "sim/model/f-14b/systems/armament/aim9/flags/explode-id-" ~ me.ID;
		me.explode_prop = props.globals.initNode( explode_path, 0, "BOOL" );
		var explode_smoke_path = "sim/model/f-14b/systems/armament/aim9/flags/explode-smoke-id-" ~ me.ID;
		me.explode_smoke_prop = props.globals.initNode( explode_smoke_path, 0, "BOOL" );
	},
	animate_explosion: func {
		me.msl_prop.setBoolValue(0);
		me.smoke_prop.setBoolValue(0);
		me.explode_prop.setBoolValue(1);
		settimer( func me.explode_prop.setBoolValue(0), 0.5 );
		settimer( func me.explode_smoke_prop.setBoolValue(1), 0.5 );
		settimer( func me.explode_smoke_prop.setBoolValue(0), 3 );
	},
	active: {},
};


# Create impact report.

#altitde-agl-ft DOUBLE
#impact
#	elevation-m DOUBLE
#	heading-deg DOUBLE
#	latitude-deg DOUBLE
#	longitude-deg DOUBLE
#	pitch-deg DOUBLE
#	roll-deg DOUBLE
#	speed-mps DOUBLE
#	type STRING
#valid "true" BOOL


var impact_report = func(pos, alt, mass_slug, string) {

	# Find the next index for "ai/models/model-impact" and create property node.
	var n = props.globals.getNode("ai/models", 1);
	for (var i = 0; 1; i += 1)
		if (n.getChild(string, i, 0) == nil)
			break;
	var impact = n.getChild(string, i, 1);

	impact.getNode("impact/elevation-m", 1).setValue(alt);
	impact.getNode("impact/latitude-deg", 1).setValue(pos.lat());
	impact.getNode("impact/longitude-deg", 1).setValue(pos.lon());
	impact.getNode("mass-slug", 1).setValue(mass_slug);
	#impact.getNode("speed-mps", 1).setValue(speed_mps);
	impact.getNode("valid", 1).setBoolValue(1);
	impact.getNode("impact/type", 1).setValue("terrain");

	var impact_str = "/ai/models/" ~ string ~ "[" ~ i ~ "]";
	setprop("ai/models/model-impact", impact_str);

}



# HUD clamped target blinker
SW_reticle_Blinker = aircraft.light.new("sim/model/f-14b/lighting/hud-sw-reticle-switch", [0.1, 0.1]);
setprop("sim/model/f-14b/lighting/hud-sw-reticle-switch/enabled", 1);












