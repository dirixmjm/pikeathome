#include <sensor.h>
#include <parameters.h>
#include <command.h>

int sensor_type = 0; 

protected object configuration;
object module;
array defvar = ({});


string sensor_name = "";
protected mapping sensor_var = ([
                               "module":"",
                               "name":"",
                               "sensor_type":sensor_type
                               ]);

protected mapping sensor_prop = ([
                               "module":"",
                               "name":"",
                               "sensor_type":sensor_type
                               ]);

void create( string name, object _module, object _configuration )
{
   module = _module;
   configuration = _configuration;
   sensor_name = name;
   sensor_prop->module = _module->name;
   sensor_prop->name = name;
   sensor_prop->sensor_type = sensor_type;
   sensor_init();
}

void sensor_init()
{
}

/* Each sensor with type=SENSOR_INPUT should implement a write function.
 * The write function takes a variable-name, and
 * the value which is to written to the variable.
 */
mixed write( mapping what )
{
}

/* 
 * Info returns the last seen sensor input and output values 
 * in a mapping.
 */
mapping info( )
{

   getnew();
   return  sensor_var;
}


/* Each sensor should implement this function. 
 * getnew() queries the sensor for new values, and 
 * updates sensor_var.
 */

void getnew()
{
}

mapping property()
{
   return sensor_prop;
}


array getvar()
{
   array ret = ({});
   foreach(module->sensvar, array var)
      ret+= ({ var + ({ configuration[var[0]] })});
   return ret;
}

void setvar( mapping params )
{
   int mod_options = 0;
   foreach(module->sensvar, array option)
   {
      //Find the parameter, and always set it
      if( has_index( params, option[0] ) )
      {
         configuration[option[0]]=params[option[0]];
      }
   }
}

void close()
{
   destruct(this);
}



void got_answer(mixed params )
{

}

void rpc_command( string sender, string receiver, int command, mapping parameters )
{
   if( command < 0 )
   {
      got_answer(parameters);
      return;
   }
   array split = module->split_server_module_sensor_value(receiver);
   switch(command)
   {
      case COM_READ:
      {
         if ( sizeof(split) == 3 )
            switchboard(receiver, sender, -command, info( ) );
         else if ( sizeof(split) == 4 && has_index( sensor_var, split[3] ) )
            switchboard(receiver, sender, -command, info( )[split[3]]);
         else
            switchboard(receiver, sender, COM_ERROR, ([ "error":
                             sprintf( "Variable not found %s",receiver) ]) );
      }
      break;
      case COM_PARAM:
      {
         if( parameters && mappingp(parameters) )
            setvar(parameters);
         switchboard( receiver,sender, -command, getvar() );
      }
      break;
      case COM_PROP:
      {
         switchboard(receiver, sender, -command, property( ) );
      }
      break;
      case COM_WRITE:
      {
         if ( ! parameters || !mappingp(parameters) )
         {
            switchboard(receiver, sender, COM_ERROR, ([ "error":
                             sprintf( "Bad parameters for %s",receiver) ]) );
            return;
         }
         if ( sizeof(split) == 3 && parameters && mappingp(parameters) )
            switchboard(receiver, sender, -command,write( parameters ));
         else if ( sizeof(split) == 4 && has_index( sensor_var, split[3] ) )
             switchboard(receiver, sender, -command, write( ([ split[3]:parameters->value ]) ));
         else
            switchboard(receiver, sender, COM_ERROR, ([ "error":
                             sprintf( "Variable not found %s",receiver) ]) );

      }
      break;
      case COM_ERROR:
         logerror(parameters->error);
      break;
      default:
         switchboard(receiver, sender, COM_ERROR, (["error":"Unknown Command"]));
   }
}

/*
* Helper Function for sensors to call the switchboard
*/
void switchboard ( mixed ... args )
{
   module->switchboard( @args );
}

void logdebug(mixed ... args)
{
   module->logdebug(@args);
}

void logerror(mixed ... args)
{
   module->logerror(@args);
}

void logdata(mixed ... args )
{
   module->logdata(@args);
}
