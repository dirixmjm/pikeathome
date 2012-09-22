#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;

object OWFS;

constant defvar = ({
                   ({ "port",PARAM_STRING,"/dev/ttyUSB0","TTY Port of the USB Stick", POPT_RELOAD }),
                  });

/* Sensor Specific Variable */
constant sensvar = ({
                   ({ "type",PARAM_STRING,"","Special Type Definition", 0 }),
                    });



void init() 
{
#ifdef DEBUG
   logdebug("Init Module %s\n",name);
#endif
   OWFS = Public.IO.OWFS( configuration->port );
   init_sensors(configuration->sensor + ({}) );
}

array find_sensors()
{
   array ret = ({});
   array device_path = get_device_path("/");
   werror("%O\n",device_path);
   foreach( device_path, string path )
   {
      array var = sensvar;
      var+= ({ ({ "name",PARAM_STRING,"default","Name"})});
      ret += ({ ([ "sensor":path,"module":name,"parameters":var ]) });
   }
   return ret;
}

array get_device_path(string path)
{
   array ret = ({});
   object traversion = OWFS->Traversion( path );
   array files = traversion->files;
   werror("%O\n",files);
   foreach(files, string filename )
   {
      int a=0;
      //Check if this is a device.
      if ( sscanf(filename,"%2x.%*s",a) && has_value ( OWFS->Traversion(filename)->files, "type" ))
      {
         ret+=({ path + filename });
         //Device is a swich
         if ( a == 31 )
         {
            ret += get_device_path(path+filename+"main/" );
            ret += get_device_path(path+filename+"aux/" );
         } 
      } 
   }
   return ret; 
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
      if( !has_suffix( configuration->sensor, "/" ) )
         configuration->sensor = configuration->sensor+"/";
      string catch_err = catch {
         low_type = OWFS->read(configuration->sensor+"type") ;
      };
      if( catch_err )
      {
         logerror("OWFS: Sensor %s not found at %s\n",sensor_prop->name,configuration->sensor);
         sensor_var->online = 0;
         return;
      }
      switch ( low_type )
      {
         case "DS2413":
         case "DS2450":
            sensor_prop->sensor_type=SENSOR_INPUT|SENSOR_OUTPUT;
         break; 
         case "DS2502":
         case "DS1820":
         case "DS18B20":
            sensor_var->temperature = 0.0;
            sensor_prop->sensor_type=SENSOR_INPUT;
         break;
      }
      getnew();
   }

   void getnew()
   {
      string low_type = "";
      string catch_err = catch {
         low_type = OWFS->read(configuration->sensor+"type") ;
      };
      if( catch_err )
      {
         logerror("Sensor %s not found\n",name);
         sensor_var->online = 0;
         return;
      }
      switch ( low_type )
      {
         case "DS2450":
         if ( configuration->type = "currentcost" )
         {
            sensor_var->VOLTA = (float)  OWFS->read(configuration->sensor+"volt.A");

            sensor_var->VOLTB = (float)  OWFS->read(configuration->sensor+"volt.B");
            sensor_var->VOLTC = (float)  OWFS->read(configuration->sensor+"volt.C");
            sensor_var->VOLTD = (float)  OWFS->read(configuration->sensor+"volt.D");
            sensor_var->powerA= (sensor_var->VOLTA-0.14) / 2E-4;
            sensor_var->powerB= (sensor_var->VOLTB-0.14) / 2E-4;
            sensor_var->powerC= (sensor_var->VOLTC-0.14) / 2E-4;
            sensor_var->powerD= (sensor_var->VOLTD-0.14) / 2E-4;
            sensor_var->VOLT2A = (float)  OWFS->read(configuration->sensor+"volt2.A");
            sensor_var->VOLT2B = (float)  OWFS->read(configuration->sensor+"volt2.B");
            sensor_var->VOLT2C = (float)  OWFS->read(configuration->sensor+"volt2.C");
            sensor_var->VOLT2D = (float)  OWFS->read(configuration->sensor+"volt2.D");
         }
         else
         {
            sensor_var->PIOA = (int)  OWFS->read(configuration->sensor+"PIO.A");
            sensor_var->PIOB = (int)  OWFS->read(configuration->sensor+"PIO.B");
            sensor_var->PIOC = (int)  OWFS->read(configuration->sensor+"PIO.C");
            sensor_var->PIOD = (int)  OWFS->read(configuration->sensor+"PIO.D");
            sensor_var->VOLTA = (float)  OWFS->read(configuration->sensor+"volt.A");
            sensor_var->VOLTB = (float)  OWFS->read(configuration->sensor+"volt.B");
            sensor_var->VOLTC = (float)  OWFS->read(configuration->sensor+"volt.C");
            sensor_var->VOLTD = (float)  OWFS->read(configuration->sensor+"volt.D");
            sensor_var->VOLT2A = (float)  OWFS->read(configuration->sensor+"volt2.A");
            sensor_var->VOLT2B = (float)  OWFS->read(configuration->sensor+"volt2.B");
            sensor_var->VOLT2C = (float)  OWFS->read(configuration->sensor+"volt2.C");
            sensor_var->VOLT2D = (float)  OWFS->read(configuration->sensor+"volt2.D");
         }
         break;
         case "DS2413":
         catch {
            sensor_var->PIOA = (int)  OWFS->read(configuration->sensor+"PIO.A");
            sensor_var->PIOB = (int)  OWFS->read(configuration->sensor+"PIO.B");
         };
         break; 
         case "DS2502":
            if( configuration->type == "vbus" )
               get_vbus();
            if ( configuration->type == "slimmemeter" )
               get_slimmemeter();
            break;
         case "DS1820":
         case "DS18B20":
            sensor_var->temperature = (float) OWFS->read(configuration->sensor+"temperature") + (float) configuration->bias;
            break;
      }
   } 
  
   void get_vbus()
   {
      string data = OWFS->read(configuration->sensor+"memory");
      if(!sizeof(data) )
         return;
      sensor_var->collector = (float) (data[3] + (data[4]<<8)) / 10;
      sensor_var->boiler = (float) (data[5] + (data[6]<<8)) / 10 ;
      sensor_var->pump = (int) data[11] ;
      //sensor_var->state = (int) data[25] ;
   }

   void get_slimmemeter()
   {
      string data = OWFS->read(configuration->sensor+"memory");
      if(!sizeof(data) )
         return;
      sensor_var->T1_in = data[4]*10000+data[5]*1000+data[6]*100+data[7]*10+data[8];
      sensor_var->T2_in = data[20]*10000+data[21]*1000+data[22]*100+data[23]*10+data[24];
      sensor_var->T1_out = data[36]*10000+data[37]*1000+data[38]*100+data[39]*10+data[40];
      sensor_var->T2_out = data[52]*10000+data[53]*1000+data[54]*100+data[55]*10+data[56];
      sensor_var->power_in = (float) (data[68]*1000+data[69]*100+data[70]*10+data[71] + (float) data[73]/10 + (float) data[74]/100 + (float) data[75]/1000);
      sensor_var->power_out = (float) (data[84]*1000+data[85]*100+data[86]*10+data[87] + (float) data[89]/10 + (float) data[90]/100 + (float) data[91]/1000);
      sensor_var->power = sensor_var->power_in-sensor_var->power_out;
      sensor_var->gas = (float) (data[100]*10000+data[101]*1000+data[102]*100+data[103]*10+data[104] + (float) data[106]/10 + (float) data[107]/100 + (float) data[108]/1000);
      sensor_var->kWh_in = (int) (sensor_var->T1_in + sensor_var->T2_in);
      sensor_var->kWh_out = (int) (sensor_var->T1_out + sensor_var->T2_out);
   }
 
}

