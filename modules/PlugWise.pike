#include <module.h>
inherit Module;


int module_type = MODULE_SENSOR;
object PlugWise;


constant defvar = ({
                   ({ "port",PARAM_STRING,"/dev/ttyUSB0","TTY Port of the USB Stick", POPT_RELOAD }),
                   ({ "debug",PARAM_BOOLEAN,0,"Turn On / Off Debugging (Requires Reload)", POPT_RELOAD }),
                   });

/* Sensor Specific Variables */
constant sensvar = ({
                   ({ "nextaddress",PARAM_INT,-1,"Current Log Pointer (-1 use plug headpointer)",0   }),
                   ({ "log",PARAM_BOOLEAN,0,"Turn On / Off Logging",0   }),
                });

void init() 
{
#ifdef DEBUG
   logdebug("Init Module %s\n",name);
#endif

     PlugWise = Public.IO.PlugWise(configuration->port,1);
     
     init_sensors( configuration->sensor+({}) );
}

void init_sensors( array load_sensors )
{
   foreach(load_sensors, string name )
   {
      sensors+= ([ name: sensor( name, this, domotica->configuration(name) ) ]);
   }
}



array find_sensors( )
{
  array ret=({});
  array var = sensvar;
  var+= ({ ({ "name",PARAM_STRING,"default","Name"}) });
  foreach(PlugWise->Plugs; string mac; object plug)
     ret += ({ ([ "sensor":mac,"module":name,"parameters":var ]) });
  return ret;
}

class sensor
{
   inherit Sensor; 

   int sensor_type = SENSOR_INPUT | SENSOR_OUTPUT;
   mapping sensor_var = ([
                           "state": 0,
                           "online": 0,
                           "power": 0.0,
                        ]);

   void create( string name, object _module, object _configuration)
   {
      module = _module;
      configuration = _configuration;
      sensor_name = name;
      sensor_prop->module = _module->name;
      sensor_prop->name = name;
      sensor_prop->sensor_type = sensor_type;
      if( has_index( configuration, "log" ) && (int) configuration->log == 1 )
         call_out(log,30);
   }

   object getplug( string mac )
   {
      if( has_index( module->PlugWise->Plugs, mac ))
         return module->PlugWise->Plugs[mac];
      else
      {
         logerror("Plug %s with mac %s Not Found, search started\n",sensor_prop->name,mac);
         if( module->PlugWise->CirclePlus )
            module->PlugWise->CirclePlus->find_plugs();
         return UNDEFINED;
      }
   }

   mapping write( mapping what, int|void retry )
   {
      object plug = getplug(configuration->sensor);
      if( !plug )
      {
         if( !retry )
         {
            logerror("Plug %s Not Found in the PlugWise Network retry in 30 seconds\n",configuration->sensor);
            call_out(write,30,what,1);
         }
         else
         {
            logerror("Plug %s Not Found in the PlugWise Network retry in 30 seconds\n",configuration->sensor);
         }
         return ([]);
      }
      if (has_index(what,"state") )
      {
         if ( (int) what->state )
               plug->on();
         else
               plug->off();
         sensor_var->state = plug->powerstate;
         return ([ "state": sensor_var->state]);
      }
   }

   protected void getnew( )
   {
#ifdef PLUGWISEDEBUG
   logdebug("Retrieving new values for plug %s\n",sensor_prop->name);
#endif
         object plug = getplug(configuration->sensor); 
         if(! plug ) 
            return;
         plug->info();
         sensor_var->state = plug->powerstate;
         sensor_var->power = (float) plug->power();
         sensor_var->online = plug->online;
   }

   void log_callback( array data, int logaddress )
   {
      object plug = module->PlugWise->Plugs[configuration->sensor];
#ifdef DEBUG
   logdebug("Plug %s logaddress %d\n",sensor_prop->name,logaddress);
#endif
      configuration->nextaddress=logaddress+1;
      //Check for roundtrip
      //Seems to be a bug
      if( logaddress > plug->powerlogpointer )
      {
           logerror("logaddress: %d > powerlogpoint %d\n",logaddress, plug->powerlogpointer);
           configuration->nextaddress=plug->powerlogpointer;
           return;
      }
      //Get next log if we lag behind  
      if( logaddress+1 < plug->powerlogpointer )
      {
         plug->powerlog(logaddress+1);
#ifdef PLUGWISEDEBUG
            logdebug("Retrieving address %d for plug %s with current address %d\n",(int) logaddress+1,sensor_prop->name,(int) plug->powerlogpointer);
#endif
      }
      //Now do the logging
      foreach( data, mapping log_item )
      {
         if( log_item->hour - time(1) > 60 )
            logerror("Loghour %d is larger then current timestamp %d\n",log_item->hour, time(1)); 
         logdata(sensor_prop->name+".Wh",log_item->kwh,log_item->hour);
      }
   }


   void log()
   {
      call_out(log,3600 );
      object plug = module->PlugWise->Plugs[configuration->sensor]; 
      if( ! plug )
      { 
         logerror("Plug %s Not Found in the PlugWise Network\n",configuration->sensor);
         return;
      }
      if( ! plug->online)
      {
         //Send a query to the plug, maybe it's online now.
         plug->info();
         return;
      }

      //If no nextaddress is know, initialize it with the log head.
      if( !has_index(configuration, "nextaddress" ) || 
                      (int) configuration->nextaddress== -1 )
      {
         configuration->nextaddress = (int) plug->powerlogpointer;
         return;
      }
      
      plug->set_powerlog_callback( log_callback );

      if( (int) configuration->nextaddress < plug->powerlogpointer )
      {
#ifdef PLUGWISEDEBUG
            logdebug("Retrieving address %d for plug %s with current address %d\n",(int) configuration->nextaddress,sensor_prop->name,(int) plug->powerlogpointer);
#endif
         plug->powerlog( (int) configuration->nextaddress );
      }
  }

}

void reload()
{
   remove_call_out(log);
   sensors = ([]);
   PlugWise->close();
   init(); 
}

void close()
{
   remove_call_out(log);
   //Stdio.stdout("Closing PlugWise\n");
   sensors = ([]);
   PlugWise->close();
   configuration = 0;
}
