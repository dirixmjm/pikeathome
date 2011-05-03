//! TimePlan scheduler
#include <module.h>

inherit Module;

int module_type = MODULE_SENSOR | MODULE_SCHEDULE;

string module_name="TimeTable";

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_SCHEDULE;

   mapping sensor_var = ([
      "module": "TimeTable",
      "state": 0,
      //Variable of the schedule pre-announcer (Necessary for the Heater module)
       "current_schedule" : 0,
      "next_schedule" : 0,
      "next_schedule_time": Calendar.Minute()
   ]);   

   array theschedule = ({ 
   });



   void sensor_init()
   {
      //FIXME Load Schedule from database.
      theschedule = configuration->schedule;
      sort_schedule();
      find_last_schedule();
      if ( has_index(configuration, "scheduletime") )
         call_out(run_schedule,0);
   }

   void sort_schedule()
   {
      if(!theschedule || !sizeof(theschedule) )
      {
         domotica->log(LOG_EVENT,LOG_ERR,"No Schedule defined for TimePlan %s",sensor_var->name);
         return;
      }
      array to_sort = ({});
      foreach( theschedule->start, string time)
      {
         to_sort += ({ (int) time });
      }
      sort(to_sort,theschedule);

   }

   /* This is the automatically returning scheduling functies
   */
   void run_schedule()
   {

     int seconds  = schedule();

      //Set output sensor to current setting to the newly scheduled.
      domotica->write(configuration->output, theschedule[sensor_var->current_schedule]->value ); 
#ifdef TIMETABLEDEBUG
      domotica->log(LOG_EVENT,LOG_DEBUG,"Done schedule, output %d\n", theschedule[sensor_var->current_schedule]->value);
#endif

     if ( seconds >= 0 )
     {
        call_out(run_schedule,seconds);
        //only call pre announcer when there is a valid timespan.
        if( has_index(theschedule[sensor_var->current_schedule],"pretimer") && (int) theschedule[sensor_var->current_schedule]->pretimer > 0 && seconds-(int) theschedule[sensor_var->current_schedule]->pretimer > 0 )
           call_out(preannounce,seconds-(int) theschedule[sensor_var->current_schedule]->pretimer);
 
     }
     else if ( has_index(configuration, "scheduletime") )
        call_out(run_schedule,(int) configuration->scheduletime);
     else 
        call_out(run_schedule,600);
   }


   void preannounce()
   {
      if ( has_index(configuration, "preoutput" ) )
         domotica->write(configuration->output, theschedule[sensor_var->next_schedule]->value ); 
   }

   void find_last_schedule()
   {
      if(!theschedule || !sizeof(theschedule))
         return ;
      //A safety gauch, to prevent it from looping forever.
      int loopcount = 0;

      object this_minute = Calendar.Minute();
      object last_schedule = 0;
      int day = 0;
      int dow = Calendar.Day()->week_day();
      int schedule_start = sizeof(theschedule);
      while( !last_schedule || this_minute <= last_schedule )
      {
         if(loopcount++ > 16 )
         {
            domotica->log(LOG_EVENT,LOG_ERR,"TimePlan Loop Safety Gauch Applied");
            return;
         }
         schedule_start--;
         if(has_value( theschedule[schedule_start]->dow/",", (string) dow) )
         {
            last_schedule = Calendar.Day();
            last_schedule = last_schedule - Calendar.Day()*day;
            last_schedule = last_schedule + Calendar.Minute()*(int) theschedule[schedule_start]->start;
            last_schedule = last_schedule->beginning();
         }
         
         if(schedule_start == 0 )
         {
            schedule_start = sizeof(theschedule);
            day++;
            object a = Calendar.Day() - Calendar.Day()*day;
            dow = a->week_day();
         }
      }

#ifdef TIMETABLEDEBUG
      domotica->log(LOG_EVENT,LOG_DEBUG,"Current %O %d\n", last_schedule, schedule_start );
#endif
      //Set the current (and next, schedule sets current = next)
      sensor_var->current_schedule=schedule_start;
      sensor_var->next_schedule=schedule_start;
   }

   int schedule()
   {
#ifdef TIMETABLEDEBUG
      domotica->log(LOG_EVENT,LOG_DEBUG,"Next %d\n",sensor_var->next_schedule );
#endif
      if(!schedule || !sizeof(theschedule))
         return -1;
      //A safety gauch, to prevent it from looping forever.
      int loopcount = 0;

      object this_minute = Calendar.Minute();
      object next_schedule = 0;
      int day = 0;
      int dow = Calendar.Day()->week_day();
      //Start at the first schedule (0).
      int schedule_start = -1;
      while( !next_schedule || this_minute >= next_schedule )
      {
         if(loopcount++ > 16 )
         {
            domotica->log(LOG_EVENT,LOG_ERR,"TimePlan Loop Safety Gauch Applied");
            return -1;
         }
         //Go to next schedule in theschedule table.
         if(++schedule_start == sizeof(theschedule) )
         {
            schedule_start = 0;
            day++;
            object a = Calendar.Day() + Calendar.Day()*day;
            dow = a->week_day();
            werror("%d\n",day);
         }

         if(has_value( theschedule[schedule_start]->dow/",", (string) dow) )
         {
            next_schedule = Calendar.Day();
            next_schedule = next_schedule + Calendar.Day()*day;
            next_schedule = next_schedule + Calendar.Minute()*(int) theschedule[schedule_start]->start;
            next_schedule = next_schedule->beginning();
         }
      }
      sensor_var->current_schedule = sensor_var->next_schedule;
      sensor_var->next_schedule = schedule_start;
      sensor_var->next_schedule_time = next_schedule; 
      //Schedule next run when the next schedule starts.
#ifdef TIMETABLEDEBUG
      domotica->log(LOG_EVENT,LOG_DEBUG,"Current %d Next %O %d\n", sensor_var->current_schedule, next_schedule, schedule_start );
#endif
      return sensor_var->next_schedule_time->unix_time()-time();
   }
 
   mapping write( mapping what )
   {
#ifdef TIMETABLEDEBUG
      domotica->log(LOG_EVENT,LOG_DEBUG,"Write %O\n",what );
#endif
   }
   
   void close()
   {
      remove_call_out(run_schedule);
      remove_call_out(preannounce);
   }
}
