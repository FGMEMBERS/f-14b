#---------------------------------------------------------------------------
#
#	Title                : AN/SPN-46 Precision Approach Landing System (PALS)
#
#	File Type            : Implementation File
#
#	Description          : Representative emulation of the functions of the AN/SPN-46 using emesary
#                        : Where an AN/SPN-46 is required it is sufficient to instantiate a ANSPN46_System connected to the instantiator model.
#	                     : Register with an instance of a Transmitter, and provide a Receive method, periodically send out Active messages
#                        : expecting ActiveResponse messages which may result in a Communication.
#                        : This is implemented as a set of messages that models the operation of the PALS
#  
#   References           : http://trace.tennessee.edu/cgi/viewcontent.cgi?article=3297&context=utk_gradthes
#                        : http://www.navair.navy.mil/index.cfm?fuseaction=home.displayPlatform&key=E8D18768-14B6-4CF5-BAB5-12B009070CFC
#                        : http://www.afceaboston.com/documents/events/cnsatm2010/Briefs/4%20-%20Friday/03-Navy_Landing_Systems_Roadmap-(CDR%20Easler).pdf
#
#	Author               : Richard Harrison (richard@zaretto.com)
#
#	Creation Date        : 29 January 2016
#
#	Version              : 4.8
#
#  Copyright © 2016 Richard Harrison           Released under GPL V2
#
#---------------------------------------------------------------------------*/
#Message Reference:
#---------------------------------------------------------------------------*/
# Notification 1 ANSPN46ActiveNotification  from carrier to aircraft
#   Transmitted via GlobalTransmitter at 1hz
#    - carrier position
#    - beam start
#    - beam angle
#    - channel / frequency information
#    - beam range / power
#
# Notification 2 - from aircraft to carrier
#    - aircraft position
#    - radar return size
#    - aircraft altitude, heading, velocity
#    - respose indicating tuned or not
#
# Notification 3 - from carrier to aircraft
#    - lateral deviation 
#    - vertical deviation
#    - LSO information / messages
#    - system status
#    - lateral 
#
#Operation:
#---------------------
# The ANSPN64 system will send periodically send out a ANSPN46ActiveNotification
# the rest of the logic within this system related to aircraft will be handled when
# the ANSPN46ActiveResponseNotification - which itself in turn will send out a ANSPN46CommunicationNotification
#----------------------
# NOTE: to avoid garbage collection all of the notifications that are sent out are created during construction
#       and simply modified prior to sending. This works because emesary is synchronous and therefore the state
#       and lifetime are known.

#
# Notification(1) from carrier to any aircraft within range.
#
var ANSPN46ActiveNotification = 
{
    # Create a new active notification notification. Aircraft will respond to this.
    # param(_anspn46_system): instance of ANSPN46_System which will send the notification 
    new: func(_anspn46_system)
    {
        var ident="none";
        if (_anspn46_system != nil)
            ident=_anspn46_system.Ident;

        var new_class = emesary.Notification.new("ANSPN46ActiveNotification", ident);

        new_class.ANSPN46_system = _anspn46_system;
        new_class.Position = nil;
        new_class.BeamPosition = nil;

        new_class.BeamAngle = 35;
        new_class.Channel = 2;
        new_class.BeamRange = 35; ##nm
        new_class.BeamPower = 999; ## mw ???

        #
        # Set notification properties from the ANSPN46_System. 
        new_class.set_from = func(_anspn)
        {
            if (_anspn != nil)
            {
                me.Ident = _anspn.Ident;
                me.Position = _anspn.GetCarrierPosition();
                me.BeamPosition = _anspn.GetTDZPosition();

                me.BeamAngle = 35;
                me.Channel = _anspn.GetChannel();
                me.BeamRange = 35; ##nm
                me.BeamPower = 999; ## mw ???
            }
        };
        new_class.bridgeProperties = func
        {
            return 
            [ 
             {
            getValue:func{return emesary.TransferCoord.encode(new_class.Position);},
            setValue:func(v){new_class.Position=emesary.TransferCoord.decode(v);}, 
             },
             {
            getValue:func{return emesary.TransferByte.encode(new_class.Channel);},
            setValue:func(v){new_class.Channel=emesary.TransferByte.decode(v);}, 
             },
            ];
          };
        new_class.set_from(new_class.ANSPN46_system);
        return new_class;
    },
};

# Notification(2) - from aircraft to carrier sent in response to Notification(1) above
#
var ANSPN46ActiveResponseNotification = 
{
    new: func(_ident)
    {
        var new_class = emesary.Notification.new("ANSPN46ActiveResponseNotification", _ident);
        new_class.Respond = func(_msg)
        {
            new_class.Position = geo.aircraft_position();
            new_class.Heading = getprop("orientation/heading-deg");
            new_class.RadarReturnStrength = 1; # normalised value based on RCS beam power etc.
            new_class.Tuned = 0; # 0 or 1
            new_class.ufps = getprop("velocities/uBody-fps");
            return me;
        }
        return new_class;
    },
};

# Notification 3 - from carrier to aircraft as a result of active response notification
#    - only sent if the aircraft is set to the same channel that we are transmitting on
#
var ANSPN46CommunicationNotification = 
{
    new: func(_ident, _anspn46_system)
    {
        var new_class = emesary.Notification.new("ANSPN46CommunicationNotification", _ident);
        new_class.Model = _anspn46_system.Model;

        new_class.set_from = func(_ident, _msg, _anspn46_system)
        {
            var carrier_ara_63_position = _anspn46_system.GetCarrierPosition();
            var carrier_heading = _anspn46_system.GetCarrierHeading();
            var carrier_ara_63_heading = 0;

# relative offset of the course to the tdz
# according to my measurements the Nimitz class is 8.1362114 degrees (measured 178 vs carrier 200 allowing for local magvar -13.8637886)
# i.e. this value is from tuning rather than calculation

            if (carrier_heading != nil)
                carrier_ara_63_heading = carrier_heading.getValue() - 8.1362114;

            var range = _msg.Position.distance_to(carrier_ara_63_position);
            var bearing_to = _msg.Position.course_to(carrier_ara_63_position);
            var deviation = bearing_to - carrier_ara_63_heading;

            deviation = deviation *0.1;
            me.ReturnPosition = _msg.Position;
            me.ReturnBearing = getprop("orientation/heading-deg");

# the AN/SPN 46 has a 20nm range with a 3 degree beam; ref: F14-AAD-1 17.3.2
            if (range < 37000 and abs(deviation) < 3) 
            {
                var FD_TAN3DEG = math.tan(3.0 / 57.29577950560105);
                var deck_height=20;
                var gs_height = ((range*FD_TAN3DEG)) + deck_height;
                var gs_deviation = (gs_height - _msg.Position.alt()) / 42.0; 

                if (gs_deviation > 1)
                    gs_deviation = 1;
                else if (gs_deviation < -1) 
                    gs_deviation = -1;

# if not in range message will not be transmitted.
                me.InRange = 1; 

# calculate the deviation from the ideal approach
                me.VerticalAdjustmentCommanded = gs_deviation;
                me.HorizontalAdjustmentCommanded = deviation;

                me.LateralDeviation = deviation;
                me.VerticalDeviation = gs_deviation;

                me.Distance = range;

                me.SignalQualityNorm = 1;

#
# work out the rough ETA for the 10 seconds light, and use this
# to decide whether or not to waveoff
                var eta = range / (_msg.ufps / 3.281);

                if(eta <= 10 and range < 800 and range > 150)
                {
                    me.TenSeconds = 1;
                    if(math.abs(deviation) > 0.2 or math.abs(gs_deviation) > 0.2)
                    {
                        me.WaveOff = 1;
                    }
                    else
                    {
                        me.WaveOff = 0;
                    }
                }
                else
                {
                    me.TenSeconds = 0;
                    me.WaveOff = 0;
                }
                me.LSOMessage = "";
                me.SystemStatus = "OK"; # Wave off, error, etcc.
                                            }
            else
            {
#
# No response will be sent when not in range; so ensure values are all cleared.
                me.InRange = 0; 
                me.VerticalAdjustmentCommanded = 0;
                me.HorizontalAdjustmentCommanded = 0;
                me.SignalQualityNorm =0;
                me.Distance = -10000000000;
                me.TenSeconds = 0;
                me.WaveOff = 0;
                me.InRange = 0;
                me.VerticalDeviation = 0;
                me.LateralDeviation = 0;
                me.LSOMessage = "";
                me.SystemStatus = "";
            }
        };
        return new_class;
    },
};

#
# The main AN/SPN46 system implemented using emesary.
# Periodically the Update method should be called, which will
# send out a notification via the global transmitter so that aircraft within range
# can respond. This is similar to a radar transmit and return.
# There should be an instance of this class created in the nasal section of the model xml
# Once an aircraft is within range it will receive guidance that can be displayed.
# It is the responsibility of the AN/SPN system to decided whether a craft is within range.
# It is the responsibility of the aircraft receiver to indicate whether it is tuned in or not
# if it the aircraft is not tuned into the right channel the receiver (e.g. ARA-63) will not receive anything; however
# the AN/SPN system (being a radar) will still have guidance information that could be relayed over the
# comms channel or displayed on a radar display on the carrier.
#
var ANSPN46_System = 
{
    new: func(_ident,_model)
    {
        var new_class = emesary.Recipient.new(_ident~".ANSPN46");

        new_class.ara_63_position = geo.Coord.new();
        new_class.Model = _model;
        new_class.communicationNotification = ANSPN46CommunicationNotification.new(new_class.Ident, new_class);
        new_class.Channel = 2;
        new_class.UpdateRate = 10;

#-------------------------------------------
# Receive override:
# Iinterested in receiving ANSPN46ActiveResponseNotification. When we get
# one of these we can respond with a CommunicationNotification

        new_class.Receive = func(notification)
        {
            if (notification.NotificationType == "ANSPN46ActiveResponseNotification")
            {
                if (notification.Tuned)
                {
                    me.communicationNotification.set_from(me.Ident, notification, me);
                    if(me.communicationNotification.InRange)
                    {
                        me.UpdateRate = 0.2;
                        emesary.GlobalTransmitter.NotifyAll(me.communicationNotification);
                    }
                }
                return emesary.Transmitter.ReceiptStatus_OK;
            }
            return emesary.Transmitter.ReceiptStatus_NotProcessed;
        }
#
# Interface methods
#-----------------------------
# Required interface to get the current carrier position
        new_class.GetCarrierPosition = func()
        {
            var x = me.Model.getNode("position/global-x").getValue() + 88.7713542;
            var y = me.Model.getNode("position/global-y").getValue() + 18.74631309;
            var z = me.Model.getNode("position/global-z").getValue() + 115.6574875;
            me.ara_63_position.set_xyz(x, y, z);
            return me.ara_63_position;
        };
#
# Interface to get the carrier heading
        new_class.GetCarrierHeading = func()
        {
            return me.Model.getNode("orientation/true-heading-deg");
        };
#
# offset of the TDZ (wires) from the carrier centre
        new_class.GetTDZPosition = func
        {
            return me.ara_63_position;
        };
#
# radar beam angle
        new_class.GetUpdateRate = func
        {
            return me.UpdateRate;
        };
        new_class.BeamAngle = func
        {
            return 30;
        };
#
# currently transmitting channel number.
        new_class.GetChannel = func
        {
            return me.Channel;
        };
        new_class.SetChannel = func(v)
        {
            me.Channel = v;
        };
#
# main entry point. The object itself will manage the update rate - but it is
# up to the caller to use this rate
        new_class.Update = func
        {
            # fill in properties of message
            me.msg.set_from(me);
            
            #
            # manage the update rate; increase each frame until we get to 10 seconds
            # this will be reset if we receive something back from the aircraft.
            if (me.UpdateRate < 10)
                me.UpdateRate = me.UpdateRate+1;
            return emesary.GlobalTransmitter.NotifyAll(me.msg);
        };

#
# create the message that will be used to notify of an active carrier. This needs to be done after the methods 
# have been created as it references them. Implemented like this to reduce garbage collection
        new_class.msg = ANSPN46ActiveNotification.new(new_class);

        emesary.GlobalTransmitter.Register(new_class);
        return new_class;
    },
}
