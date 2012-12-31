#include <module.h>
inherit Module;
#include <sensor.h>
#include <variable.h>

int module_type = MODULE_SENSOR;
string module_name = "WebAction";

constant ModuleParameters = ({
                   });

constant SensorBaseParameters = ({
                   ({ "input",PARAM_SENSORINPUTARRAY,"","Output Sensor",0 }),
                   ({ "output",PARAM_SENSOROUTPUT,"","Output Sensor",0 }),
                   ({ "delayhigh",PARAM_INT,300,"Input High Threshold",0 }),
                   ({ "delaylow",PARAM_INT,300,"Input Low Threshold",0 }),
                   });


class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_OUTPUT | SENSOR_FUNCTION;
    
   void sensor_init(  )
   {
      call_out( sensor_timer, (int) configuration->timer );
   }

   mapping write( mapping what )
   {
   }

   mapping inputvalues = ([]);

   protected void sensor_timer()
   {
      call_out( sensor_timer, (int) configuration->timer );
      foreach( configuration->input+({}), string inputsensor )
      {
         switchboard(SensorProperties->name, inputsensor, COM_READ, ([ ]));
      }
   }

   void got_answer( int command, string name, mixed params )
   {
      if ( command == -COM_READ )
      {
         inputvalues[name] = params->value;
         do_logic(); 
      }
   }

   void do_logic()
   {
      int output = 0;
      switch( (string) configuration->logic )
      {
         case "AND":
         {
            output=1;
            foreach( configuration->input+({}), string inputsensor )
            {
               if ( ! has_index(inputvalues,inputsensor) || ! ( inputvalues[inputsensor] > 0 ) )
                 output = 0;
            }
            
         }
         break;
         case "OR":
         {
            foreach( configuration->input+({}), string inputsensor )
            {
               if ( has_index(inputvalues,inputsensor) && inputvalues[inputsensor] > 0 )
                 output = 0;
            }
         }
         break;
      }
      switchboard(SensorProperties->name,configuration->output,COM_WRITE,(["value":output]));
   }
 
   void close()
   {
   }

}


