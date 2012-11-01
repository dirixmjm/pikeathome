#include <module.h>
#include <sensor.h>
#include <variable.h>
inherit Module;


int module_type = MODULE_SENSOR;
object PlugWise;


constant ModuleParameters = ({
                   ({ "port",PARAM_STRING,"/dev/ttyUSB0","TTY Port of the USB Stick", POPT_RELOAD }),
                   ({ "debug",PARAM_BOOLEAN,0,"Turn On / Off Debugging" }),
                   });

/* Sensor Specific Variables */
constant SensorBaseParameters = ({
                   ({ "nextaddress",PARAM_INT,-1,"Current Log Pointer (-1 use plug headpointer)",0   }),
                   ({ "log",PARAM_BOOLEAN,0,"Turn On / Off Logging",0   }),
                });

void init() 
{
   logdebug("Init Module %s\n",ModuleProperties->name);
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
  array var = SensorBaseParameters;
  var+= ({ ({ "name",PARAM_STRING,"default","Name"}) });
  foreach(PlugWise->Plugs; string mac; object plug)
     ret += ({ ([ "sensor":mac,"module":ModuleProperties->name,"parameters":var ]) });
  return ret;
}

class sensor
{
   inherit Sensor; 

   int sensor_type = SENSOR_INPUT | SENSOR_OUTPUT;

   void create( string name, object _module, object _configuration)
   {
      module = _module;
      configuration = _configuration;
      SensorProperties->module = _module->ModuleProperties->name;
      SensorProperties->name = name;
      SensorProperties->sensor_type = sensor_type;
      if( has_index( configuration, "log" ) && (int) configuration->log == 1 )
         call_out(log,30);
      //Initialise Variables
      ValueCache->state= ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
      ValueCache->online= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
      ValueCache->power= ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
   }

   object getplug( string mac )
   {
      if( has_index( module->PlugWise->Plugs, mac ))
         return module->PlugWise->Plugs[mac];
      else
      {
         logerror("Plug %s with mac %s Not Found, search started\n",SensorProperties->name,mac);
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
         ValueCache->state = plug->powerstate;
         return ([ "state": ValueCache->state]);
      }
   }

   protected void UpdateSensor( )
   {
         object plug = getplug(configuration->sensor); 
         if(! plug ) 
            return;
         plug->info();
         ValueCache->state = plug->powerstate;
         ValueCache->power = (float) plug->power();
         ValueCache->online = plug->online;
   }

   protected void log_callback( array data, int logaddress )
   {
      object plug = module->PlugWise->Plugs[configuration->sensor];
      logdebug("Plug %s logaddress %d\n",SensorProperties->name,logaddress);
      //Check for roundtrip
      //Seems to be a bug
      int logpointer = plug->powerlogpointer();
      if( logaddress >= logpointer )
      {
           logerror("logaddress: %d => powerlogpoint %d\n",logaddress, logpointer);
           configuration->nextaddress=logpointer;
           return;
      }
      //Set the next address that needs te be queried
      configuration->nextaddress=logaddress+1;
      //Sort the array
      sort(data->hour,data);
      //Now do the logging
      int logcount = 0;
      foreach( data, mapping log_item )
      {
         if( log_item->hour - time(1) > 60 )
            logerror("Loghour %d is larger then current timestamp %d\n",log_item->hour, time(1)); 
         //Make sure logging occurs timesynchronised.
         call_out(logdata,0.1*logcount++,SensorProperties->name+".Wh",log_item->kwh,log_item->hour);
      }
      //Get next log if we lag behind  
      if( logaddress+1 < logpointer )
      {
         //Add a delay to make sure logging occurs chronologically
         call_out(plug->powerlog,1,logaddress+1);
         logdebug("Retrieving address %d for plug %s with current address %d\n",(int) logaddress+1,SensorProperties->name,(int) logpointer);
      }
   }


   protected void log()
   {
      call_out(log,3600 );
      logdebug("Checking Log for Plug %s\n",SensorProperties->name);
      object plug = module->PlugWise->Plugs[configuration->sensor]; 
      if( ! plug )
      { 
         logerror("Plug %s Not Found in the PlugWise Network\n",configuration->sensor);
         return;
      }
      if( ! plug->online)
      {
         logdebug("Plug %s Not Online Sleeping\n",SensorProperties->name);
         //Send a query to the plug, maybe it's online now.
         plug->info();
         return;
      }

      int logpointer = plug->powerlogpointer();

      //If no nextaddress is know, initialize it with the log head.
      if( !has_index(configuration, "nextaddress" ) || 
                      (int) configuration->nextaddress== -1 )
      {
         configuration->nextaddress = (int) logpointer;
         return;
      }
      

      if( (int) configuration->nextaddress < logpointer )
      {
         logdebug("Retrieving address %d for plug %s with current address %d\n",(int) configuration->nextaddress,SensorProperties->name,logpointer);
         plug->set_powerlog_callback( log_callback );
         plug->powerlog( (int) configuration->nextaddress );
      }
  }

}

void reload()
{
   //remove_call_out(log);
   sensors = ([]);
   PlugWise->close();
   init(); 
}

void close()
{
   //remove_call_out(log);
   //Stdio.stdout("Closing PlugWise\n");
   sensors = ([]);
   PlugWise->close();
   configuration = 0;
}
