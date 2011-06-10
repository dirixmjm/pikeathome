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
                                   ]);

   void getnew()
   {
      switch ( configuration->type )
      {
         case "vbus":
            get_vbus();
            break;
         default:
            sensor_var->temperature = (float) OWFS->read(configuration->path) + (float) configuration->bias;
            break;
      }
   } 
  
   void get_vbus()
   {
      string data = OWFS->read(configuration->path);
      if(!sizeof(data) )
         return;
      sensor_var->collector = (float) (data[3] + (data[4]<<8)) / 10;
      sensor_var->boiler = (float) (data[5] + (data[6]<<8)) / 10 ;
      sensor_var->pump = (int) data[11] ;
      //sensor_var->state = (int) data[25] ;
   }
 
   void log()
   {
      getnew();
      switch ( configuration->type )
      {
         case "vbus":
            domotica->log(LOG_DATA,sensor_var->module,sensor_var->name,(["collector":sensor_var->collector,"boiler":sensor_var->boiler,"pump":sensor_var->pump ]) );
            break;
         default:
            domotica->log(LOG_DATA,sensor_var->module,sensor_var->name,(["temperature":sensor_var->temperature ]), time(1) );
            break;
      }
   }
}

