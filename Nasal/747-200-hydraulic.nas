# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =====
# DOORS
# =====

Doors = {};

Doors.new = func {
   var obj = { parents : [Doors],

               cargodoors : nil,

               seat : SeatRail.new(),
 
               flightdeck : aircraft.door.new("controls/doors/crew/flightdeck", 8.0),
               exit : aircraft.door.new("controls/doors/crew/exit", 8.0),
               cargobulk : aircraft.door.new("controls/doors/cargo/bulk", 12.0),
               cargoaft : aircraft.door.new("controls/doors/cargo/aft", 12.0),
               cargoforward : aircraft.door.new("controls/doors/cargo/forward", 12.0)
         };

   obj.init();

   return obj;
};

Doors.init = func {
   me.cargodoors = props.globals.getNode("/controls/doors/cargo");
}

Doors.amber_cargo_doors = func {
   var result = constant.FALSE;

   if( me.cargodoors.getNode("forward").getChild("position-norm").getValue() > 0.0 or
       me.cargodoors.getNode("aft").getChild("position-norm").getValue() > 0.0 or
       me.cargodoors.getNode("bulk").getChild("position-norm").getValue() > 0.0 ) {
       result = constant.TRUE;
   }

   return result;
}

Doors.seatexport = func( seat ) {
   me.seat.toggle( seat );
}

Doors.flightdeckexport = func {
   me.flightdeck.toggle();
}

Doors.exitexport = func {
   me.exit.toggle();
}

Doors.cargobulkexport = func {
   me.cargobulk.toggle();
}

Doors.cargoaftexport = func {
   me.cargoaft.toggle();
}

Doors.cargoforwardexport = func {
   me.cargoforward.toggle();
}


# ===========
# GEAR SYSTEM
# ===========

Gear = {};

Gear.new = func {
   var obj = { parents : [Gear,System],

               FLIGHTSEC : 2.0,

               STEERINGKT : 40
         };

   obj.init();

   return obj;
};

Gear.init = func {
   me.inherit_system( "/systems/gear" );

   aircraft.steering.init("/controls/gear/brake-steering");
}

Gear.steeringexport = func {
   var result = 0.0;

   # taxi with steering wheel, rudder pedal at takeoff
   if( me.noinstrument["airspeed"].getValue() < me.STEERINGKT ) {

       # except forced by menu
       if( !me.dependency["steering"].getChild("pedal").getValue() ) {
           result = 1.0;
       }
   }

   me.dependency["steering"].getChild("wheel").setValue(result);
}

Gear.schedule = func {
   me.steeringexport();
}


# =======
# TRACTOR
# =======

Tractor = {};

Tractor.new = func {
   var obj = { parents : [Tractor,System],

               TRACTORSEC : 10.0,

               SPEEDFPS : 5.0,
               STOPFPS : 0.0,

               CONNECTED : 1.0,
               DISCONNECTED : 0.0,

               disconnecting : constant.FALSE,

               initial : nil
             };

# user customization
   obj.init();

   return obj;
};

Tractor.init = func {
   me.inherit_system( "/systems/tractor" );
}

Tractor.schedule = func {
   if( me.itself["root-ctrl"].getChild("pushback").getValue() ) {
       me.start();
   }

   me.move();
}

Tractor.move = func {
   if( me.itself["root"].getChild("pushback").getValue() and !me.disconnecting ) {
       var status = "";
       var latlon = geo.aircraft_position();
       var rollingmeter = latlon.distance_to( me.initial );

       status = sprintf(rollingmeter, "1f.0");

       # wait for tractor connect
       if( me.dependency["pushback"].getChild("position-norm").getValue() == me.CONNECTED ) {
           var ratefps = math.sgn( me.itself["root-ctrl"].getChild("distance-m").getValue() ) * me.SPEEDFPS;

           me.dependency["pushback"].getChild("target-speed-fps").setValue( ratefps );
       }

       if( rollingmeter >= math.abs( me.itself["root-ctrl"].getChild("distance-m").getValue() ) ) {
           # wait for tractor disconnect
           me.disconnecting = constant.TRUE;

           me.dependency["pushback"].getChild("target-speed-fps").setValue( me.STOPFPS );
           interpolate(me.dependency["pushback"].getChild("position-norm").getPath(), me.DISCONNECTED, me.TRACTORSEC);

           status = "";
       }

       me.itself["root"].getChild("distance-m").setValue( status );
   }

   # tractor disconnect
   elsif( me.disconnecting ) {
       if( me.dependency["pushback"].getChild("position-norm").getValue() == me.DISCONNECTED ) {
           me.disconnecting = constant.FALSE;

           me.dependency["pushback"].getChild("enabled").setValue( constant.FALSE );

           # interphone to copilot
           me.itself["root"].getChild("clear").setValue( constant.TRUE );
           me.itself["root"].getChild("pushback").setValue( constant.FALSE );
       }
   }
}

Tractor.start = func {
   # must wait for end of current movement
   if( !me.itself["root"].getChild("pushback").getValue() ) {
       me.disconnecting = constant.FALSE;

       me.initial = geo.aircraft_position();

       me.itself["root-ctrl"].getChild("pushback").setValue( constant.FALSE );
       me.itself["root"].getChild("pushback").setValue( constant.TRUE );
       me.itself["root"].getChild("clear").setValue( constant.FALSE );
       me.itself["root"].getChild("engine14").setValue( constant.FALSE );

       me.dependency["pushback"].getChild("enabled").setValue( constant.TRUE );
       interpolate(me.dependency["pushback"].getChild("position-norm").getPath(), me.CONNECTED, me.TRACTORSEC);
   }
}
