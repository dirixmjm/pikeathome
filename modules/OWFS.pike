#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "OWFS";

static object OWFS;

constant defvar = ({
                   ({ "port",PARAM_STRING,"/dev/ttyUSB0","TTY Port of the USB Stick", POPT_RELOAD }),
                  });

/* Sensor Specific Variable */
constant sensvar = ({
                   ({ "special_type",PARAM_STRING,"","Special Type Definition", 0 }),
                    });



void module_init() 
{
   OWFS = Public.IO.OWFS( configuration->port );
   init_sensors(configuration->sensor + ({}) );
}


void init_sensors( array load_sensors )
{
   foreach(load_sensors, string name )
   {
      sensors+= ([ name: sensor( name, OWFS, domotica->configuration(name) ) ]);
   }
}

array find_sensors(int|void manual)
{
   array ret = ({});
//   foreach(OW->devices(1), object dev )
//      ret+= ({ ([ "sensor":dev->serial, "module":name,"parameters":sensvar ]) }) ;
   return ret;
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

