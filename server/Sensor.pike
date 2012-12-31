#include <sensor.h>
#include <variable.h>
#include <parameters.h>
#include <command.h>

int sensor_type = 0; 

protected object configuration;
object module;

array SensorParameters = ({});


object ValueCache = VariableStorage();

mapping SensorProperties = ([
                               "module":"",
                               "name":"",
                               "sensor_type":sensor_type
                               ]);

void create( string name, object _module, object _configuration )
{
   module = _module;
   configuration = _configuration;
   SensorProperties->module = _module->ModuleProperties->name;
   SensorProperties->name = name;
   SensorProperties->sensor_type = sensor_type;
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

/* Each sensor should implement this function. 
 * UpdateSensor() queries the sensor for new values, and 
 * updates ValueCache.
 */

void UpdateSensor()
{
}

mapping property()
{
   return SensorProperties;
}


array GetParameters()
{
   array ret = ({});
   foreach(module->SensorBaseParameters, array var)
      ret+= ({ var + ({ configuration[var[0]] })});
   foreach(SensorParameters, array var)
      ret+= ({ var + ({ configuration[var[0]] })});
   return ret;
}

void SetParameters( mapping params )
{
   int mod_options = 0;
   foreach(module->SensorBaseParameters, array option)
   {
      //Find the parameter, and always set it
      if( has_index( params, option[0] ) )
      {
         configuration[option[0]]=params[option[0]];
      }
   }
   foreach(SensorParameters, array option)
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



void got_answer(int command, string name, mixed params )
{

}

void rpc_command( string sender, string receiver, int command, mapping parameters )
{
   if( command < 0 )
   {
      got_answer(command, sender, parameters);
      return;
   }
   array split = module->split_server_module_sensor_value(receiver);
   switch(command)
   {
      case COM_READ:
      {
         UpdateSensor();
         if ( sizeof(split) == 3 )
            switchboard(receiver, sender, -command, (mapping) ValueCache );
         else if ( sizeof(split) == 4 && has_index( ValueCache, split[3] ) )
         {
            switchboard(receiver, sender, -command, ((mapping) ValueCache)[split[3]]);
         }
         else
            switchboard(receiver, sender, COM_ERROR, ([ "error":
                             sprintf( "Variable not found %s",receiver) ]) );
      }
      break;
      case COM_PARAM:
      {
         if( parameters && mappingp(parameters) )
            SetParameters(parameters);
         switchboard( receiver,sender, -command, GetParameters() );
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
         else if ( sizeof(split) == 4 && has_index( ValueCache, split[3] ) )
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
