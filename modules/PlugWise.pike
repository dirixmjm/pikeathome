#include <module.h>
inherit Module;


int module_type = MODULE_SENSOR;
string module_name = "PlugWise";
object circle_plus;

array plugs = ({});

void module_init() 
{
     circle_plus = Public.IO.PlugWise.Plug(configuration->port,configuration->circleplus);
     foreach(configuration->sensor, string name )
     {
        sensors+= ([ name: sensor( name, circle_plus->proto, domotica ) ]);
     }
}

class sensor
{
   inherit Sensor; 

   int sensor_type = SENSOR_INPUT | SENSOR_OUTPUT;   
   Public.IO.PlugWise.Plug plug;
 
   mapping sensor_var = ([
                           "module":"PlugWise",
                           "name": "",
                           "sensor_type": sensor_type,
                           "state": 0,
                           "online": 0,
                           "value": 0.0,
                        ]);

   void create( string name, object plugport, object Domotica)
   {
      domotica = Domotica;
      configuration = domotica->configuration(name);
      sensor_name = name;
      sensor_var->name = name;
      plug = Public.IO.PlugWise.Plug(plugport,configuration->mac);
      if( has_index( configuration, "log" ) )
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
   domotica->log(LOG_EVENT,LOG_DEBUG,"Retrieving new values for plug %s\n",sensor_name);
#endif
         plug->info();
         sensor_var->state = plug->powerstate;
         sensor_var->value = (float) plug->power(1);
         sensor_var->online = plug->online;
   }

   void log()
   {
      plug->info();
      if( ! plug->online)
         return;
      if( !has_index(configuration, "lastaddress" ) )
         configuration->lastaddress = (int) plug->logaddress;
      if( plug->logaddress < (int) configuration->lastaddress && (int) configuration->lastaddress > 1 )
         configuration->lastaddress = 0; 
      int nextaddress = (int) configuration->lastaddress+1;
      if( nextaddress < plug->logaddress )
      {
#ifdef PLUGWISEDEBUG
            domotica->log(LOG_EVENT,LOG_DEBUG,"Retrieving address %d for plug %s with current address %d\n",nextaddress,sensor_name,(int) plug->logaddress);
#endif
         array logs = ({});
         catch {
            logs = plug->power_log(nextaddress);
         };
         if( sizeof(logs) < 4  )
         {
#ifdef PLUGWISEDEBUG
            domotica->log(LOG_EVENT,LOG_ERR,"Emtpy Log %s %O\n",configuration->name,logs);
#endif
            return;
         }
         int sum=0;
         foreach( logs, mapping log_item )
         {
#ifdef PLUGWISEDEBUG
         domotica->log(LOG_EVENT,LOG_DEBUG,"Loghour:%d data %d, current timestamp %d, Plugtime %O\n",log_item->hour, (int) log_item->kwh, time(1), Calendar.Minute(plug->clock()) ); 
#endif
            domotica->log(LOG_DATA,sensor_name,(["power":(string) log_item->kwh]),log_item->hour);
         }
         configuration->lastaddress=nextaddress;
      }
      //If there are multiple logs ready retrieve one every minute.
      if( ++nextaddress < plug->logaddress )
      {
#ifdef PLUGWISEDEBUG
         domotica->log(LOG_EVENT,LOG_DEBUG,"Multiple logs, running 60 second timer\n" ); 
#endif
         call_out(log, 60 );
      }
      else
         call_out(log,(int) configuration->log );

   }

}
void close()
{
   remove_call_out(log);
   //Stdio.stdout("Closing PlugWise\n");
   sensors = ([]);
   circle_plus->close();
   configuration = 0;
   domotica = 0;
}
