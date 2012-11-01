#include <module.h>
inherit Module;
#include <sensor.h>
#include <variable.h>

int module_type = MODULE_SENSOR;
string module_name = "Logger";

constant ModuleParameters= ({
                 });
constant SensorBaseParameters = ({
                   ({ "input", PARAM_SENSORINPUT,"","Input Sensor",0 }),
                   ({ "logtime", PARAM_INT,600,"Log Repeat",0 }),
                   });

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_FUNCTION;
    
   mapping SensorProperties = ([
                                  "module":"Logger",
                                  "name":"",
                                  "type":sensor_type,
                                  ]); 
   void sensor_init(  )
   {
     call_out(log_timer,(int) configuration->logtime );
   }
  
   void log_timer()
   {
      call_out(log_timer,(int) configuration->logtime );
      switchboard(SensorProperties->name,configuration->input, COM_READ);
   }
  
   void got_answer(int command, mapping params )
   {
      if ( command == -COM_READ )
         logdata(configuration->input,params->value,time(1));
      else
         logdebug("Logger can't handle return data for command %d\n",command);
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


