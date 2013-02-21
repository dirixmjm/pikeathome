#include <module.h>
#include <sensor.h>
#include <variable.h>

inherit Module;

int module_type = MODULE_SENSOR;

string module_name = "Comperator";

constant ModuleParameters = ({
                  });

constant SensorBaseParameters = ({
                   ({ "input",PARAM_SENSORINPUT,"","Input Sensor",0 }),
                   ({ "output",PARAM_SENSOROUTPUTARRAY,"","Output Sensor",0 }),
                   ({ "timer",PARAM_INT,300,"Time Value (Seconds)",0 }),
                   ({ "highlevel",PARAM_INT,300,"Input High Threshold",0 }),
                   ({ "lowlevel",PARAM_INT,300,"Input Low Threshold",0 }),
                   ({ "gracecount",PARAM_INT,300,"Grace Time = Grace Count * timer",0 }),
                   ({ "grace",PARAM_STRING,"","Grace function: avg, last",0 }),
                   ({ "function",PARAM_SELECT,(["Detect Low":0,"Detect High":1,"Detect Low to High":2,"Detect High to Low":3]),"Comperator Function",0 }),
                   ({ "passive",PARAM_BOOLEAN,0,"Passive Output",0 }),
                   });

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_FUNCTION;
   //Grace counter;
   int counter = 0;
   array gracevalues = ({});

   protected object ValueCache = VariableStorage( );
 
   mapping SensorProperties = ([
                                  "module":"Comperator",
                                  "name":"",
                                  "type":sensor_type,
                                  ]);
 
   void sensor_init(  )
   {
      counter = (int) configuration->gracecount;
      call_out(sensor_timer, (int) configuration->timer);
      ValueCache->level= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
      if ( (int) configuration->passive == 1 )
         ValueCache->state= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
   }

   protected void sensor_timer()
   {
      call_out(sensor_timer, (int) configuration->timer);
      switchboard(SensorProperties->name,configuration->input, COM_READ,([]));
   }

   void got_answer(int command, string name, mixed params)
   {
      if ( command  == -COM_READ)
      {
            compare(params);
      }
   }
 
   void compare(mapping input)
   {
      ValueCache->lastinput = input->value;
      int lastlevel = ValueCache->level;
      switch( configuration->grace )
      {
         case "last":
         int newlevel = 0;
         if( lastlevel == 0 )
           newlevel = (float) input->value >= (float) configuration->highlevel;
         else
           newlevel = (float) input->value > (float) configuration->lowlevel;

         if( newlevel !=  lastlevel )
         {
            if( (--counter) == 0 )
            {
               ValueCache->level = newlevel;
               counter = (int) configuration->gracecount;
            }
         }
         else
            counter = (int) configuration->gracecount;
         ValueCache->counter = counter;
         break;
         case "avg":
         gracevalues += ({ (float) input->value });
         if( sizeof(gracevalues) > (int) configuration->gracecount )
            gracevalues = gracevalues[1..];
         float avgvalue = Array.sum( gracevalues) / sizeof(gracevalues);
         if( lastlevel == 0 )
           ValueCache->level = (float) avgvalue >= (float) configuration->highlevel;
         else
           ValueCache->level = (float) avgvalue > (float) configuration->lowlevel;
         ValueCache->avg = avgvalue;
         break;
         case "off":
         default:
            //Hystereses
            if( lastlevel == 0 )
              ValueCache->level = (float) input->value >= (float) configuration->highlevel;
            else
              ValueCache->level = (float) input->value > (float) configuration->lowlevel;
      }

      /*Detect LOW (function = 0) or HIGH (function = 1) levels.
       *The sensor sensor will send ON (1) and OFF (0) signals to
       *the output each time the signal level changes.
       *Detect LOW-HIGH (function = 2) or HIGH-LOW (function = 3)
       *level changes will only send an ON (1) on the according 
       *level change.
       */ 
       //Lastlevel = 0, level = 1 (HIGH / LOW-HIGH )
       if( lastlevel < (int) ValueCache->level ) 
       {
          switch( (int) configuration->function )
          {
             case 0:
             {
                ValueCache->state = 0;
                WriteOut(0);
             }
             break;
             case 1:
             case 2:
             {
                ValueCache->state = 1;
                WriteOut(1);
             }
             break;
          }
       }
       else if( lastlevel > ValueCache->level ) 
       {
          switch( (int) configuration->function )
          {
             case 1:
             {
                ValueCache->state = 0;
                WriteOut(0);
             }
             break;
             case 0:
             case 3:
             {
                ValueCache->state = 1;
                WriteOut(1);
             }
             break;
          }
       }
   }
 
   protected void WriteOut(int value)
   {
      if( !((int) configuration->passive) )
      {
         foreach( configuration->output || ({}), string output)
            switchboard(SensorProperties->name,output,COM_WRITE,(["value":value]));
      }
   }

}


