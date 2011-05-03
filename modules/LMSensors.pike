#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "LMSensors";

static object LMSensors;

void module_init() 
{
   LMSensors = Public.IO.LMSensors( configuration->sensorsconf );
   array load_sensors; 
   if(!arrayp(configuration->sensor) )
      load_sensors = ({ configuration->sensor });
   else
      load_sensors = configuration->sensor;

   foreach(load_sensors, string name )
      sensors+= ([ name: sensor( name, domotica ) ]);
}

class sensor
{

   inherit Sensor;

   int sensor_type = SENSOR_INPUT;    
   protected mapping sensor_var = ([
                                    "module":"LMSensors",
                                    "online": 1,
                                    "value": 0.0
                                   ]);

   void getnew()
   {
      array sensor = LMSensors->get_sensor_data(configuration->sensor);
      foreach(sensor, mapping temp)
      {
         if( temp->label == configuration->label )
            sensor_var->value = temp->input;
      }
   } 
}
void close()
{
   LMSensors = 0;
   configuration = 0;
   domotica = 0;
}
