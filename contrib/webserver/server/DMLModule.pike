#include <parameters.h>

protected object dml;
protected object configuration;
inherit Base_func;

mapping tags = ([
]);

mapping emit = ([
]);

mapping containers = ([
]);

constant ModuleParameters = ({});

void create( object dml_ , object Config)
{
   dml = dml_;
   configuration = Config;
}

array GetParameters()
{
   array ret = ({});
   foreach(ModuleParameters, array var)
      ret+= ({ var + ({ configuration[var[0]] })});
   return ret;
}

void SetParameters( mapping params )
{
   int mod_options = 0;
   foreach(ModuleParameters, array option)
   {
      //Find the parameter, and always set it
      if( has_index( params, option[0] ) )
      {
         configuration[option[0]]=params[option[0]];
         mod_options |= option[4];
      }
   }
   if( mod_options & POPT_RELOAD )
      reload();
}

void reload()
{
  
}

void logerror( mixed ... args )
{
   dml->logerror(@args);
}
