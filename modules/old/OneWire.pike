#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "OneWire";

object OW;

constant defvar = ({
                   ({ "port",PARAM_STRING,"/dev/ttyUSB0","TTY Port of the USB Stick", POPT_RELOAD }),
                  });

/* Sensor Specific Variable */
constant sensvar = ({
                    ({ "log",PARAM_BOOLEAN,0,"Turn On / Off Logging",0 }),
                    });

void init() 
{
   
   mixed er = catch{
      OW = Public.IO.OneWire.Net( configuration->port ); 
   };
   if( er )
   {
     logerror("Failed to open port %s\n",configuration->port);
     return;
   }
    
   init_sensors( configuration->sensor+({}) );
}


array find_sensors(int|void manual)
{
   array ret = ({});
   foreach(OW->devices(1), object dev )
      ret+= ({ ([ "sensor":dev->serial, "module":name,"parameters":sensvar ]) }) ;
   return ret;
}

void init_sensors( array load_sensors )
{
   foreach(load_sensors, string name )
   {
      sensors+= ([ name: sensor( name, this, domotica->configuration(name) ) ]);
   }
}


class sensor
{

   inherit Sensor;
   object device;

   protected mapping sensor_var = ([
                                    "module":"OW",
                                    "online": 1,
                                   ]);
   void sensor_init()
   {
      //FIXME create find_device function in OneWire.

      array devices = module->OW->devices(1);
      foreach(devices, object dev )
      {
         if(dev->serial == configuration->sensor )
         {
            device = dev; 
            switch(dev->family)
            {
               case 0x10:
               case 0x28:
               sensor_var->sensor_type = SENSOR_INPUT;
               sensor_var->temperature = -1.0;
            }
         }
      }
   }

   mapping write( mapping what )
   {
      domotica->log(LOG_EVENT,LOG_DEBUG,"OW Write %O\n",what);
      mapping ret=([]);
   return ret;
   }

   void getnew()
   {
      switch(device->family)
      {
         case 0x10:
         case 0x28:
         sensor_var->temperature = device->temperature();
         break;
      }
   } 
  
   void get_vbus()
   {
      string data = OW->read(configuration->path);
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
      switch ( device->family )
      {
         case 0x10:
         case 0x28:
            logdata(sensor_prop->name+".temperature",sensor_var->temperature, time(1) );
            break;
      }
   }
}

