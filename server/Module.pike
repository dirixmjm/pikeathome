#include <module.h>

protected object configuration;

object domotica;
int module_type = 0;
string module_name = "module";
mapping sensors=([]);

//defvar should contain arrays  ({ "name","type","default","description"})
array defvar = ({});



void create( object Domo )
{
   domotica = Domo;
   configuration = domotica->configuration(module_name);
#ifdef DEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"Init Module %s\n",module_name);
#endif
   module_init();
}

void module_init()
{
   if( (module_type & MODULE_SENSOR) && has_index(configuration,"sensor") )
   {
      array load_sensors = arrayp(configuration->sensor)?configuration->sensor:({configuration->sensor});
      foreach(load_sensors, string name )
      {
         sensors+= ([ name: sensor( name, domotica ) ]);
      }
   }
}

array getvar()
{
   array ret = ({});
   foreach( defvar, array vars )
   {
      ret += ({([
               "name":vars[0],
               "type":vars[1],
               "default":vars[2],
               "description":vars[3],
               "value":configuration[vars[0]]
              ])});
   }
   return ret;
}

//Expect either to receive a mapping (["key":value,...) 
mapping write( mapping what)
{
}


class sensor
{
inherit Sensor;

}

void close()
{
   foreach(values(sensors),object sensor)
      sensor->close();
   domotica = 0;
   configuration = 0;   

   
}
