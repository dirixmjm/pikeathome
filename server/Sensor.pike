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
   //FIXME Dynamically set module name? Should this be a create argument?
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
 * If "new" is given, the sensor must be queried for new values.
 */
mapping info( )
{

   getnew();
   return  sensor_var;
}

mapping property()
{
   return sensor_prop;
}

/* Each sensor should implement this function. 
 * getnew() queries the sensor for new values, and 
 * updates sensor_var.
 */

void getnew()
{
}


array getvar()
{
   array ret = ({});
   foreach(module->sensvar, array var)
      ret+= ({ var + ({ configuration[var[0]] })});
   return ret;
}

void close()
{
   destruct(this);
}


void logdebug(mixed ... args )
{
   module->logdebug(@args);
}
void logerror(mixed ... args )
{
   module->logerror(@args);
}
void logdata(mixed ... args )
{
   module->logdata(@args);
}

void got_answer(mixed params )
{

}

array setvar( mapping params )
{
   int mod_options = 0;
   //FIXME check if the parameter is defined?
   //FIXME parameter options, like reload?
   foreach( indices(params), string param )
   {
      configuration[param]=params[param];
   }
}

void rpc_command( string sender, string receiver, int command, mapping parameters, function callback, mixed ... callback_args)
{
   array split = module->split_server_module_sensor_value(receiver);
   switch(command)
   {
      case COM_ANSWER:
        got_answer(parameters);
      break;
      case COM_INFO:
      {
      //FIXME This should also be a callback (and backends callback driven)
      //And create a buffer of callers, in order to de-multiplex?
      if( sizeof(split) == 4 )
         //FIXME Error if variable does not exist?
         switchboard(receiver, sender, COM_ANSWER, info( )[split[3]]);
      else
         switchboard(receiver, sender, COM_ANSWER, info( ) );
      }
      break;
      case COM_PROP:
      {
      //FIXME This should also be a callback (and backends callback driven)
      //And create a buffer of callers, in order to de-multiplex?
      if( sizeof(split) == 4 )
         //FIXME Error if variable does not exist?
         switchboard(receiver, sender, COM_ANSWER, property( )[split[3]]);
      else
         switchboard(receiver, sender, COM_ANSWER, property( ) );
      }
      break;
      case COM_WRITE:
      {
         if( sizeof( split ) == 4  )
            switchboard(receiver, sender, COM_ANSWER, write( ([ split[3]:parameters->value ]) ), @callback_args );
         else if ( mappingp(parameters->values ) )
            switchboard(receiver, sender, COM_ANSWER,write( parameters->values ), @callback_args );
         else
            switchboard(receiver, sender, COM_ERROR, (["error": sprintf("Unknown values format %O\n",parameters->values)]), @callback_args );
      }
      break;
      case COM_PARAM:
      if( parameters && sizeof( parameters ) > 0 )
         setvar(parameters);
         switchboard( receiver,sender, COM_ANSWER, getvar() );
      break;
      case COM_ERROR:
         logerror("%s received error %O\n",receiver,parameters->error);
      break;
      default:
         switchboard(receiver, sender, COM_ERROR, (["error":"Unknown Command"]),@callback_args );
   }
}

/*
* Helper Function for sensors to call the switchboard
*/
void switchboard ( mixed ... args )
{
   module->switchboard( @args );
}

