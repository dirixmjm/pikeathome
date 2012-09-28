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
   logdebug("Init Module %s\n",name);
   OWFS = Public.IO.OWFS( configuration->port );
   init_sensors(configuration->sensor + ({}) );
}

array find_sensors()
{
   array ret = ({});
   array device_path = get_device_path("/");
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
         case "DS2408":
            sensor_prop->sensor_type=SENSOR_INPUT|SENSOR_OUTPUT;
         break; 
         case "DS2502":
         case "DS1820":
         case "DS18B20":
            sensor_var->temperature = 0.0;
            sensor_prop->sensor_type=SENSOR_INPUT;
         break;
         case "DS2438":
            sensor_prop->sensor_type=SENSOR_INPUT;
         break;
      }
      getnew();
   }

   mapping write( mapping what )
   {
      string low_type = "";
      if( !has_suffix( configuration->sensor, "/" ) )
         configuration->sensor = configuration->sensor+"/";
      string catch_err = catch {
         low_type = OWFS->read(configuration->sensor+"type") ;
      };
      switch ( low_type )
      {

         case "DS2413":
            if( has_index( what, "PIOA" ) )
               OWFS->write(configuration->sensor+"PIO.A", (int) what->PIOA);
            if( has_index( what, "PIOB" ) )
               OWFS->write(configuration->sensor+"PIO.B",(int) what->PIOB );
         break;
         case "DS2408":
            if( has_index( what, "PIOA" ) )
               OWFS->write(configuration->sensor+"PIO.0", (int) what->PIOA);
            if( has_index( what, "PIOB" ) )
               OWFS->write(configuration->sensor+"PIO.1",(int) what->PIOB );
            if( has_index( what, "PIOC" ) )
               OWFS->write(configuration->sensor+"PIO.2",(int) what->PIOC );
            if( has_index( what, "PIOD" ) )
               OWFS->write(configuration->sensor+"PIO.3",(int) what->PIOD );
            if( has_index( what, "PIOE" ) )
               OWFS->write(configuration->sensor+"PIO.4",(int) what->PIOE );
            if( has_index( what, "PIOF" ) )
               OWFS->write(configuration->sensor+"PIO.5",(int) what->PIOF );
            if( has_index( what, "PIOG" ) )
               OWFS->write(configuration->sensor+"PIO.6",(int) what->PIOG );
            if( has_index( what, "PIOH" ) )
               OWFS->write(configuration->sensor+"PIO.7",(int) what->PIOH );
         break;
      }
      getnew();
      return sensor_var;   
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
            sensor_var->powerA= (sensor_var->VOLTA-0.14) / 3E-4;
            sensor_var->powerB= (sensor_var->VOLTB-0.14) / 3E-4;
            sensor_var->powerC= (sensor_var->VOLTC-0.14) / 3E-4;
            sensor_var->powerD= (sensor_var->VOLTD-0.14) / 3E-4;
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
         case "DS2408":
         catch {
            sensor_var->PIOA = (int)  OWFS->read(configuration->sensor+"PIO.0");
            sensor_var->PIOB = (int)  OWFS->read(configuration->sensor+"PIO.1");
            sensor_var->PIOC = (int)  OWFS->read(configuration->sensor+"PIO.2");
            sensor_var->PIOD = (int)  OWFS->read(configuration->sensor+"PIO.3");
            sensor_var->PIOE = (int)  OWFS->read(configuration->sensor+"PIO.4");
            sensor_var->PIOF = (int)  OWFS->read(configuration->sensor+"PIO.5");
            sensor_var->PIOG = (int)  OWFS->read(configuration->sensor+"PIO.6");
            sensor_var->PIOH = (int)  OWFS->read(configuration->sensor+"PIO.7");
            sensor_var->SENSEDA = (int)  OWFS->read(configuration->sensor+"SENSED.0");
            sensor_var->SENSEDB = (int)  OWFS->read(configuration->sensor+"SENSED.1");
            sensor_var->SENSEDC = (int)  OWFS->read(configuration->sensor+"SENSED.2");
            sensor_var->SENSEDD = (int)  OWFS->read(configuration->sensor+"SENSED.3");
            sensor_var->SENSEDE = (int)  OWFS->read(configuration->sensor+"SENSED.4");
            sensor_var->SENSEDF = (int)  OWFS->read(configuration->sensor+"SENSED.5");
         };
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
         case "DS2438":
            if( configuration->type == "CO2" )
            {
               int concentration = (int)  ((float) OWFS->read(configuration->sensor+"VAD")*1000.00);
               //Check if the sensor needs a reset?
               if ( concentration >= 4400 )
               {
                  logdebug("CO2 Sensor %s Needs reset\n",sensor_prop->name);
                  switchboard(sensor_prop->name, configuration->reset, COM_WRITE, 1 );
                  call_out( switchboard, 20, sensor_prop->name,configuration->reset, COM_WRITE, 0 );
               }
               sensor_var->concentration = concentration; 
               sensor_var->vis = (float)  OWFS->read(configuration->sensor+"vis");
            }
            else
            {
               sensor_var->VDD = (float)  OWFS->read(configuration->sensor+"VDD");
               sensor_var->VAD = (float)  OWFS->read(configuration->sensor+"VAD");
               sensor_var->vis = (float)  OWFS->read(configuration->sensor+"vis");
             }
         
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

