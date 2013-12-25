#include <sensor.h>
#include <variable.h>
#include <parameters.h>
#include <command.h>
inherit Base_func;

int sensor_type = 0; 

protected object configuration;
object module;
protected object ValueCache;

array SensorParameters = ({});



mapping SensorProperties = ([
                               "module":"",
                               "name":"",
                               "sensor_type":sensor_type
                               ]);

void create( string name, object _module, object _configuration )
{
   module = _module;
   configuration = _configuration;
   ValueCache = VariableStorage(_configuration, LogValue );
   SensorProperties->module = _module->ModuleProperties->name;
   SensorProperties->name = name;
   SensorProperties->sensor_type = sensor_type;
   sensor_init();
}

/* Function called to initialize the sensor and variables */
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

protected void UpdateSensor()
{
}


/* This is the basic logging function. If other logic is needed
 * it is recommended that the sensor class overloads this function
 */
protected void LogValue(string variable_name)
{
   string name = SensorProperties->name + "." + variable_name; 
   UpdateSensor();
   logdata(name,ValueCache[variable_name],time(1));
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
         if ( option[4] == POPT_RELOAD )
            SensorReload(option[0]);
      }
   }
   foreach(SensorParameters, array option)
   {
      //Find the parameter, and always set it
      if( has_index( params, option[0] ) )
      {
         configuration[option[0]]=params[option[0]];
         if ( option[4] == POPT_RELOAD )
            SensorReload(option[0]);
      }
   }
}

//Reload Sensor due to change of option <option>
void SensorReload(string option)
{

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
   array split = split_server_module_sensor_value(receiver);
   switch(command)
   {
      case COM_READ:
      {
         UpdateSensor();
         //If the sensor can be offline, then do not return a value, since
         //then we would return the value 0.0 which offputs the comperator
         //FIXME think about this behaviour.
         if ( has_index( ValueCache, "online" ) && (ValueCache->online == 0) )
         {
            logdebug("Sensor %s not online so not returning any data\n",receiver);
            switchboard(receiver, sender, COM_ERROR, ([ "error":
                             sprintf( "Sensor %s not online so not returning any data\n",receiver) ]) );
            return;
         }
         if ( sizeof(split) == 3 )
            switchboard(receiver, sender, -command, (mapping) ValueCache );
         else if ( sizeof(split) == 4 && has_index( ValueCache, split[3] ) )
         {
            switchboard(receiver, sender, -command, ((mapping) ValueCache)[split[3]]);
         }
         else
            switchboard(receiver, sender, COM_ERROR, ([ "error":
                             sprintf( "Variable not found %s\n",receiver) ]) );
      }
      break;
      case COM_PARAM:
      {
         if ( sizeof(split) == 3 )
         {
            if( parameters && mappingp(parameters) )
               SetParameters(parameters);
            switchboard( receiver,sender, -command, GetParameters() );
         }
         else if ( sizeof(split) == 4 )
         {
            if( parameters && mappingp(parameters) )
               ValueCache->SetParameters(split[3],parameters);
            switchboard( receiver, sender, -command, ValueCache->GetParameters(split[3])); 
         }
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
                             sprintf( "Variable not found %s\n",receiver) ]) );

      }
      break;
      case COM_RETRLOGDATA:
      {
         /* Logging goes through the Sensor since the requesting server
          * must not necessarily know which logging module is used
          */
         if ( ! parameters || !mappingp(parameters) )
         {
            switchboard(receiver, sender, COM_ERROR, ([ "error":
                             sprintf( "Bad parameters retrieve log data for %s",receiver) ]) );
            return;
         }
         if ( sizeof(split) < 4 )
         {
            switchboard(receiver, sender, COM_ERROR, ([ "error":
                             sprintf( "Need variable name for retrieving log data for %s",receiver) ]) );
            return;
         }
         //Need to retrieve log over the switchboard.
         module->retrlogdata(receiver,sender,parameters);
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
