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
      // FIXME Should I check if there are gpio's on the system?
      if( !Stdio.is_dir( "/sys/class/gpio/gpio"+configuration->address ) )
      {
         Stdio.File exp = Stdio.File("/sys/class/gpio/export","w");
         exp->write(configuration->address);
         exp->close();
      }
      Stdio.File dir =  Stdio.File("/sys/class/gpio/gpio"+configuration->address+"/direction","w");
      dir->write(configuration->direction);
      dir->close();
   }

   void getnew()
   {
         Stdio.File sensor = Stdio.File("/sys/class/gpio/gpio"+configuration->address+"/value","R");
         sscanf(sensor->read(),"%d\n",sensor_var->state);
         sensor->close();
   }

   void write( string variable, mixed value )
   {
      //FIXME Check direction?
      Stdio.File sensor = Stdio.File("/sys/class/gpio/gpio"+configuration->address+"/value","W");
      if( variable=="state")
         sensor->write( "%d\n",(int) value );
      sensor->close();
   }
 
}

