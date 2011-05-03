#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "Variable";

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_INPUT | SENSOR_OUTPUT;
    
   protected mapping sensor_var = ([
                                  "module":"Variable",
                                  "name":"",
                                  "type":sensor_type,
                                  ]); 
   void sensor_init(  )
   {
      sensor_type = (int) configuration->sensor_type;
      sensor_var->sensor_type=sensor_type;
      if( sensor_type & SENSOR_INPUT )
          sensor_var["value"]=0.0;
      if( sensor_type & SENSOR_OUTPUT )
          sensor_var["state"]=0;
   }

   mapping write( mapping what )
   {
      mapping ret = ([]);
      if( (sensor_type & SENSOR_INPUT) && has_index(what,"value") )
      {
         sensor_var->value = (float) what->value;
         ret+=([ "value":sensor_var->value]);
      }
      if( (sensor_type & SENSOR_OUTPUT) && has_index(what,"state") )
      {
         sensor_var->state = (int) what->state;
         ret+=([ "state":sensor_var->state]);
      }
      return ret;
   }
 
}


