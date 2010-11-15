# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains checklist tasks.


# ================
# VIRTUAL ENGINEER
# ================

Virtualengineer = {};

Virtualengineer.new = func {
   var obj = { parents : [Virtualengineer], 

               navigation : Navigation.new()
         };

    obj.init();

    return obj;
}

Virtualengineer.init = func {
}

Virtualengineer.veryslowschedule = func {
    me.navigation.schedule();
}


# ==========
# NAVIGATION
# ==========

Navigation = {};

Navigation.new = func {
   var obj = { parents : [Navigation,System], 

              altitudeft : 0.0,

              last : constant.FALSE,

              NOSPEEDFPM : 0.0,

              SUBSONICKT : 480,                                 # estimated ground speed
              FLIGHTKT : 150,                                   # minimum ground speed

              groundkt : 0,

              SUBSONICKGPH : 20000,                             # subsonic consumption

              galusph : 0,

              NOFUELGALUS : -999,

              totalgalus : 0
         };

   obj.init();

   return obj;
}

Navigation.init = func {
   me.inherit_system("/systems/engineer");
}

Navigation.schedule = func {
   var groundfps = me.dependency["ins"].getChild("ground-speed-fps").getValue();
   var id = "";
   var distnm = 0.0;
   var targetft = 0;
   var selectft = 0.0;
   var fuelgalus = 0.0;
   var speedfpm = 0.0;

   if( groundfps != nil ) {
       me.groundkt = groundfps * constant.FPSTOKT;
   }

   me.totalgalus = me.dependency["fuel"].getChild("total-gal_us").getValue();

   # on ground
   if( me.groundkt < me.FLIGHTKT ) {
       me.groundkt = me.SUBSONICKT;
       me.galusph = me.SUBSONICKGPH;
   }
   else {
       # gauge is NOT REAL
       me.galusph = me.dependency["fuel"].getNode("fuel-flow-gal_us_ph").getValue();
   }

   me.altitudeft = me.noinstrument["altitude"].getValue();
   selectft = me.dependency["autoflight"].getChild("dial-altitude-ft").getValue();
   me.last = constant.FALSE;


   # waypoint
   for( var i = 2; i >= 0; i = i-1 ) {
        if( i < 2 ) {
            id = me.dependency["waypoint"][i].getChild("id").getValue();
            distnm = me.dependency["waypoint"][i].getChild("dist").getValue();
            targetft = selectft;
        }

        # last
        else {
            id = getprop("/autopilot/route-manager/wp-last/id"); 
            distnm = getprop("/autopilot/route-manager/wp-last/dist"); 
        }

        fuelgalus = me.estimatefuelgalus( id, distnm );
        speedfpm = me.estimatespeedfpm( id, distnm, targetft );

        # display for FDM debug, or navigation
        me.itself["waypoint"][i].getChild("fuel-gal_us").setValue(fuelgalus);
        me.itself["waypoint"][i].getChild("speed-fpm").setValue(speedfpm);
   }
}

Navigation.estimatespeedfpm = func( id, distnm, targetft ) {
   var speedfpm = me.NOSPEEDFPM;
   var minutes = 0.0;

   if( id != "" and distnm != nil ) {
       # last waypoint at sea level
       if( !me.last ) {
           targetft = me.itself["root-ctrl"].getChild("destination-ft").getValue();
           me.last = constant.TRUE;
       }

       minutes = ( distnm / me.groundkt ) * constant.HOURTOMINUTE;
       speedfpm = ( targetft - me.altitudeft ) / minutes;
   }

   return speedfpm;
}

Navigation.estimatefuelgalus = func( id, distnm ) {
   var fuelgalus = me.NOFUELGALUS;
   var ratio = 0.0;

   if( id != "" and distnm != nil ) {
       ratio = distnm / me.groundkt;
       fuelgalus = me.galusph * ratio;
       fuelgalus = me.totalgalus - fuelgalus;
       if( fuelgalus < 0 ) {
           fuelgalus = 0;
       }
   }

   return fuelgalus;
}
