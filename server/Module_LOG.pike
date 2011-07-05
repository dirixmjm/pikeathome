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
   foreach(defvar, array var)
      ret+= ({var + ({ configuration[var[0]] })});
   return ret;
}

array setvar( mapping params )
{
   int mod_reload = 0;
   foreach(defvar, array option)
   {
      if( has_value( params, option[0] ))
      {
         configuration[option[0]]=params[option[0]];
         if( option[4] == POPT_MODRELOAD )
            mod_reload = 1;
      }
   }
   reload();
}


void reload()
{
   module_init();
}
void close()
{

}
