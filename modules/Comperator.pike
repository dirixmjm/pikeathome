#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "Comperator";

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_FUNCTION;
    
   protected mapping sensor_var = ([
                                  "module":"Comperator",
                                  "name":"",
                                  "type":sensor_type,
                                  "level": 0
                                  ]); 
   void sensor_init(  )
   {
      call_out(compare,(int) configuration->timer );
   }
   
   void compare()
   {
      int lastlevel = sensor_var->level;
      if( domotica->info(configuration->input, 1) > (float) configuration->high )
         sensor_var->level = 1;

      if( domotica->info(configuration->input, 1) < (float) configuration->high )
         sensor_var->level = 0;

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
                domotica->write(configuration->output, 0);
                break;
             case 1:
             case 2:
                domotica->write(configuration->output, 1);
                break;
          }
       }
       else if( lastlevel > sensor_var->level ) 
       {
          switch( (int) configuration->function )
          {
             case 1:
                domotica->write(configuration->output, 0);
                break;
             case 0:
             case 3:
                domotica->write(configuration->output, 1);
                break;
          }
       }
       call_out(compare,(int) configuration->timer );
   } 

}


