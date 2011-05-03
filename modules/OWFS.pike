#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "OWFS";

static object OWFS;

void module_init() 
{
   OWFS = Public.IO.OWFS( configuration->port );
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
                                    "module":"OWFS",
                                    "online": 1,
                                    "value": 0.0
                                   ]);

   void getnew()
   {
      sensor_var->value = (float) OWFS->read(configuration->path) + (float) configuration->bias;
   } 
   
   void log()
   {
      domotica->log(LOG_DATA,sensor_name,(["temperature":sprintf("%f",(float) OWFS->read(configuration->path) + (float) configuration->bias) ]), time(1) );
   }
}

