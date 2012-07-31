#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "WebAction";

constant defvar = ({
                  });
constant sensvar = ({
                   ({ "url", PARAM_STRING,"","Website Action URL",0 }),
                   ({ "repeat", PARAM_INT ,1,"Number of repeating calls, -1 means indefinetely",0 }),
                   ({ "time", PARAM_INT ,300,"Time between repetitions",0 }),
                   });


class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_OUTPUT;
    
   protected mapping sensor_var = ([
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
         {
            sensor_var->repeat_cnt = (int) configuration->repeat;
            call_out(webaction,0);
         }
         else
            remove_call_out(webaction);
         ret+=([ "state":sensor_var->state]);
      }
      return ret;
   }

   private void webaction()
   {
      Protocols.HTTP.get_url(configuration->url); 
      if ( sensor_var->repeat_cnt == -1 || (--sensor_var->repeat_cnt) > 0 )
      {
         call_out(webaction, (int) configuration->time);
      }
      else
         sensor_var->state = 0;

   }

   void close()
   {
      remove_call_out(webaction);
   }


}


