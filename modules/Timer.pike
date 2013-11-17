#include <module.h>
inherit Module;
#include <sensor.h>
#include <variable.h>

int module_type = MODULE_SENSOR;
string module_name = "WebAction";

constant ModuleParameters = ({
                   });

constant SensorBaseParameters = ({
                   ({ "output",PARAM_SENSOROUTPUT,"","Output Sensor",0 }),
                   ({ "pretimer",PARAM_BOOLEAN,0,"Timer before Output",0 }),

		   ({ "highlow",PARAM_SELECT,(["Input Low":0,"Input High":1]),"Timer On ",0 }),
                   ({ "time",PARAM_INT,300,"Duration of the Timer",0 }),
                   });


class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_OUTPUT | SENSOR_FUNCTION;
    
   void sensor_init(  )
   {
      ValueCache->state= ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
   }

   mapping write( mapping what )
   {

      mapping ret = ([]);
      if( has_index(what,"state") )
      {
         remove_call_out(do_output);
         ValueCache->state = (int) what->state;
         if ( (int) configuration->pretimer )
         {
            call_out(do_output,(int) configuration->time,(int) what->state);
         }
         else
         {
            call_out(do_output,0,(int) what->state);
            if ( (int) configuration->highlow )
               call_out(do_output,(int) configuration->time,! (int) what->state);
         }
         ret+=([ "state":what->state ]);
      }
      return ret;
   }

   private void do_output( int state )  
   {
       switchboard(SensorProperties->name,configuration->output,COM_WRITE,(["value":state]));
   }

   void close()
   {
      remove_call_out(do_output);
   }

}


