#include <module.h>
#include <parameters.h>
#include <command.h>

inherit Base_func;

protected object configuration;
object domotica;

int module_type = 0;

string name = "module";
array defvar = ({});

void create( string _name, object domo )
{
   domotica = domo;
   name=_name;

   configuration = domotica->configuration(name);
#ifdef DEBUG
   logdebug("Init Module %s\n",name);
#endif
}

void init()
{
}

void log_data( string name, string|int data, int|void tstamp )
{
}

mapping retr_data( string name, int|void start, int|void end)
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

void setvar( mapping params )
{
   int mod_options = 0;
   foreach(defvar, array option)
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
   init();
}
void close()
{

}

void rpc_command( string sender, string receiver, int command, mapping parameters )
{
   array split = split_server_module_sensor_value(receiver);
   switch(command)
   {
      case COM_LOGDATA:
      {
         log_data ( sender, parameters->data, has_index(parameters,"stamp")?parameters->stamp:UNDEFINED); 
      }
      break;
      case COM_RETRLOGDATA:
      {
         mapping ret = retr_data( parameters->name, parameters->start, parameters->end);
         switchboard( receiver,sender, -command, ret );
      }
      break;
      case COM_PARAM:
      {
         if ( parameters && mappingp(parameters) )
            setvar(parameters);
         switchboard( receiver,sender, -command, getvar() );
      }
      break;
      case COM_ERROR:
         logerror(parameters->error);
      break;
      default:
         switchboard( receiver,sender, COM_ERROR, ([ "error":sprintf("Module %s unknown command %d",receiver,command) ]) );
   }
}

void switchboard (mixed ... args )
{
   call_out( domotica->switchboard,0, @args );
}

void logdebug(mixed ... args)
{
   call_out(switchboard, 0, name, domotica->name, COM_LOGEVENT, ([ "level":LOG_DEBUG, "error":sprintf(@args) ]) );
}

void logerror(mixed ... args)
{
   call_out(switchboard, 0, name, domotica->name, COM_LOGEVENT, ([ "level":LOG_ERR, "error":sprintf(@args) ]) );

}
