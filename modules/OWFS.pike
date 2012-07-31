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

   protected mapping sensor_var = ([
                                    "online": 1,
                                   ]);

   protected mapping sensor_prop = ([
                                    "module":"",
                                    "name":""
                                   ]);

   void sensor_init()
   {
      string low_type = "";
      string catch_err = catch {
         low_type = OWFS->read(configuration->path+"type") ;
      };
      if( catch_err )
      {
         logerror("Sensor %s not found\n",name);
         sensor_var->online = 0;
         return;
      }
      switch ( low_type )
      {
         case "DS2413":
            sensor_prop->sensor_type=SENSOR_INPUT|SENSOR_OUTPUT;
         break; 
         case "DS2502":
         case "DS1820":
         case "DS18B20":
            sensor_prop->sensor_type=SENSOR_INPUT;
         break;
      }
   }

   void getnew()
   {
      string low_type = "";
      string catch_err = catch {
         low_type = OWFS->read(configuration->path+"type") ;
      };
      if( catch_err )
      {
         logerror("Sensor %s not found\n",name);
         sensor_var->online = 0;
         return;
      }
      switch ( low_type )
      {
         case "DS2413":
            sensor_var->PIOA = (int)  OWFS->read(configuration->path+"PIO.A");
            sensor_var->PIOB = (int)  OWFS->read(configuration->path+"PIO.B");
         break; 
         case "DS2502":
            if( configuration->type == "vbus" )
               get_vbus();
            break;
         case "DS1820":
         case "DS18B20":
            sensor_var->temperature = (float) OWFS->read(configuration->path+"temperature") + (float) configuration->bias;
            break;
      }
   } 
  
   void get_vbus()
   {
      string data = OWFS->read(configuration->path+"memory");
      if(!sizeof(data) )
         return;
      sensor_var->collector = (float) (data[3] + (data[4]<<8)) / 10;
      sensor_var->boiler = (float) (data[5] + (data[6]<<8)) / 10 ;
      sensor_var->pump = (int) data[11] ;
      //sensor_var->state = (int) data[25] ;
   }
 
}

