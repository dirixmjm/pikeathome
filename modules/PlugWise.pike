#include <module.h>
#include <sensor.h>
#include <variable.h>
inherit Module;
inherit Base_func;


int module_type = MODULE_SENSOR;
object PlugWise;


constant ModuleParameters = ({
                   ({ "port",PARAM_STRING,"/dev/ttyUSB0","TTY Port of the USB Stick", POPT_RELOAD }),
                   ({ "plugfind",PARAM_BOOLEAN,0,"Turn On / Off Plug Finder for 5 Minutes",POPT_NONE }),
                   ({ "debug",PARAM_BOOLEAN,0,"Turn On / Off Debugging",POPT_NONE }),
                   });

/* Sensor Specific Variables */
constant SensorBaseParameters = ({
                   ({ "type",PARAM_INT,-1,"Plug Type",0   }),
                   ({ "mac",PARAM_STRING,-1,"Plug Hardware Address",0   }),
                   ({ "nextaddress",PARAM_INT,-1,"Current Log Pointer (-1 use plug headpointer)",0   }),
                   ({ "log",PARAM_BOOLEAN,0,"Turn On / Off Logging",0   }),
                });

void init() 
{
   logdebug("Init Module %s\n",ModuleProperties->name);
   PlugWise = Public.IO.PlugWise(configuration->port);
   init_sensors( configuration->sensor+({}) );
}

void init_sensors( array load_sensors )
{
   foreach(load_sensors, string name )
   {
      sensors+= ([ name: sensor( name, this, configuration->Configuration(name) ) ]);
   }
}



array find_sensors( )
{
  array ret=({});
  //array var = SensorBaseParameters;
  foreach(indices(PlugWise), string mac)
  {
     array var = ({ });
     foreach ( SensorBaseParameters, array Parameter )
     {
        if ( Parameter[0] == "mac" )
           var+= ({ Parameter+({ mac }) });
        else if ( Parameter[0] == "type" )
           var+= ({ Parameter+({ PlugWise[mac]->type })});
        else
           var+= ({Parameter});
           
     }  
     ret += ({ ([ "name":mac,"module":ModuleProperties->name,"parameters":var ]) });
  }
  return ret;
}

void SetParameters( mapping params )
{
   int mod_options = 0;
   foreach(ModuleParameters, array option)
   {
      //Find the parameter, and always set it
      if( has_index( params, option[0] ) )
      {
         if( option[0] == "plugfind" )
         {
            PlugWise->CirclePlus->FindNewPlugs( 300 );
         }
         else
         {
            configuration[option[0]]=params[option[0]];
            mod_options |= option[4];
         }
      }
   }
   if( mod_options & POPT_RELOAD )
      ModuleReload();
}


class sensor
{
   inherit Sensor; 

   int sensor_type = SENSOR_INPUT | SENSOR_OUTPUT;

   void sensor_init()
   {
      //Logging only for Circle+, Circle and (Sense)
      switch( (int) configuration->type )
      {
         case 0:
         case 1:
         {
            ValueCache->state= ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
            ValueCache->power= ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            if( has_index( configuration, "log" ) && (int) configuration->log == 1)
               call_out(log,30);
         }
         break;
         case 3:
         {
           SensorParameters += ({ 
                  ({ "switch1_output",PARAM_SENSOROUTPUT,"","Output Switch 1",0 }),
                  ({ "switch2_output",PARAM_SENSOROUTPUT,"","Output Switch 2",0 }),
                              });

           call_out(set_switch_callback,0);
           SensorProperties->sensor_type |= SENSOR_FUNCTION;
           ValueCache->switch1= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
           ValueCache->switch2= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
         }
         break;
         case 4:
         {
            call_out(set_switch_callback,0);
            SensorProperties->sensor_type |= SENSOR_FUNCTION;
            ValueCache->switch1= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
         }
         break;
         case 5:
         {
            call_out(set_switch_callback,0);
            SensorProperties->sensor_type |= SENSOR_FUNCTION;
            ValueCache->switch1= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
            ValueCache->humidity= ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->temperature= ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
         }
         break;
      }
      //Initialise Variables
      ValueCache->online= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
      ValueCache->logpointer= ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
   }

   object getplug( string mac )
   {
      object Plug = module->PlugWise[mac];
      if( ! Plug )
      {
         logerror("Plug %s with mac %s Not Found, search started\n",SensorProperties->name,mac);
         return UNDEFINED;
      } 
     return Plug;
   }

   mapping write( mapping what, int|void retry )
   {
      object plug = getplug(configuration->mac);
      if( !plug )
      {
         if( !retry )
         {
            logerror("Plug %s Not Found in the PlugWise Network retry in 30 seconds\n",configuration->mac);
            call_out(write,30,what,1);
         }
         else
         {
            logerror("Plug %s Not Found in the PlugWise Network not retrying\n",configuration->mac);
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
         object plug = getplug(configuration->mac); 
         if(! plug ) 
            return;

         switch ( (int) configuration->type )
         {
            case 0:
            case 1:
            {
               plug->info();
               ValueCache->state = plug->powerstate;
               ValueCache->power = (float) plug->power();
            }
            break;
            case 5:
            {
               ValueCache->humidity = (float) plug->Humidity;
               ValueCache->temperature = (float) plug->Temperature;
            }
         }
         ValueCache->online = plug->online;
         ValueCache->logpointer = plug->log_pointer();
   }

   //Repeated callback, since at start we probably don't know or see the switch
   //Keep checking until we've found it.
   protected void set_switch_callback ( )
   {
      object plug = getplug( configuration->mac );
      if ( ! plug )
      {
         call_out(set_switch_callback,10);
         return;
      }
      plug->set_switch_callback( switch_callback );
   }

   protected void switch_callback ( int switchnr, int onoff )
   {
      if ( has_index( configuration, sprintf("switch%d_output",switchnr ) ))
         switchboard( SensorProperties->name,configuration[sprintf("switch%d_output",switchnr)],COM_WRITE,([ "value":onoff ] ) );
   }

   protected void log_callback( array data, int logaddress )
   {
      object plug = getplug(configuration->mac);
      logdebug("Plug %s logaddress %d\n",SensorProperties->name,logaddress);
      //Check for undetected roundtrip
      int logpointer = plug->log_pointer();
      if( logaddress >= logpointer )
      {
           logerror("logaddress: %d => logpoint %d\n",logaddress, logpointer);
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
         call_out(plug->log,1,logaddress+1);
         logdebug("Retrieving address %d for plug %s with current address %d\n",(int) logaddress+1,SensorProperties->name,(int) logpointer);
      }
   }


   protected void log()
   {
      if( (int) configuration->type == 3 || (int) configuration->type == 6 )
         return;

      call_out(log,3600 );
      logdebug("Checking Log for Plug %s\n",SensorProperties->name);
      object plug = getplug(configuration->mac);
      if( ! plug )
         return;
      if( ! plug->online)
      {
         logdebug("Plug %s Not Online Sleeping\n",SensorProperties->name);
         //Send a query to the plug, maybe it's online now.
         plug->info();
         return;
      }
      plug->info();
      int logpointer = plug->log_pointer();

      //If no nextaddress is known, initialize it with the log head.
      if( !has_index(configuration, "nextaddress" ) || 
                      (int) configuration->nextaddress== -1 )
      {
         configuration->nextaddress = (int) logpointer;
         return;
      }
     
      //Check for roundtrip
      if ( (int) configuration->nextaddress > logpointer && logpointer > 6000 )
      {
         logdebug("Logpointer Roundtrip Starting from address 1\n");
         configuration->nextaddress = 1;
      }

      if( (int) configuration->nextaddress < logpointer )
      {
         logdebug("Retrieving address %d for plug %s with current address %d\n",(int) configuration->nextaddress,SensorProperties->name,logpointer);
         plug->set_log_callback( log_callback );
         plug->log( (int) configuration->nextaddress );
      }
  }

}

void ModuleReload()
{
   //remove_call_out(log);
   sensors = ([]);
   init(); 
}

void close()
{
   sensors = ([]);
   configuration = 0;
}
