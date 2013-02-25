//! TimePlan scheduler
#include <module.h>
#include <sensor.h>
#include <variable.h>

inherit Module;

int module_type = MODULE_SENSOR | MODULE_SCHEDULE;

constant ModuleParameters = ({
	({ "LongestDay",PARAM_INT,172,"Longest Day of the Year",POPT_NONE }),
         ({ "debug",PARAM_BOOLEAN,0,"Turn On / Off Debugging",POPT_NONE }),

                  });

constant SensorBaseParameters = ({
                   ({ "output",PARAM_SENSOROUTPUT,"","Output Sensor",0 }),
                   //Preoutput is used by an external module, 
                   //e.g. a heater which wants to dynamically set pre-heating.
                   ({ "preoutput",PARAM_BOOLEAN,0,"Turn On / Off Adaptive Scheduling",0 }),
                   ({ "scheduletime",PARAM_INT,600,"Fallback Schedule Timing",0 }),
                   ({ "schedule",PARAM_SCHEDULE,"","The Schedule",POPT_RELOAD }),
                   });

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_SCHEDULE;


   array theschedule = ({ 
   });



   void sensor_init()
   {
      ValueCache->current_schedule= ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
      ValueCache->next_schedule= ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
      //Variable of the schedule pre-announcer (Necessary for the Heater module)
      ValueCache->next_schedule_time= ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
      theschedule = configuration->schedule;
      sort_schedule();
      find_last_schedule();
      if( theschedule && sizeof(theschedule) )
         call_out(run_schedule,0);
   }

   void sort_schedule()
   {
      if(!theschedule || !sizeof(theschedule) )
      {
         logerror("No Schedule defined for TimePlan %s",SensorProperties->name);
         return;
      }
      array to_sort = ({});
      foreach( theschedule->start, string time)
      {
         to_sort += ({ (int) time });
      }
      sort(to_sort,theschedule);

   }

   //Reload Sensor due to change of option <option>
   void SensorReload(string option)
   {
      remove_call_out(run_schedule);
      theschedule = configuration->schedule;
      sort_schedule();
      find_last_schedule();
      if( theschedule && sizeof(theschedule) )
         call_out(run_schedule,0);
      
   }


   /* This is the automatically returning scheduling functies
   */
   void run_schedule()
   {

     int seconds  = schedule();

     if ( seconds >= 0 )
     {
        call_out(run_schedule,seconds);

        //Check if the next schedule has a Day-length antedating
        if ( has_index( theschedule[ValueCache->next_schedule] , "antedate")
             && (int) theschedule[ValueCache->next_schedule]->antedate > 0 )
        {
           //Calculate number of days from the longest day.
           int longestday = module->GetParameter("LongestDay");
           int days = (Calendar.Day()->year_day() +365 - longestday)%365;
           int antedate_seconds = seconds - (days*60* (int) theschedule[ValueCache->next_schedule]->antedate);
           if( antedate_seconds < 0 )
              antedate_seconds = 0;

           call_out( switchboard, antedate_seconds, SensorProperties->name,configuration->output,COM_WRITE,(["value": (int) theschedule[ValueCache->next_schedule]->value]));

        }
        //only call pre announcer when there is a valid timespan.
        //The pretimer can be changed by an external module using the TimeTable.
        if( has_index(theschedule[ValueCache->current_schedule],"pretimer") && (int) theschedule[ValueCache->current_schedule]->pretimer > 0 && seconds-(int) theschedule[ValueCache->current_schedule]->pretimer > 0 )
           call_out(preannounce,seconds-(int) theschedule[ValueCache->current_schedule]->pretimer);
 
     }
     else if ( has_index(configuration, "scheduletime") )
        call_out(run_schedule,(int) configuration->scheduletime);
     else 
        call_out(run_schedule,600);
      //Set output sensor to current setting to the newly scheduled.
      switchboard(SensorProperties->name,configuration->output,COM_WRITE,(["value": (int) theschedule[ValueCache->current_schedule]->value]));
      logdebug("Done schedule, output %d\n", (int) theschedule[ValueCache->current_schedule]->value);
   }


   void preannounce()
   {
      if ( has_index(configuration, "preoutput" ) && configuration->preoutput==1 )
         switchboard(SensorProperties->name,configuration->output,COM_WRITE,(["value":theschedule[ValueCache->current_schedule]->value]));

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
            logerror("TimePlan Loop Safety Gauch Applied");
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

      logdebug("Current %O %d\n", last_schedule->format_nice(), schedule_start );
      //Set the current (and next, schedule sets current = next)
      ValueCache->current_schedule=schedule_start;
      ValueCache->next_schedule=schedule_start;
   }

   int schedule()
   {
      logdebug("Next %d\n", (int) ValueCache->next_schedule );
      if(!theschedule || !sizeof(theschedule))
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
            logerror("TimePlan Loop Safety Gauch Applied");
            return -1;
         }
         //Go to next schedule in theschedule table.
         if(++schedule_start == sizeof(theschedule) )
         {
            schedule_start = 0;
            day++;
            object a = Calendar.Day() + Calendar.Day()*day;
            dow = a->week_day();
         }

         if(has_value( theschedule[schedule_start]->dow/",", (string) dow) )
         {
            next_schedule = Calendar.Day();
            next_schedule = next_schedule + Calendar.Day()*day;
            next_schedule = next_schedule + Calendar.Minute()*(int) theschedule[schedule_start]->start;
            next_schedule = next_schedule->beginning();
         }
      }
      ValueCache->current_schedule = ValueCache->next_schedule;
      ValueCache->next_schedule = schedule_start;
      ValueCache->next_schedule_time = next_schedule->unix_time();
      //Schedule next run when the next schedule starts.
      logdebug("Current %d Next %s %d\n", ValueCache->current_schedule, next_schedule->format_nice(), schedule_start );
      return ValueCache->next_schedule_time-time();
   }
 
   mapping write( mapping what )
   {
      logdebug("Write %O\n",what );
   }
  
   void close()
   {
      remove_call_out(run_schedule);
      remove_call_out(preannounce);
   }
}
