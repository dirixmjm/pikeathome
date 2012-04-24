#include <module.h>
inherit Module;


int module_type = MODULE_SENSOR;
object circle_plus;


constant defvar = ({
                   ({ "port",PARAM_STRING,"/dev/ttyUSB0","TTY Port of the USB Stick", POPT_RELOAD }),
                   ({ "circleplus",PARAM_STRING,"","The Mac Address of the Circle Plus", POPT_RELOAD }),
                   ({ "debug",PARAM_BOOLEAN,0,"Turn On / Off Debugging (Requires Reload)", POPT_RELOAD }),
                   });

/* Sensor Specific Variables */
constant sensvar = ({
                   ({ "lastaddress",PARAM_INT,-1,"Current Log Pointer (-1 use plug headpointer)",0   }),
                   ({ "log",PARAM_BOOLEAN,0,"Turn On / Off Logging",0   }),
                });

void init() 
{
#ifdef DEBUG
   logdebug("Init Module %s\n",name);
#endif

     mixed err = catch { circle_plus = Public.IO.PlugWise.Plug(configuration->port,configuration->circleplus);
     };
     init_sensors( configuration->sensor+({}) );
}

void init_sensors( array load_sensors )
{
   foreach(load_sensors, string name )
   {
      sensors+= ([ name: sensor( name, circle_plus->proto, this, domotica->configuration(name) ) ]);
   }
}


/* We need to do some sort of odd caching here otherwise the server 
   will hang to long */
array plugs = ({});

array find_sensors(int|void manual)
{
  array ret=({});
  call_out(_find_plugs,1);
  foreach(plugs, string plug)
  {
     ret += ({ ([ "sensor":plug,"module":name,"parameters":sensvar ]) });
  }
  return ret;
}

protected void _find_plugs()
{
   plugs = circle_plus->find_plugs();
   plugs += ({ configuration->circleplus });
}

class sensor
{
   inherit Sensor; 

   int sensor_type = SENSOR_INPUT | SENSOR_OUTPUT;   
   Public.IO.PlugWise.Plug plug;
 
   mapping sensor_var = ([
                           "module":"",
                           "name": "",
                           "sensor_type": sensor_type,
                           "state": 0,
                           "online": 0,
                           "value": 0.0,
                        ]);

   void create( string name, object plugport, object _module, object _configuration)
   {
      sensor_var->module = _module->name;
      module = _module;
      configuration = _configuration;
      sensor_name = name;
      sensor_var->name = name;
      plug = Public.IO.PlugWise.Plug(plugport,configuration->sensor);
      if( has_index( configuration, "log" ) && (int) configuration->log == 1 )
         call_out(log,0);
   }

   mapping write( mapping what )
   {
      if (has_index(what,"state") )
      {
         plug->info();
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
         plug->info();
         sensor_var->state = plug->powerstate;
         sensor_var->value = (float) plug->power(1);
         sensor_var->online = plug->online;
   }

   void log()
   {
      call_out(log,3600 );
      plug->info();
      if( ! plug->online)
         return;
      if( !has_index(configuration, "lastaddress" ) || 
                      (int) configuration->lastaddress== -1 )
         configuration->lastaddress = (int) plug->logaddress;
      if( plug->logaddress < (int) configuration->lastaddress && (int) configuration->lastaddress > 1 )
         configuration->lastaddress = 0; 
      int nextaddress = (int) configuration->lastaddress+1;
      if( nextaddress < plug->logaddress )
      {
#ifdef PLUGWISEDEBUG
            logdebug("Retrieving address %d for plug %s with current address %d\n",nextaddress,sensor_var->name,(int) plug->logaddress);
#endif
         array logs = ({});
         catch {
            logs = plug->power_log(nextaddress);
         };
         if( sizeof(logs) < 4  )
         {
#ifdef PLUGWISEDEBUG
            logerror("Emtpy Log %s %O\n",configuration->name,logs);
#endif
            return;
         }
         int sum=0;
         foreach( logs, mapping log_item )
         {
            //1 Minute Time shift occured
            //FIXME Correct plug time here?
            if( log_item->hour - time(1) > 60 )
               logerror("Loghour %d is larger then current timestamp %d\n",log_item->hour, time(1)); 
            logdata(sensor_var->name+".power",log_item->kwh,log_item->hour);
         }
         configuration->lastaddress=nextaddress;
      }
      //If there are multiple logs ready retrieve one every minute.
      if( ++nextaddress < plug->logaddress )
      {
#ifdef PLUGWISEDEBUG
         logdebug("Multiple logs, running 60 second timer\n" ); 
#endif
         call_out(log, 60 );
      }
   }

}

void reload()
{
   remove_call_out(log);
   sensors = ([]);
   if( circle_plus )
      circle_plus->close();
   init(); 
}

void close()
{
   remove_call_out(log);
   //Stdio.stdout("Closing PlugWise\n");
   sensors = ([]);
   circle_plus->close();
   configuration = 0;
}
