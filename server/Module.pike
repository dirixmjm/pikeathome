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
   module_init();
}

void module_init()
{
#ifdef DEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"Init Module %s\n",module_name);
#endif
   if( (module_type & MODULE_SENSOR) && has_index(configuration,"sensor") )
   {
      array load_sensors = arrayp(configuration->sensor)?configuration->sensor:({configuration->sensor});
      foreach(load_sensors, string name )
      {
         sensors+= ([ name: sensor( name, domotica ) ]);
      }
   }
}

//Expect either to receive a mapping (["key":value,...) 
mapping write( mapping what)
{
}

array getvar()
{
   array ret = ({});
   foreach(defvar, array var)
      ret+= ({ var + ({ configuration[var[0]] })});
   return ret;
}

array setvar( mapping params )
{
   int mod_reload = 0;
   foreach(defvar, array option)
   {
      if( has_value( params, option[0] ) )
      {
         configuration[option[0]]=params[option[0]];
         if( option[4] == POPT_MODRELOAD )
            mod_reload = 1;
      }
   }
   reload();
}

class sensor
{
inherit Sensor;

}

void reload()
{
   foreach(values(sensors),object sensor)
      sensor->close();
   module_init(); 
}

void close()
{
   foreach(values(sensors),object sensor)
      sensor->close();
   domotica = 0;
   configuration = 0;   
}
