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

void create( string name, object _module, object _configuration )
{
   //FIXME Dynamically set module name? Should this be a create argument?
   module = _module;
   configuration = _configuration;
   sensor_name = name;
   sensor_var->name = name;
   sensor_var->sensor_type = sensor_type;
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
mapping info( int|void new )
{
   if ( new )
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

void rpc( string module_sensor_value, int command, mapping parameters, function callback, mixed ... callback_args)
{
   array split = module->split_module_sensor_value(module_sensor_value);
   switch(command)
   {
      case COM_INFO:
      {
      //FIXME This should also be a callback (and backends callback driven)
      if( sizeof(split) > 2 )
         //FIXME Error if variable does not exist?
         call_out(callback, 0, info( parameters->new )[split[2]],@callback_args );
      else
         call_out(callback, 0, info( parameters->new ),@callback_args );
      }
      break;
      case COM_WRITE:
      {
         if( sizeof( split ) > 2  )
            call_out( callback, 0 , write( ([ split[2]:parameters->values ]) ), @callback_args );
         else if ( mappingp(parameters->values ) )
            call_out( callback, 0 , write( parameters->values ), @callback_args );
         else
            call_out( callback, 0 , (["error": sprintf("Unknown values format %O\n",parameters->values)]), @callback_args );
      }
      default:
         call_out(callback, 0, (["error":"Unknown Command"]),@callback_args );
   }
}


