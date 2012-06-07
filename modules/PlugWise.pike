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



array find_sensors(int|void manual)
{
  array ret=({});
  foreach(PlugWise->Plugs; string mac; object plug)
  {
     ret += ({ ([ "sensor":mac,"module":name,"parameters":sensvar ]) });
  }
  return ret;
}

class sensor
{
   inherit Sensor; 

   int sensor_type = SENSOR_INPUT | SENSOR_OUTPUT;
   mapping sensor_var = ([
                           "module":"",
                           "name": "",
                           "sensor_type": sensor_type,
                           "state": 0,
                           "online": 0,
                           "value": 0.0,
                        ]);

   void create( string name, object _module, object _configuration)
   {
      sensor_var->module = _module->name;
      module = _module;
      configuration = _configuration;
      sensor_name = name;
      sensor_var->name = name;
      if( has_index( configuration, "log" ) && (int) configuration->log == 1 )
         call_out(log,30);
   }

   mapping write( mapping what )
   {
      //FIXME Check if the plug exists in the network
      object plug = module->PlugWise->Plugs[configuration->sensor];
      if( !plug )
      {
         return ([]);
      }
      //FIXME The plug should handle this!
      plug->info();
      if (has_index(what,"state") )
      {
         if ( (int) what->state )
         {
            if ( !plug->powerstate )
               plug->on();
         }
         else
         {
            if ( plug->powerstate )
               plug->off();
         }
         sensor_var->state = plug->powerstate;
         return ([ "state": sensor_var->state]);
      }
   }

   protected void getnew( )
   {
#ifdef PLUGWISEDEBUG
   logdebug("Retrieving new values for plug %s\n",sensor_var->name);
#endif
         object plug = module->PlugWise->Plugs[configuration->sensor]; 
         plug->info();
         sensor_var->state = plug->powerstate;
         sensor_var->value = (float) plug->power();
         sensor_var->online = plug->online;
   }

   void log_callback( array data, int logaddress )
   {
      logdebug("Log Data arrived for plug %s\n",sensor_var->name);
      int sum=0;
      foreach( data, mapping log_item )
      {
         //FIXME Correct plug time here?
         if( log_item->hour - time(1) > 60 )
            logerror("Loghour %d is larger then current timestamp %d\n",log_item->hour, time(1)); 
         logdata(sensor_var->name+".power",log_item->kwh,log_item->hour);
      }
      object plug = module->PlugWise->Plugs[configuration->sensor];
      configuration->nextaddress=logaddress+1;
      //Check for roundtrip
      if( logaddress > plug->powerlogpointer )
         configuration->nextaddress=logaddress+1;
      //Get next log if we lag behind  
      if( logaddress+1 < plug->powerlogpointer )
         plug->powerlog(logaddress+1);
   }


   void log()
   {
      call_out(log,3600 );
      logdebug("Log for plug %s\n",sensor_var->name);
      object plug = module->PlugWise->Plugs[configuration->sensor]; 
      //FIXME Log error?
      if( ! plug )
      { 
         logdebug("Can't log unknown plug? %s\n",sensor_var->name);
         return;
      }
      if( ! plug->online)
      {
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
      logdebug("Request Log Data for plug %s\n",sensor_var->name);

      if( (int) configuration->nextaddress < plug->powerlogpointer )
      {
#ifdef PLUGWISEDEBUG
            logdebug("Retrieving address %d for plug %s with current address %d\n",(int) configuration->nextaddress,sensor_var->name,(int) plug->powerlogpointer);
#endif
         plug->powerlog( (int) configuration->nextaddress );
      }
      else if ( (int) configuration->nextaddress > plug->powerlogpointer )
      {
         //Round trip. Log the last higher log
         plug->powerlog( (int) configuration->nextaddress );
      }
  }

}

void reload()
{
   remove_call_out(log);
   sensors = ([]);
//   PlugWise->close();
   init(); 
}

void close()
{
   remove_call_out(log);
   //Stdio.stdout("Closing PlugWise\n");
   sensors = ([]);
//   PlugWise->close();
   configuration = 0;
}
