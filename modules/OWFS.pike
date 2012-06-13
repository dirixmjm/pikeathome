#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;

object OWFS;

constant defvar = ({
                   ({ "port",PARAM_STRING,"/dev/ttyUSB0","TTY Port of the USB Stick", POPT_RELOAD }),
                  });

/* Sensor Specific Variable */
constant sensvar = ({
                   ({ "path",PARAM_STRING,"","OWFS Path to sensor", 0 }),
                   ({ "type",PARAM_STRING,"","Special Type Definition", 0 }),
                    });



void init() 
{
   OWFS = Public.IO.OWFS( configuration->port );
   init_sensors(configuration->sensor + ({}) );
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
 
}

