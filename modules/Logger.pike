#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "Logger";

constant defvar= ({
                 });
constant sensvar = ({
                   ({ "input", PARAM_SENSORINPUT,"","Input Sensor",0 }),
                   ({ "logtime", PARAM_INT,600,"Log Repeat",0 }),
                   });

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
     call_out(log_timer,(int) configuration->logtime );
   }
  
   void log_timer()
   {
      call_out(log_timer,(int) configuration->logtime );
      call_out(module->switchboard, 0, configuration->input, COM_INFO, (["new":1]), do_log);
   }
   
   void do_log(int|float|string input)
   {
      call_out(module->switchboard, (int) configuration->logtime, configuration->input, COM_INFO, (["new":1]), do_log);

      logdata(configuration->input,input,time(1));
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


