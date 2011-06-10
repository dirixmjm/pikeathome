//! TimePlan scheduler
#include <module.h>

inherit Module;

int module_type = MODULE_SENSOR | MODULE_SCHEDULE;

string module_name="Heater";
//FIXME what about a cool-down pretimer?
//FIXME Check if someone is home or not. (And what about pre-timers?)
//FIXME Work with multiple sensors?

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_FUNCTION;

   mapping sensor_var = ([
      "module": "Heater",
      "temperature" : 0.0,
      "value": 0.0,
      "state": 0,
   ]);   

   protected int measure_pretimer = 0;
   protected int pretime = 0;
   protected int pretimer_schedule = 0;

   void sensor_init()
   {
      call_out(set_heater,30);
   }

   void set_heater()
   {
      if ( ! ( sensor_var->value = domotica->info(configuration->input, 1) ) )
      {
         domotica->log(LOG_EVENT,LOG_ERR,"Error: Input Sensor %s not found, turning off heater\n",
                                                          configuration->input);
           domotica->write(configuration->output, 0);
         return;
      }
      //Temperature Control
      if( sensor_var->value < (float) sensor_var->temperature )
         sensor_var->state = 1;
      else
      {
         sensor_var->state = 0;
         //Check if we are measuring pre-heating timings, and set the schedule accordingly.
         //FIXME What happens the schedule changes while measuring.
         if( measure_pretimer == 1)
         {
            measure_pretimer = 0;
            domotica->write(configuration->schedule, ([ "schedule":pretimer_schedule, "pretimer": time() - pretime ]) );
#ifdef HEATERDEBUG
      domotica->log(LOG_EVENT,LOG_DEBUG,"Done pretimer, pretimer set to %d\n",time(1) - pretime);
#endif
         }
      }
#ifdef HEATERDEBUG
      domotica->log(LOG_EVENT,LOG_DEBUG,"Sensor %f, Set %f, Output %d\n",sensor_var->value, sensor_var->temperature,(int) sensor_var->state);
#endif

      call_out(set_heater, 30 );
      domotica->write(configuration->output,sensor_var->state);
   }

   mapping write( mapping what )
   {
      if( has_index(what, "temperature") )
      {
         //Only start pretimer measurement if it hasn't been started during a
         //pretemp start.
         if(!measure_pretimer && (float) what->temperature > sensor_var->temperature && has_index(what,"schedule") )
         {
#ifdef HEATERDEBUG
      domotica->log(LOG_EVENT,LOG_DEBUG,"Starting pretimer Measurement\n");
#endif
            measure_pretimer = 1;
            pretime = time();
            pretimer_schedule = what->schedule;
         }
         //If output temperature changes to a value below the currently
         //set temperature, stop measurening the pretimer
         if( measure_pretimer && (float) what->temperature < sensor_var->temperature)
            measure_pretimer = 0;
         sensor_var->temperature = (float) what->temperature;
      }
      if( has_index(what, "pretemp") )
      {
            //Start measuring the pretimer value.
            if((float) what->pretemp > sensor_var->temperature)
            {
#ifdef HEATERDEBUG
      domotica->log(LOG_EVENT,LOG_DEBUG,"Starting pretimer Measurement in pretimer\n");
#endif
               measure_pretimer = 1; 
               pretime = time(); 
               pretimer_schedule = what->schedule;
               //Only set the new temperature if it is higher.
               sensor_var->temperature = (float) what->pretemp;
            }
            sensor_var->schedule = domotica->read(configuration->schedule+".next_schedule");
      }
   }

   void close()
   {
      remove_call_out(set_heater);
   }
}
