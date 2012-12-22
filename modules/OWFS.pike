#include <module.h>
#include <sensor.h>
#include <variable.h>

inherit Module;

int module_type = MODULE_SENSOR;

object OWFS;

constant ModuleParameters = ({
                   ({ "port",PARAM_STRING,"/dev/ttyUSB0","TTY Port of the USB Stick", POPT_RELOAD }),
		   ({ "debug",PARAM_BOOLEAN,0,"Turn On / Off Debugging",POPT_NONE }),

                  });

/* Sensor Specific Variable */
constant SensorBaseParameters = ({
                   ({ "type",PARAM_STRING,"","Special Type Definition", 0 }),
                    });



void init() 
{
   logdebug("Init Module %s\n",ModuleProperties->name);
   OWFS = Public.IO.OWFS( configuration->port );
   init_sensors(configuration->sensor + ({}) );
}

array find_sensors()
{
   array ret = ({});
   array device_path = get_device_path("/");
   foreach( device_path, string path )
   {
      array var = SensorBaseParameters;
      var+= ({ ({ "name",PARAM_STRING,"default","Name"})});
      ret += ({ ([ "sensor":path,"module":ModuleProperties->name,"parameters":var ]) });
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

   mapping SensorProperties = ([
                                    "module":"",
                                    "name":"",
                                    "init":0,
                                   ]);
   protected string OWFSread( string sensor )
   {
      string answer;
      string catch_err = catch {
         answer = OWFS->read(sensor) ;
      };
      if( catch_err )
      {
         logerror("OWFS: Sensor %s not found at %s\n",SensorProperties->name,sensor);
         return UNDEFINED;
      }
      return answer;
   }

   protected void OWFSwrite( string sensor, string|int value)
   {
      string catch_err = catch {
         OWFS->write(sensor,value) ;
      };
      if( catch_err )
      {
         logerror("OWFS: Sensor %s not found at %s\n",SensorProperties->name,sensor);
         return;
      }
   }

   void sensor_init()
   {
      string low_type = "";
      if( !has_suffix( configuration->sensor, "/" ) )
         configuration->sensor = configuration->sensor+"/";
      low_type = OWFSread(configuration->sensor+"type");
      if( !low_type )
      {
         return;
      }
      switch ( low_type )
      {
         case "DS2450":
         if ( configuration->type = "currentcost" )
         {
            SensorProperties->sensor_type=SENSOR_INPUT;
            ValueCache->VOLTA= ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);

            ValueCache->VOLTB = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLTC = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLTD = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->powerA= ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->powerC= ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->powerD= ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLT2A = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLT2B = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLT2C = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLT2D = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
         }
         else
         {
            SensorProperties->sensor_type=SENSOR_INPUT|SENSOR_OUTPUT;
            ValueCache->PIOA = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
            ValueCache->PIOB = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
            ValueCache->PIOC = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
            ValueCache->PIOD = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
            ValueCache->VOLTA = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLTB = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLTC = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLTD = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLT2A = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLT2B = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLT2C = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            ValueCache->VOLT2D = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
         }
         break;
         case "DS2408":
         SensorProperties->sensor_type=SENSOR_INPUT|SENSOR_OUTPUT;
         ValueCache->PIOA = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]); 
         ValueCache->PIOB = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
         ValueCache->PIOC = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
         ValueCache->PIOD = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
         ValueCache->PIOE = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
         ValueCache->PIOF = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
         ValueCache->PIOG = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
         ValueCache->PIOH = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
         ValueCache->SENSEDA = ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
         ValueCache->SENSEDB = ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
         ValueCache->SENSEDC = ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
         ValueCache->SENSEDD = ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
         ValueCache->SENSEDE = ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
         ValueCache->SENSEDF = ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]); 
         break;
         case "DS2413":
         SensorProperties->sensor_type=SENSOR_INPUT|SENSOR_OUTPUT;
         ValueCache->PIOA = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
         ValueCache->PIOB = ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
         ValueCache->SENSEDA = ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
         ValueCache->SENSEDB = ([ "value":0, "direction":DIR_RO, "type":VAR_BOOLEAN ]);
         break; 
         case "DS2502":
            if( configuration->type == "vbus" )
            {
               SensorProperties->sensor_type=SENSOR_INPUT;
               ValueCache->collector = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
               ValueCache->boiler = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
               ValueCache->pump = ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
            }
            else if ( configuration->type == "slimmemeter" )
            {
               SensorProperties->sensor_type=SENSOR_INPUT;
               ValueCache->T1_in = ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
               ValueCache->T2_in = ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
               ValueCache->T1_out = ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
               ValueCache->T2_out = ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
               ValueCache->power_in = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
               ValueCache->power_out = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
               ValueCache->power = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
               ValueCache->gas = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
               ValueCache->kWh_in = ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
               ValueCache->kWh_out = ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
            }
            break;
         case "DS1820":
         case "DS18B20":
            SensorProperties->sensor_type=SENSOR_INPUT;
            ValueCache->temperature = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            break;
         case "DS2438":
            SensorProperties->sensor_type=SENSOR_INPUT;
            if( configuration->type == "CO2" )
            {
               ValueCache->concentration = ([ "value":0, "direction":DIR_RO, "type":VAR_INT ]);
               ValueCache->vis = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
            }
            else
            {
               ValueCache->VDD = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
               ValueCache->VAD = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
               ValueCache->vis = ([ "value":0.0, "direction":DIR_RO, "type":VAR_FLOAT ]);
             }
         
         break;
      }
      SensorProperties.init = 1;
      UpdateSensor();
   }

   mapping write( mapping what )
   {
      if ( SensorProperties.init == 0 )
         sensor_init();
      if ( SensorProperties.init == 0 )
         return ([]);
 
      string low_type = "";
      if( !has_suffix( configuration->sensor, "/" ) )
         configuration->sensor = configuration->sensor+"/";
      low_type = OWFSread(configuration->sensor+"type") ;
      if( !low_type )
         return ([]);
      switch ( low_type )
      {

         case "DS2413":
            if( has_index( what, "PIOA" ) )
               OWFSwrite(configuration->sensor+"PIO.A", (int) what->PIOA);
            if( has_index( what, "PIOB" ) )
               OWFSwrite(configuration->sensor+"PIO.B",(int) what->PIOB );
         break;
         case "DS2408":
            if( has_index( what, "PIOA" ) )
               OWFSwrite(configuration->sensor+"PIO.0", (int) what->PIOA);
            if( has_index( what, "PIOB" ) )
               OWFSwrite(configuration->sensor+"PIO.1",(int) what->PIOB );
            if( has_index( what, "PIOC" ) )
               OWFSwrite(configuration->sensor+"PIO.2",(int) what->PIOC );
            if( has_index( what, "PIOD" ) )
               OWFSwrite(configuration->sensor+"PIO.3",(int) what->PIOD );
            if( has_index( what, "PIOE" ) )
               OWFSwrite(configuration->sensor+"PIO.4",(int) what->PIOE );
            if( has_index( what, "PIOF" ) )
               OWFSwrite(configuration->sensor+"PIO.5",(int) what->PIOF );
            if( has_index( what, "PIOG" ) )
               OWFSwrite(configuration->sensor+"PIO.6",(int) what->PIOG );
            if( has_index( what, "PIOH" ) )
               OWFSwrite(configuration->sensor+"PIO.7",(int) what->PIOH );
         break;
      }
      UpdateSensor();
      return (mapping) ValueCache;   
   }

   void UpdateSensor()
   {
      if ( SensorProperties.init == 0 )
      {
         sensor_init();
         return;
      }
      string low_type = "";
      low_type = OWFSread(configuration->sensor+"type") ;
      if( !low_type )
         return;
      switch ( low_type )
      {
         case "DS2450":
         if ( configuration->type = "currentcost" )
         {
            ValueCache->VOLTA = (float)  OWFSread(configuration->sensor+"volt.A");

            ValueCache->VOLTB = (float)  OWFSread(configuration->sensor+"volt.B");
            ValueCache->VOLTC = (float)  OWFSread(configuration->sensor+"volt.C");
            ValueCache->VOLTD = (float)  OWFSread(configuration->sensor+"volt.D");
            ValueCache->powerA= (ValueCache->VOLTA-0.14) / 3E-4;
            ValueCache->powerB= (ValueCache->VOLTB-0.14) / 3E-4;
            ValueCache->powerC= (ValueCache->VOLTC-0.14) / 3E-4;
            ValueCache->powerD= (ValueCache->VOLTD-0.14) / 3E-4;
            ValueCache->VOLT2A = (float)  OWFSread(configuration->sensor+"volt2.A");
            ValueCache->VOLT2B = (float)  OWFSread(configuration->sensor+"volt2.B");
            ValueCache->VOLT2C = (float)  OWFSread(configuration->sensor+"volt2.C");
            ValueCache->VOLT2D = (float)  OWFSread(configuration->sensor+"volt2.D");
         }
         else
         {
            ValueCache->PIOA = (int)  OWFSread(configuration->sensor+"PIO.A");
            ValueCache->PIOB = (int)  OWFSread(configuration->sensor+"PIO.B");
            ValueCache->PIOC = (int)  OWFSread(configuration->sensor+"PIO.C");
            ValueCache->PIOD = (int)  OWFSread(configuration->sensor+"PIO.D");
            ValueCache->VOLTA = (float)  OWFSread(configuration->sensor+"volt.A");
            ValueCache->VOLTB = (float)  OWFSread(configuration->sensor+"volt.B");
            ValueCache->VOLTC = (float)  OWFSread(configuration->sensor+"volt.C");
            ValueCache->VOLTD = (float)  OWFSread(configuration->sensor+"volt.D");
            ValueCache->VOLT2A = (float)  OWFSread(configuration->sensor+"volt2.A");
            ValueCache->VOLT2B = (float)  OWFSread(configuration->sensor+"volt2.B");
            ValueCache->VOLT2C = (float)  OWFSread(configuration->sensor+"volt2.C");
            ValueCache->VOLT2D = (float)  OWFSread(configuration->sensor+"volt2.D");
         }
         break;
         case "DS2408":
            ValueCache->PIOA = (int)  OWFSread(configuration->sensor+"PIO.0");
            ValueCache->PIOB = (int)  OWFSread(configuration->sensor+"PIO.1");
            ValueCache->PIOC = (int)  OWFSread(configuration->sensor+"PIO.2");
            ValueCache->PIOD = (int)  OWFSread(configuration->sensor+"PIO.3");
            ValueCache->PIOE = (int)  OWFSread(configuration->sensor+"PIO.4");
            ValueCache->PIOF = (int)  OWFSread(configuration->sensor+"PIO.5");
            ValueCache->PIOG = (int)  OWFSread(configuration->sensor+"PIO.6");
            ValueCache->PIOH = (int)  OWFSread(configuration->sensor+"PIO.7");
            ValueCache->SENSEDA = (int)  OWFSread(configuration->sensor+"sensed.0");
            ValueCache->SENSEDB = (int)  OWFSread(configuration->sensor+"sensed.1");
            ValueCache->SENSEDC = (int)  OWFSread(configuration->sensor+"sensed.2");
            ValueCache->SENSEDD = (int)  OWFSread(configuration->sensor+"sensed.3");
            ValueCache->SENSEDE = (int)  OWFSread(configuration->sensor+"sensed.4");
            ValueCache->SENSEDF = (int)  OWFSread(configuration->sensor+"sensed.5");
         break;
         case "DS2413":
            ValueCache->PIOA = (int)  OWFSread(configuration->sensor+"PIO.A");
            ValueCache->PIOB = (int)  OWFSread(configuration->sensor+"PIO.B");
            ValueCache->SENSEDA = (int)  OWFSread(configuration->sensor+"SENSED.A");
            ValueCache->SENSEDB = (int)  OWFSread(configuration->sensor+"SENSED.B");
         break; 
         case "DS2502":
            if( configuration->type == "vbus" )
               get_vbus();
            if ( configuration->type == "slimmemeter" )
               get_slimmemeter();
            break;
         case "DS1820":
         case "DS18B20":
            ValueCache->temperature = (float) OWFSread(configuration->sensor+"temperature") + (float) configuration->bias;
            break;
         case "DS2438":
            if( configuration->type == "CO2" )
            {
               int concentration = (int)  ((float) OWFSread(configuration->sensor+"VAD")*1000.00);
               //Check if the sensor needs a reset?
               if ( concentration >= 4400 )
               {
                  logdebug("CO2 Sensor %s Needs reset\n",SensorProperties->name);
                  switchboard(SensorProperties->name, configuration->reset, COM_WRITE, (["value":1]) );
                  call_out( switchboard, 20, SensorProperties->name,configuration->reset, COM_WRITE, ([ "value":0]) );
               }
               ValueCache->concentration = concentration; 
               ValueCache->vis = (float)  OWFSread(configuration->sensor+"vis");
            }
            else
            {
               ValueCache->VDD = (float)  OWFSread(configuration->sensor+"VDD");
               ValueCache->VAD = (float)  OWFSread(configuration->sensor+"VAD");
               ValueCache->vis = (float)  OWFSread(configuration->sensor+"vis");
             }
         
         break;
      }
   } 
  
   void get_vbus()
   {
      string data = OWFSread(configuration->sensor+"memory");
      if(!data || !sizeof(data) )
         return;
      int collector = (data[3] + (data[4]<<8));
      //The collector can return negative values.
      if( collector >= (1 << 15) )
      {
         collector = collector - (1<<16);
      }
      ValueCache->collector = (float) collector / 10.00;
      //The Boiler temperature (hopefully) never gets below 0 degrees.
      ValueCache->boiler = (float) (data[5] + (data[6]<<8)) / 10 ;
      ValueCache->pump = (int) data[11] ;
      //ValueCache->state = (int) data[25] ;
   }

   void get_slimmemeter()
   {
      string data = OWFSread(configuration->sensor+"memory");
      if( !data || !sizeof(data) )
         return;
      ValueCache->T1_in = data[4]*10000+data[5]*1000+data[6]*100+data[7]*10+data[8];
      ValueCache->T2_in = data[20]*10000+data[21]*1000+data[22]*100+data[23]*10+data[24];
      ValueCache->T1_out = data[36]*10000+data[37]*1000+data[38]*100+data[39]*10+data[40];
      ValueCache->T2_out = data[52]*10000+data[53]*1000+data[54]*100+data[55]*10+data[56];
      ValueCache->power_in = (float) (data[68]*1000+data[69]*100+data[70]*10+data[71] + (float) data[73]/10 + (float) data[74]/100 + (float) data[75]/1000);
      ValueCache->power_out = (float) (data[84]*1000+data[85]*100+data[86]*10+data[87] + (float) data[89]/10 + (float) data[90]/100 + (float) data[91]/1000);
      ValueCache->power = ValueCache->power_in-ValueCache->power_out;
      ValueCache->gas = (float) (data[100]*10000+data[101]*1000+data[102]*100+data[103]*10+data[104] + (float) data[106]/10 + (float) data[107]/100 + (float) data[108]/1000);
      ValueCache->kWh_in = (int) (ValueCache->T1_in + ValueCache->T2_in);
      ValueCache->kWh_out = (int) (ValueCache->T1_out + ValueCache->T2_out);
   }
 
}

