#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "Logger";

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_FUNCTION;
    
   protected mapping sensor_var = ([
                                  "module":"Logger",
                                  "name":"",
                                  "type":sensor_type,
                                  "level": 0
                                  ]); 
   void sensor_init(  )
   {
      call_out(do_log,(int) configuration->logtime );
   }
   
   void do_log()
   {
      array msv = split_module_sensor_value(configuration->input);

      domotica->log(LOG_DATA,msv[0],msv[1],([msv[2]:domotica->info(configuration->input, 1)]),time(1));
      call_out(do_log,(int) configuration->logtime );
   }

 
   /* Split a sensor or module pointer into an array.
    * The array contains ({ module, sensor, attribute });
    */
   array split_module_sensor_value(string what)
   {
      array ret = ({});
      string parse = what;
      int i=search(what,".");
      while(i>0)
      {
         if( what[++i] != '.' )
         {
            ret += ({ what[..i-2] });
            what = what[i..];
            i=0;
         }
         i++;
         i=search(what,".",i);
      }
      if(sizeof(what))
         ret+= ({ what });
      return ret;
   }

}


