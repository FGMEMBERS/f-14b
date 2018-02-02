 #---------------------------------------------------------------------------
 #
 #	Title                : EMESARY flightgear standardised notifications
 #
 #	File Type            : Implementation File
 #
 #	Description          : Messages that are applicable across all models and do not specifically relate to a single sysmte
 #	                     : - mostly needed when using the mutiplayer bridge
 #
 #	Author               : Richard Harrison (richard@zaretto.com)
 #
 #	Creation Date        : 06 April 2016
 #
 #	Version              : 4.8
 #
 #  Copyright � 2016 Richard Harrison           Released under GPL V2
 #
 #---------------------------------------------------------------------------*/

#
# Ideally for notifications bridged over MP the message ID should be system unique.
# with that in mind 0-16 are reserved for model use; and may well be marked as not bridgeable
# however the most important thing is that as these notifications ID's are used the
# wiki page  http://wiki.flightgear.org/Emesary_Notifications
var PropertySyncNotificationBase_Id = 16;
var AircraftControlNotification_Id = 17;
var GeoEventNotification_Id = 18;
# event ID 19 reserved for armaments and stores (model defined).
var PFDEventNotification_Id = 20;

#
# PropertySyncNotificationBase is a wrapper class for allow properties to be synchronized between
# modules. This can replace (or augment) the properties that are normally transmitted by multiplayer
# It is reasonably efficient with the MP2017.2
#
# Usage example - this can all go into one Nasal module somewhere.
#-----------
# var PropertySyncNotification =
# {
#    new: func(_ident="none", _name="", _kind=0, _secondary_kind=0)
#    {
#        var new_class = PropertySyncNotificationBase.new(_ident, _name, _kind, _secondary_kind);
#
#        new_class.addIntProperty("consumables/fuel/total-fuel-lbs", 1);
#        new_class.addIntProperty("controls/fuel/dump-valve", 1);
#        new_class.addIntProperty("engines/engine[0]/augmentation-burner", 1);
#        new_class.addIntProperty("engines/engine[0]/n1", 1);
#        new_class.addIntProperty("engines/engine[0]/n2", 1);
#        new_class.addNormProperty("surface-positions/wing-pos-norm", 2);
#        return new_class;
#    }
#};
#
#var routedNotifications = [notifications.PropertySyncNotification.new(nil), notifications.GeoEventNotification.new(nil)];
#
#var bridgedTransmitter = emesary.Transmitter.new("outgoingBridge");
#var outgoingBridge = emesary_mp_bridge.OutgoingMPBridge.new("F-14mp",routedNotifications, 19, "", bridgedTransmitter);
#var incomingBridge = emesary_mp_bridge.IncomingMPBridge.startMPBridge(routedNotifications);
#var f14_aircraft_notification = notifications.PropertySyncNotification.new("F-14"~getprop("/sim/multiplay/callsign"));
#-----------
#
# That's all that is required to ship properties between multiplayer modules via emesary.
# property /sim/multiplay/transmit-filter-property-base can be set to 1 to turn off all of the standard properties and only send generics.
# this will give a packet size of 280 bytes; leaving lots of space for notifications. 
# The F-14 packet size is around 53 bytes on 2017.2 compared to over 1100 bytes with the traditional method.
# property /sim/multiplay/transmit-filter-property-base can be set to a number greater than 1 (e.g. 12000) to only transmit properties
# where the ID is greater than the value in the property. This can further reduce packet size by only transmitting the emesary bridge data
#
# The other advantage with this method of transferring data is that the model is in full control of what is
# sent, and also when it is sent. This works on a per notification basis so less important properties could be
# transmitted on a less frequent schedule; however this will require an instance of the notification for each one.
#
# PropertySyncNotificationBase is a shortcut notification; as it doesn't need to received and all
# of the properties are simply set when the notification is unpacked over MP.
# So although the notification will be transmitted
var PropertySyncNotificationBase =
{
    new: func(_ident="none", _name="", _kind=0, _secondary_kind=0)
    {
        var new_class = emesary.Notification.new("PropertySyncNotification", _ident, PropertySyncNotificationBase_Id);

        new_class.IsDistinct = 1;
        new_class.Kind = _kind;
        new_class.Name = _name;
        new_class.SecondaryKind = _secondary_kind;
        new_class.Callsign = nil; # populated automatically by the incoming bridge when routed
        new_class._bridgeProperties = [];

        new_class.addIntProperty = func(variable, property, length)
        {
            me[variable] = nil;
            append(me._bridgeProperties,
                   {
                       getValue:func{return emesary.TransferInt.encode(getprop(property) or 0,length);},
                       setValue:func(v,bridge,pos){var dv=emesary.TransferInt.decode(v,length,pos);me[variable]=dv.value;setprop(bridge.PropertyRoot~property, me[variable]);return dv;},
                   });
        }
        new_class.addNormProperty = func(variable, property, length)
        {
            me[variable] = nil;
            append(me._bridgeProperties,
                   {
                       getValue:func{return emesary.TransferNorm.encode(getprop(property) or 0,length);},
                       setValue:func(v,bridge,pos){var dv=emesary.TransferNorm.decode(v,length,pos);me[variable] = dv.value;setprop(bridge.PropertyRoot~property, me[variable]);return dv;},
                   });
        }

        new_class.addStringProperty = func(variable, property)
        {
            me[variable] = nil;
            append(me._bridgeProperties,
                   {
                       getValue:func{return emesary.TransferString.encode(getprop(property) or 0);},
                       setValue:func(v,bridge,pos){var dv=emesary.TransferString.decode(v,pos);me[variable] = dv.value;setprop(bridge.PropertyRoot~property, me[variable]);return dv;},
                   });

        }
        new_class.bridgeProperties = func()
        {
            return me._bridgeProperties;
        }
        return new_class;
    }
};
#
# Transmit a generic control event.
# two parameters - the event Id and the event value which is a 4 byte length (+/- 1,891371.000)
var AircraftControlNotification =
{
    new: func(_ident="none")
    {
        var new_class = emesary.Notification.new("AircraftControlNotification", _ident, AircraftControlNotification_Id);

        new_class.IsDistinct = 0;
        new_class.EventType = 0;
        new_class.EventValue = 0;
        new_class.Callsign = nil; # populated automatically by the incoming bridge when routed

        new_class.bridgeProperties = func
        {
            return
            [
             {
            getValue:func{return emesary.TransferInt.encode(new_class.EventType,2);},
            setValue:func(v,bridge,pos){var dv=emesary.TransferInt.decode(v,2,pos);new_class.EventType=dv.value;return dv;},
             },
             {
            getValue:func{return emesary.TransferFixedDouble.encode(new_class.EventValue,4,1000);},
            setValue:func(v,bridge,pos){var dv=emesary.TransferFixedDouble.decode(v,4,1000,pos);new_class.EventValue=dv.value;print("dec ",dv.value);return dv;},
             },
            ];
        };
        return new_class;
    }
};

#
#
# Use to transmit events that happen at a specific place; can be used to make
# models that are simulated locally (e.g. tankers) appear on other player's MP sessions.
var GeoEventNotification =
{
# new:
# _ident - the identifier for the notification. not bridged.
# _name - name of the notification, bridged.
# _kind - created, moved, deleted (see below). This is the activity that the  notification represents, called kind to avoid confusion with notification type.
# _secondary_kind - This is the entity on which the activity is being performed. See below for predefined types.
##
    new: func(_ident="none", _name="", _kind=0, _secondary_kind=0)
    {
        var new_class = emesary.Notification.new("GeoEventNotification", _ident, GeoEventNotification_Id);

        new_class.Kind = _kind;
        new_class.Name = _name;
        new_class.SecondaryKind = _secondary_kind;
        new_class.Position = geo.aircraft_position();
        new_class.UniqueIndex = 0;

        new_class.Heading = getprop("/orientation/heading");
        new_class.u_fps = getprop("/velocities/uBody-fps");
        new_class.v_fps = getprop("/velocities/vBody-fps");
        new_class.w_fps = getprop("/velocities/wBody-fps");
        new_class.IsDistinct = 0;
        new_class.Callsign = nil; # populated automatically by the incoming bridge when routed
        new_class.RemoteCallsign = ""; # associated remote callsign.
        new_class.Flags = 0; # 8 bits for whatever.

        new_class.GetBridgeMessageNotificationTypeKey = func {
            return new_class.NotificationType~"."~new_class.Ident~"."~new_class.UniqueIndex;
        };
        new_class.bridgeProperties = func
        {
            return
            [
             {
            getValue:func{return emesary.TransferCoord.encode(new_class.Position);},
            setValue:func(v,root,pos){var dv=emesary.TransferCoord.decode(v, pos);new_class.Position=dv.value;return dv},
             },
             {
            getValue:func{return emesary.TransferString.encode(new_class.Name);},
            setValue:func(v,root,pos){var dv=emesary.TransferString.decode(v,pos);new_class.Name=dv.value;return dv},
             },
             {
            getValue:func{return emesary.TransferByte.encode(new_class.Kind);},
            setValue:func(v,root,pos){var dv=emesary.TransferByte.decode(v,pos);new_class.Kind=dv.value;return dv},
             },
             {
            getValue:func{return emesary.TransferByte.encode(new_class.SecondaryKind);},
            setValue:func(v,root,pos){var dv=emesary.TransferByte.decode(v,pos);new_class.SecondaryKind=dv.value;return dv},
             },
             {
            getValue:func{return emesary.TransferFixedDouble.encode(new_class.u_fps,2,10);},
            setValue:func(v,root,pos){var dv=emesary.TransferFixedDouble.decode(v,2,10,pos);new_class.u_fps=dv.value;return dv},
             },
             {
            getValue:func{return emesary.TransferFixedDouble.encode(new_class.v_fps,2,10);},
            setValue:func(v,root,pos){var dv=emesary.TransferFixedDouble.decode(v,2,10,pos);new_class.v_fps=dv.value;return dv},
             },
             {
            getValue:func{return emesary.TransferFixedDouble.encode(new_class.w_fps,2,10);},
            setValue:func(v,root,pos){var dv=emesary.TransferFixedDouble.decode(v,2,10,pos);new_class.w_fps=dv.value;return dv},
             },
             {
            getValue:func{return emesary.TransferString.encode(new_class.RemoteCallsign);},
            setValue:func(v,root,pos){var dv=emesary.TransferString.decode(v,pos);new_class.RemoteCallsign=dv.value;return dv},
             },
             {
            getValue:func{return emesary.TransferByte.encode(new_class.Flags);},
            setValue:func(v,root,pos){var dv=emesary.TransferByte.decode(v,pos);new_class.Flags=dv.value;return dv},
             },
            ];
          };
        return new_class;
    },
};
#
# Defined kinds:
#    1 - Created
#    2 - Moved
#    3 - Deleted
#    4 - Collision
# ----
# Secondary kind (8 bits)
# using the first 4 bits as the classification and the second 4 bits as the sub-classification
#-----------
# Type 0000 : Cargo
#   0 0000 0000 - Vehicle
#   1 0000 0001 - Person
#   2 0000 0010 - 10 kg Item
#   3 0000 0011 - 20 kg Item
#   4 0000 0100 - 30 kg Item
#   5 0000 0101 - 40 kg Item
#   6 0000 0110 - 50 kg Item
#   7 0000 0111 - 100 kg Item
#   8 0000 1000 - 200 kg Item
#   9 0000 1001 - 500 kg Item
#  10 0000 1010 - 1000 kg Item
#  11 0000 1011 - Chaff
#  12 0000 1100 - Flares
#  13 0000 1101 - Water (fire fighting)
#  14 0000 1110 -
#  15 0000 1111 - Morris Marina
#--------
# Type 0001 : Self propelled
#  16 0001 0000 - X-2
#  17 0001 0001 - X-15
#  18 0001 0010 - X-24
#  19 0001 0011 -
#  20 0001 0100 -
#  21 0001 0101 -
#  22 0001 0110 -
#  23 0001 0111 -
#  24 0001 1000 -
#  25 0001 1001 -
#  26 0001 1010 -
#  27 0001 1011 -
#  28 0001 1100 -
#  29 0001 1101 -
#  30 0001 1110 -
#  31 0001 1111 -
#--------
# Type 0010 : Aircraft Damage (e.g space shuttle re-entry or during launch)
#  32 0010 0000 - Engine 1
#  33 0010 0001 - Engine 2
#  34 0010 0010 - Engine 3
#  35 0010 0011 - Engine 4
#  36 0010 0100 - Engine 5
#  37 0010 0101 - Engine 6
#  38 0010 0110 - Engine 7
#  39 0010 0111 - Engine 8
#  40 0010 1000 - Vertical Tail Right
#  41 0010 1001 - Left Wing
#  42 0010 1010 - Right Wing
#  43 0010 1011 - Horizontal Tail Left
#  44 0010 1100 - Horizontal Tail Right
#  45 0010 1101 - Fuselage Front
#  46 0010 1110 - Fuselage Center
#  47 0010 1111 - Fuselage Back
#--------
# Type 0011 : External stores
#  48 0011 0000 - Drop Tank 1
#  49 0011 0001 - Drop Tank 2
#  50 0011 0010 - Drop Tank 3
#  51 0011 0011 - Drop Tank 4
#  52 0011 0100 -
#  53 0011 0101 -
#  54 0011 0110 -
#  55 0011 0111 -
#  56 0011 1000 -
#  57 0011 1001 -
#  58 0011 1010 -
#  59 0011 1011 -
#  60 0011 1100 -
#  61 0011 1101 -
#  62 0011 1110 -
#  63 0011 1111 -
#--------
# Type 0100 :
#  64 0100 0000 -
#  65 0100 0001 -
#  66 0100 0010 -
#  67 0100 0011 -
#  68 0100 0100 -
#  69 0100 0101 -
#  70 0100 0110 -
#  71 0100 0111 -
#  72 0100 1000 -
#  73 0100 1001 -
#  74 0100 1010 -
#  75 0100 1011 -
#  76 0100 1100 -
#  77 0100 1101 -
#  78 0100 1110 -
#  79 0100 1111 -
#--------
# Type 0101 : Models/Geometry items
#  80 0101 0000 - Aim91x.ac
#  81 0101 0001 - Bomb-500lbs-MC/bomb-500lbs-mc.ac
#  82 0101 0010 - Clemenceau/tracteur.ac
#  83 0101 0011 - Crater/crater.ac
#  84 0101 0100 - Ensign.ac
#  85 0101 0101 - Nimitz/Models/phalanx.ac
#  86 0101 0110 - Nimitz/Models/phalanx.xml
#  87 0101 0111 - Nimitz/Models/sea-sparrow.ac
#  88 0101 1000 - Nimitz/Models/sea-sparrow.xml
#  89 0101 1001 - RP-3/RP-3.ac
#  90 0101 1010 - RP-3/crater.ac
#  91 0101 1011 - container_carrier.ac
#  92 0101 1100 - droptank_300_gal.ac
#  93 0101 1101 - flare.ac
#  94 0101 1110 - load.ac
#  95 0101 1111 - mk82.ac
#--------
# Type 0110 : Models/Geometry items
#  96 0110 0000 - puff.ac
#  97 0110 0001 - rocket.ac
#  98 0110 0010 - tracer.ac
#  99 0110 0011 - tracer2.ac
# 100 0110 0100 -
# 101 0110 0101 -
# 102 0110 0110 -
# 103 0110 0111 -
# 104 0110 1000 -
# 105 0110 1001 -
# 106 0110 1010 -
# 107 0110 1011 -
# 108 0110 1100 -
# 109 0110 1101 -
# 110 0110 1110 -
# 111 0110 1111 -
#--------
# Type 0111 : Models/Geometry items
# 112 0111 0000 -
# 113 0111 0001 -
# 114 0111 0010 -
# 115 0111 0011 -
# 116 0111 0100 -
# 117 0111 0101 -
# 118 0111 0110 -
# 119 0111 0111 -
# 120 0111 1000 -
# 121 0111 1001 -
# 122 0111 1010 -
# 123 0111 1011 -
# 124 0111 1100 -
# 125 0111 1101 -
# 126 0111 1110 -
# 127 0111 1111 -
#--------
# Type 1000 : Models/Geometry items
# 128 1000 0000 -
# 129 1000 0001 -
# 130 1000 0010 -
# 131 1000 0011 -
# 132 1000 0100 -
# 133 1000 0101 -
# 134 1000 0110 -
# 135 1000 0111 -
# 136 1000 1000 -
# 137 1000 1001 -
# 138 1000 1010 -
# 139 1000 1011 -
# 140 1000 1100 -
# 141 1000 1101 -
# 142 1000 1110 -
# 143 1000 1111 -
#--------
# Type 1001 :
# 144 1001 0000 -
# 145 1001 0001 -
# 146 1001 0010 -
# 147 1001 0011 -
# 148 1001 0100 -
# 149 1001 0101 -
# 150 1001 0110 -
# 151 1001 0111 -
# 152 1001 1000 -
# 153 1001 1001 -
# 154 1001 1010 -
# 155 1001 1011 -
# 156 1001 1100 -
# 157 1001 1101 -
# 158 1001 1110 -
# 159 1001 1111 -
#--------
# Type 1010 :
# 160 1010 0000 -
# 161 1010 0001 -
# 162 1010 0010 -
# 163 1010 0011 -
# 164 1010 0100 -
# 165 1010 0101 -
# 166 1010 0110 -
# 167 1010 0111 -
# 168 1010 1000 -
# 169 1010 1001 -
# 170 1010 1010 -
# 171 1010 1011 -
# 172 1010 1100 -
# 173 1010 1101 -
# 174 1010 1110 -
# 175 1010 1111 -
#--------
# Type 1011 :
# 176 1011 0000 -
# 177 1011 0001 -
# 178 1011 0010 -
# 179 1011 0011 -
# 180 1011 0100 -
# 181 1011 0101 -
# 182 1011 0110 -
# 183 1011 0111 -
# 184 1011 1000 -
# 185 1011 1001 -
# 186 1011 1010 -
# 187 1011 1011 -
# 188 1011 1100 -
# 189 1011 1101 -
# 190 1011 1110 -
# 191 1011 1111 -
#--------
# Type 1100 :
# 192 1100 0000 -
# 193 1100 0001 -
# 194 1100 0010 -
# 195 1100 0011 -
# 196 1100 0100 -
# 197 1100 0101 -
# 198 1100 0110 -
# 199 1100 0111 -
# 200 1100 1000 -
# 201 1100 1001 -
# 202 1100 1010 -
# 203 1100 1011 -
# 204 1100 1100 -
# 205 1100 1101 -
# 206 1100 1110 -
# 207 1100 1111 -
#--------
# Type 1101 :
# 208 1101 0000 -
# 209 1101 0001 -
# 210 1101 0010 -
# 211 1101 0011 -
# 212 1101 0100 -
# 213 1101 0101 -
# 214 1101 0110 -
# 215 1101 0111 -
# 216 1101 1000 -
# 217 1101 1001 -
# 218 1101 1010 -
# 219 1101 1011 -
# 220 1101 1100 -
# 221 1101 1101 -
# 222 1101 1110 -
# 223 1101 1111 -
#--------
# Type 1110 :
# 224 1110 0000 -
# 225 1110 0001 -
# 226 1110 0010 -
# 227 1110 0011 -
# 228 1110 0100 -
# 229 1110 0101 -
# 230 1110 0110 -
# 231 1110 0111 -
# 232 1110 1000 -
# 233 1110 1001 -
# 234 1110 1010 -
# 235 1110 1011 -
# 236 1110 1100 -
# 237 1110 1101 -
# 238 1110 1110 -
# 239 1110 1111 -
#--------
# Type 1111 :
# 240 1111 0000 -
# 241 1111 0001 -
# 242 1111 0010 -
# 243 1111 0011 -
# 244 1111 0100 -
# 245 1111 0101 -
# 246 1111 0110 -
# 247 1111 0111 -
# 248 1111 1000 -
# 249 1111 1001 -
# 250 1111 1010 -
# 251 1111 1011 -
# 252 1111 1100 -
# 253 1111 1101 -
# 254 1111 1110 -
# 255 1111 1111 -


#
#
# Use to transmit events that happen at a specific place; can be used to make
# models that are simulated locally (e.g. tankers) appear on other player's MP sessions.
var PFDEventNotification =
{
# new:
# _ident - the identifier for the notification. not bridged.
# _pfd_id - numeric identification of the PFD within the model
# _event_id - event ID.
#     1       softkey pushed.
#     2       select page by ID
#     3       Change softkey button text
#     4       hardkey pushed - i.e. non-soft keys that don't change function based on context.
#     5       Engine data - e.g. RPM, EGTs, CHTs for display purposes
#     6       NavCom data - e.g. frequencies, volume, TX, RX for each of the COM and NAV radios.
# _event_param - param related to the event ID. implementation specific.
##
    SoftKeyPushed : 1,
    SelectPageById : 2,
    ChangeMenuText : 3, #event parameter contains array of { Id: , Text: } tuples
    HardKeyPushed : 4,  #event parameter contains single { Id: , Value: } tuple
    EngineData : 5,     #event parameter contains an array of hashes, each containing information about a given engine.
    NavComData : 6,     #event parameter contains a hash of updated Nav/Com settings
    NavData : 7,        #event parameter contrains a single { Id: , Value: } tuple requesting a particular type of NavData
    FMSData : 8,        #event parameter containing a hash of updated GPS/FMS information (track, ground-speed, waypoint legs etc.)
    ADCData : 8,        #event parameter containing a hash of updated Air Data Computer information (track, ground-speed etc.)

    DefaultType : "PFDEventNotification",

    new: func(_ident, _device_id,_event_id,_event_parameter_id)
    {
        var new_class = emesary.Notification.new(PFDEventNotification.DefaultType, _ident, PFDEventNotification_Id);
        new_class.Device_Id = _device_id;
        new_class.Event_Id = _event_id;
        new_class.EventParameter = _event_parameter_id;

        new_class.IsDistinct = 1; # each of these events is unique and needs to be bridged

        new_class.bridgeProperties = func
        {
            return
            [
             {
            getValue:func{return emesary.TransferByte.encode(new_class.Event_Id);},
            setValue:func(v,root,pos){var dv=emesary.TransferByte.decode(v,pos);new_class.Event_Id=dv.value;return dv},
             },
             {
            getValue:func{return emesary.TransferByte.encode(new_class.EventParameter);},
            setValue:func(v,root,pos){var dv=emesary.TransferByte.decode(v,pos);new_class.EventParameter=dv.value;return dv},
             },
            ];
          };
        return new_class;
    },
};
