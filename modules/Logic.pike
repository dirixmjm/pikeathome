#include <module.h>
inherit Module;
#include <sensor.h>
#include <variable.h>

int module_type = MODULE_SENSOR;
string module_name = "WebAction";

constant ModuleParameters = ({
                   });

constant SensorBaseParameters = ({
                   ({ "input",PARAM_INT,"","Number of Inputs Sensor",0 }),
                   ({ "output",PARAM_SENSOROUTPUT,"","Output Sensor",0 }),
                   ({ "function",PARAM_INT,0,"Logic Function",0 }),
                   });


class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_OUTPUT | SENSOR_FUNCTION;
    
   void sensor_init(  )
   {
      for( int i=1; i <= (int) configuration->input; i++ )
      {
         ValueCache[sprintf("input%d",i)]= ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
      }
         ValueCache->state= ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
   }

   mapping write( mapping what )
   {
      foreach(what; string index; mixed value)
      {
         if( has_index(ValueCache,index))
            ValueCache[index]= (int) value;
      }
      do_logic(); 
   }

   void got_answer( int command, string name, mixed params )
   {
   }

   void do_logic()
   {
      int output = 0;
      switch( (int) configuration->function )
      {
         case 0:
         {
            output=1;
            for( int i=1; i <= (int) configuration->input; i++ )
            {
               if( !ValueCache[sprintf("input%d",i)] > 0 )
                  output = 0;
            }
         }
         break;
         case 1:
         {
            output = 0;
            for( int i=1; i <= (int) configuration->input; i++ )
            {
               if( ValueCache[sprintf("input%d",i)] > 0 )
                  output = 1;
            }
         }
         break;
      }
      ValueCache->state=output;
      switchboard(SensorProperties->name,configuration->output,COM_WRITE,(["value":output]));
   }
 
   void close()
   {
   }

}


