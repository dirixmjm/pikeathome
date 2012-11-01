#include <module.h>
inherit Module;
#include <sensor.h>
#include <variable.h>

int module_type = MODULE_SENSOR;
string module_name = "WebAction";

constant ModuleParameters = ({
                  });
constant SensorBaseParameters = ({
                   ({ "url", PARAM_STRING,"","Website Action URL",0 }),
                   ({ "repeat", PARAM_INT ,1,"Number of repeating calls, -1 means indefinetely",0 }),
                   ({ "time", PARAM_INT ,300,"Time between repetitions",0 }),
                   });


class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_OUTPUT;
    
   void sensor_init(  )
   {
      ValueCache->state= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
   }

   mapping write( mapping what )
   {

      mapping ret = ([]);
      if( has_index(what,"state") )
      {
         ValueCache->state = (int) what->state;
         if( ValueCache->state )
         {
            ValueCache->repeat_cnt = (int) configuration->repeat;
            call_out(webaction,0);
         }
         else
            remove_call_out(webaction);
         ret+=([ "state":ValueCache->state]);
      }
      return ret;
   }

   private void webaction()
   {
      Protocols.HTTP.get_url(configuration->url); 
      if ( ValueCache->repeat_cnt == -1 || (--ValueCache->repeat_cnt) > 0 )
      {
         call_out(webaction, (int) configuration->time);
      }
      else
         ValueCache->state = 0;

   }

   void close()
   {
      remove_call_out(webaction);
   }


}


