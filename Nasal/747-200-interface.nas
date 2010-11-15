# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =====
# SEATS
# =====

Seats = {};

Seats.new = func {
   var obj = { parents : [Seats],

               controls : nil,
               positions : nil,
               theseats : nil,
               theview : nil,

               lookup : {},
               names : {},
               nb_seats : 0,

               CAPTINDEX : 0,

               floating : {},
               recoverfloating : constant.FALSE,
               last_recover : {},
               initial : {}
         };

   obj.init();

   return obj;
};

Seats.init = func {
   var child = nil;
   var name = "";

   me.controls = props.globals.getNode("/controls/seat");
   me.positions = props.globals.getNode("/systems/seat/position");
   me.theseats = props.globals.getNode("/systems/seat");
   me.theviews = props.globals.getNode("/sim").getChildren("view");

   # retrieve the index as created by FG
   for( var i = 0; i < size(me.theviews); i=i+1 ) {
        child = me.theviews[i].getChild("name");

        # nasal doesn't see yet the views of preferences.xml
        if( child != nil ) {
            name = child.getValue();
            if( name == "Copilot View" ) {
                me.save_lookup("copilot", i);
            }
            elsif( name == "Engineer View" ) {
                me.save_lookup("engineer", i);
            }
            elsif( name == "Observer View" ) {
                me.save_lookup("observer", i);
                me.save_initial( "observer", me.theviews[i] );
            }
            elsif( name == "Gear Well View" ) {
                me.save_lookup("gear-well", i);
                me.save_initial( "gear-well", me.theviews[i] );
            }
            elsif( name == "Cargo Aft View" ) {
                me.save_lookup("cargo-aft", i);
                me.save_initial( "cargo-aft", me.theviews[i] );
            }
            elsif( name == "Cargo Forward View" ) {
                me.save_lookup("cargo-forward", i);
                me.save_initial( "cargo-forward", me.theviews[i] );
            }
        }
   }

   # default
   me.recoverfloating = me.controls.getChild("recover").getValue();
}

Seats.recoverexport = func {
   me.recoverfloating = !me.recoverfloating;
   me.controls.getChild("recover").setValue(me.recoverfloating);
}

Seats.viewexport = func( name ) {
   var index = 0;

   if( name != "captain" ) {
       index = me.lookup[name];

       # swap to view
       if( !me.theseats.getChild(name).getValue() ) {
           setprop("/sim/current-view/view-number", index);
           me.theseats.getChild(name).setValue(constant.TRUE);
           me.theseats.getChild("captain").setValue(constant.FALSE);

           me.theviews[index].getChild("enabled").setValue(constant.TRUE);
       }

       # return to captain view
       else {
           setprop("/sim/current-view/view-number", 0);
           me.theseats.getChild(name).setValue(constant.FALSE);
           me.theseats.getChild("captain").setValue(constant.TRUE);

           me.theviews[index].getChild("enabled").setValue(constant.FALSE);
       }

       # disable all other views
       for( var i = 0; i < me.nb_seats; i=i+1 ) {
            if( name != me.names[i] ) {
                me.theseats.getChild(me.names[i]).setValue(constant.FALSE);

                index = me.lookup[me.names[i]];
                me.theviews[index].getChild("enabled").setValue(constant.FALSE);
            }
       }

       me.recover();
   }

   # captain view
   else {
       setprop("/sim/current-view/view-number",0);
       me.theseats.getChild("captain").setValue(constant.TRUE);

       # disable all other views
       for( var i = 0; i < me.nb_seats; i=i+1 ) {
            me.theseats.getChild(me.names[i]).setValue(constant.FALSE);

            index = me.lookup[me.names[i]];
            me.theviews[index].getChild("enabled").setValue(constant.FALSE);
       }
   }
}

Seats.scrollexport = func{
   me.stepView(1);
}

Seats.scrollreverseexport = func{
   me.stepView(-1);
}

Seats.stepView = func( step ) {
   var targetview = 0;
   var name = "";

   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            targetview = me.lookup[name];
            break;
        }
   }

   # ignores captain view
   if( targetview > me.CAPTINDEX ) {
       me.theviews[me.CAPTINDEX].getChild("enabled").setValue(constant.FALSE);
   }

   view.stepView(step);

   # restores because of userarchive
   if( targetview > me.CAPTINDEX ) {
       me.theviews[me.CAPTINDEX].getChild("enabled").setValue(constant.TRUE);
   }
}

# forwards is positiv
Seats.movelengthexport = func( step ) {
   var headdeg = 0.0;
   var prop = "";
   var sign = 0;
   var pos = 0.0;
   var result = constant.FALSE;

   if( me.move() ) {
       headdeg = getprop("/sim/current-view/goal-heading-offset-deg");

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "/sim/current-view/z-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "/sim/current-view/z-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "/sim/current-view/x-offset-m";
           sign = -1;
       }
       else {
           prop = "/sim/current-view/x-offset-m";
           sign = 1;
       }

       pos = getprop(prop);
       pos = pos + sign * step;
       setprop(prop,pos);

       result = constant.TRUE;
   }

   return result;
}

# left is negativ
Seats.movewidthexport = func( step ) {
   var headdeg = 0.0;
   var prop = "";
   var sign = 0;
   var pos = 0.0;
   var result = constant.FALSE;

   if( me.move() ) {
       headdeg = getprop("/sim/current-view/goal-heading-offset-deg");

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "/sim/current-view/x-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "/sim/current-view/x-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "/sim/current-view/z-offset-m";
           sign = 1;
       }
       else {
           prop = "/sim/current-view/z-offset-m";
           sign = -1;
       }

       pos = getprop(prop);
       pos = pos + sign * step;
       setprop(prop,pos);

       result = constant.TRUE;
   }

   return result;
}

# up is positiv
Seats.moveheightexport = func( step ) {
   var pos = 0.0;
   var result = constant.FALSE;

   if( me.move() ) {
       pos = getprop("/sim/current-view/y-offset-m");
       pos = pos + step;
       setprop("/sim/current-view/y-offset-m",pos);

       result = constant.TRUE;
   }

   return result;
}

Seats.save_lookup = func( name, index ) {
   me.names[me.nb_seats] = name;

   me.lookup[name] = index;

   me.floating[name] = constant.FALSE;

   me.nb_seats = me.nb_seats + 1;
}

# backup initial position
Seats.save_initial = func( name, view ) {
   var pos = {};
   var config = view.getNode("config");

   pos["x"] = config.getChild("x-offset-m").getValue();
   pos["y"] = config.getChild("y-offset-m").getValue();
   pos["z"] = config.getChild("z-offset-m").getValue();

   me.initial[name] = pos;

   me.floating[name] = constant.TRUE;
   me.last_recover[name] = constant.FALSE;
}

Seats.initial_position = func( name ) {
   var position = me.positions.getNode(name);

   var posx = me.initial[name]["x"];
   var posy = me.initial[name]["y"];
   var posz = me.initial[name]["z"];

   setprop("/sim/current-view/x-offset-m",posx);
   setprop("/sim/current-view/y-offset-m",posy);
   setprop("/sim/current-view/z-offset-m",posz);

   position.getChild("x-m").setValue(posx);
   position.getChild("y-m").setValue(posy);
   position.getChild("z-m").setValue(posz);
}

Seats.last_position = func( name ) {
   var position = nil;
   var posx = 0.0;
   var posy = 0.0;
   var posz = 0.0;

   # 1st restore
   if( !me.last_recover[ name ] and me.recoverfloating ) {
       position = me.positions.getNode(name);

       posx = position.getChild("x-m").getValue();
       posy = position.getChild("y-m").getValue();
       posz = position.getChild("z-m").getValue();

       if( posx != me.initial[name]["x"] or
           posy != me.initial[name]["y"] or
           posz != me.initial[name]["z"] ) {

           setprop("/sim/current-view/x-offset-m",posx);
           setprop("/sim/current-view/y-offset-m",posy);
           setprop("/sim/current-view/z-offset-m",posz);
       }

       me.last_recover[ name ] = constant.TRUE;
   }
}

Seats.recover = func {
   var name = "";

   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.last_position( name );
            }
            break;
        }
   }
}

Seats.move_position = func( name ) {
   var posx = getprop("/sim/current-view/x-offset-m");
   var posy = getprop("/sim/current-view/y-offset-m");
   var posz = getprop("/sim/current-view/z-offset-m");

   var position = me.positions.getNode(name);

   position.getChild("x-m").setValue(posx);
   position.getChild("y-m").setValue(posy);
   position.getChild("z-m").setValue(posz);
}

Seats.move = func {
   var name = "";
   var result = constant.FALSE;

   # saves previous position
   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.move_position( name );
                result = constant.TRUE;
            }
            break;
        }
   }

   return result;
}

# restore view
Seats.restoreexport = func {
   var name = "";

   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.initial_position( name );
            }
            break;
        }
   }
}

# restore view pitch
Seats.restorepitchexport = func {
   var index = getprop("/sim/current-view/view-number");

   if( index == me.CAPTINDEX ) {
       var headingdeg = me.theviews[index].getNode("config").getChild("heading-offset-deg").getValue();
       var pitchdeg = me.theviews[index].getNode("config").getChild("pitch-offset-deg").getValue();

       setprop("/sim/current-view/heading-offset-deg", headingdeg );
       setprop("/sim/current-view/pitch-offset-deg", pitchdeg );
   }

   # only cockpit views
   else {
       var name = "";

       for( var i = 0; i < me.nb_seats; i=i+1 ) {
            name = me.names[i];
            if( me.theseats.getChild(name).getValue() ) {
                var headingdeg = me.theviews[index].getNode("config").getChild("heading-offset-deg").getValue();
                var pitchdeg = me.theviews[index].getNode("config").getChild("pitch-offset-deg").getValue();

                setprop("/sim/current-view/heading-offset-deg", headingdeg );
                setprop("/sim/current-view/pitch-offset-deg", pitchdeg );
                break;
            }
        }
   }
}


# ====
# MENU
# ====

Menu = {};

Menu.new = func {
   var obj = { parents : [Menu],

               autopilot : nil,
               crew : nil,
               fuel : nil,
               ground : nil,
               navigation : nil,
               radios : nil,
               menu : nil
         };

   obj.init();

   return obj;
};

Menu.init = func {
   # B747-200, because property system refuses 747-200
   me.menu = gui.Dialog.new("/sim/gui/dialogs/B747-200/menu/dialog",
                            "Aircraft/747-200/Dialogs/747-200-menu.xml");
   me.autopilot = gui.Dialog.new("/sim/gui/dialogs/B747-200/autopilot/dialog",
                                 "Aircraft/747-200/Dialogs/747-200-autopilot.xml");
   me.crew = gui.Dialog.new("/sim/gui/dialogs/B747-200/crew/dialog",
                            "Aircraft/747-200/Dialogs/747-200-crew.xml");
   me.fuel = gui.Dialog.new("/sim/gui/dialogs/B747-200/fuel/dialog",
                            "Aircraft/747-200/Dialogs/747-200-fuel.xml");
   me.ground = gui.Dialog.new("/sim/gui/dialogs/B747-200/ground/dialog",
                              "Aircraft/747-200/Dialogs/747-200-ground.xml");
   me.navigation = gui.Dialog.new("/sim/gui/dialogs/B747-200/navigation/dialog",
                                  "Aircraft/747-200/Dialogs/747-200-navigation.xml");
   me.radios = gui.Dialog.new("/sim/gui/dialogs/B747-200/radios/dialog",
                            "Aircraft/747-200/Dialogs/747-200-radios.xml");
}
