#include <module.h>

protected object configuration;
object domotica;

int module_type = MODULE_LOG;
string module_name = "module";
array defvar = ({});

void create( object domo )
{
   domotica = domo;
   configuration = domotica->configuration(module_name);
#ifdef DEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"Init Module %s\n",module_name);
#endif
   module_init();
}

void module_init()
{
}

void log_data( string module,string name, mapping data )
{

}

void log_event( int level, string name, string format, mixed ... args )
{

}

array getvar()
{
   array ret = ({});
   foreach( defvar, array vars )
   {
      ret += ({ ([
               "name":vars[0],
               "type":vars[1],
               "default":vars[2],
               "description":vars[3],
               "value":configuration[vars[0]]
              ]) });
   }
   return ret;
}

void close()
{

}
