#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "WebAction";

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_OUTPUT;
    
   protected mapping sensor_var = ([
                                  "module":"WebAction",
                                  "name":"",
                                  "type":sensor_type,
                                  "state":0
                                  ]); 
   void sensor_init(  )
   {
   }

   mapping write( mapping what )
   {

      mapping ret = ([]);
      if( has_index(what,"state") )
      {
         sensor_var->state = (int) what->state;
         if( sensor_var->state )
            call_out(webaction,0);
         else
            remove_call_out(webaction);
         ret+=([ "state":sensor_var->state]);
      }
      return ret;
   }

   private void webaction()
   {
      Protocols.HTTP.get_url(configuration->url); 
      if ( has_index(configuration, "repeat") )
         call_out(webaction, (int) configuration->repeat);
   }

   void close()
   {
      remove_call_out(webaction);
   }


}


