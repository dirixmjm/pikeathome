#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;

string module_name = "Comperator";

constant defvar = ({
                  });

constant sensvar = ({
                   ({ "input",PARAM_SENSORINPUT,"","Input Sensor",0 }),
                   ({ "output",PARAM_SENSOROUTPUT,"","Output Sensor",0 }),
                   ({ "timer",PARAM_INT,300,"Time Value (Seconds)",0 }),
                   ({ "highlevel",PARAM_INT,300,"Input High Threshold",0 }),
                   ({ "lowlevel",PARAM_INT,300,"Input Low Threshold",0 }),
                   ({ "gracecount",PARAM_INT,300,"Grace Time = Grace Count * timer",0 }),
                   ({ "function",PARAM_INT,0,"Comperator Function",0 }),
                   });

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_FUNCTION;
   //Grace counter;
   int counter = 0;
 
   protected mapping sensor_var = ([
                                  "module":"Comperator",
                                  "name":"",
                                  "type":sensor_type,
                                  "level": 0
                                  ]);
   protected mapping sensor_prop = ([
                                  "module":"Comperator",
                                  "name":"",
                                  "type":sensor_type,
                                  ]);
 
   void sensor_init(  )
   {
      counter = (int) configuration->gracecount;
      call_out(sensor_timer, (int) configuration->timer);
   }

   protected void sensor_timer()
   {
      call_out(sensor_timer, (int) configuration->timer);
      switchboard(sensor_prop->name,configuration->input, COM_INFO, (["new":1]), compare);
   }

   void written(mixed returnvalue )
   {
     return;
 
   }

   void got_answer( mixed params)
   {
      compare(params);
   }
 
   void compare(float|int|string|mapping input)
   {
      //FIXME Error handling

      int lastlevel = sensor_var->level;
      int newlevel = (float) input > (float) configuration->highlevel;
      if( newlevel !=  lastlevel )
      {
         if( (--counter) == 0 )
         {
            sensor_var->level = newlevel;
            counter = (int) configuration->gracecount;
         }
      }
      else
         counter = (int) configuration->gracecount;

      /*Detect LOW (function = 0) or HIGH (function = 1) levels.
       *The sensor sensor will send ON (1) and OFF (0) signals to
       *the output each time the signal level changes.
       *Detect LOW-HIGH (function = 2) or HIGH-LOW (function = 3)
       *level changes will only send an ON (1) on the according 
       *level change.
       */ 
       //Lastlevel = 0, level = 1 (HIGH / LOW-HIGH )
       if( lastlevel < sensor_var->level ) 
       {
          switch( (int) configuration->function )
          {
             case 0:
                switchboard(sensor_prop->name,configuration->output,COM_WRITE,(["values":0]),written);
                break;
             case 1:
             case 2:
                switchboard(sensor_prop->name,configuration->output,COM_WRITE,(["values":1]),written);
                break;
          }
       }
       else if( lastlevel > sensor_var->level ) 
       {
          switch( (int) configuration->function )
          {
             case 1:
                switchboard(sensor_prop->name,configuration->output,COM_WRITE,(["values":0]),written);
                break;
             case 0:
             case 3:
                switchboard(sensor_prop->name,configuration->output,COM_WRITE,(["values":1]),written);
                break;
          }
       }
   } 

}


