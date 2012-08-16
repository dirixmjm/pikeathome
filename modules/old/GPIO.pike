#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "GPIO";

class sensor()
{
   inherit Sensor;

   int sensor_type = SENSOR_INPUT | SENSOR_OUTPUT;    

   protected mapping sensor_var = ([
                               "module":"GPIO",
                               "name":"",
                               "sensor_type":sensor_type,
                               "online":1
                               ]);

   void sensor_init( )
   {
      // Check if the GPIO Pin is exported
      if( !Stdio.is_dir( "/sys/class/gpio/gpio"+configuration->address ) )
      {
         Stdio.File exp = Stdio.File("/sys/class/gpio/export","w");
         exp->write(address);
         exp->close();
      }
      Stdio.File dir =  Stdio.File("/sys/class/gpio/gpio"+address+"/direction","w");
      dir->write(configuration->direction);
      dir->close();
   }

   void getnew()
   {
         Stdio.File sensor = Stdio.File("/sys/class/gpio/gpio"+configuration->address+"/value","R");
         sscanf(sensor->read(),"%d\n",a->state);
         sensor->close();
   }

   midex write ( string variable, mixed value )
   {
      Stdio.File sensor = Stdio.File("/sys/class/gpio/gpio"+configuration->address+"/value","W");
      if( variable=="state")
         sensor->write( "%d\n",(int) value );
      sensor->close();
   }
 
}

