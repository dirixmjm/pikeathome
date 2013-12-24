#include <module.h>
#include <parameters.h>
#include <command.h>
inherit Base_func;

protected object configuration;
protected string servername = "";
function switchboard;

int module_type = 0;

//The Sensor Mapping should contain all sensors
mapping sensors=([]);

//The ModuleProperties mapping should contain all runtime variables
mapping ModuleProperties = ([
                      ]);

constant ModuleParameters = ({});

constant SensorBaseParameters = ({});

void create( string _name, object _configuration, function _switchboard )
{
   switchboard = _switchboard;
   ModuleProperties->name=_name;
   array split = split_server_module_sensor_value(_name);
   servername = split[0];
   configuration = _configuration;
   ModuleProperties->module_type=module_type;
}

void init()
{
   logdebug("Init Module %s\n",ModuleProperties->name);
   if( (ModuleProperties->module_type & MODULE_SENSOR) && has_index(configuration,"sensor") )
   {
      init_sensors( configuration->sensor +({}) );
   }
}

void init_sensors( array load_sensors )
{
   foreach(load_sensors, string name )
   {
      sensors+= ([ name: sensor( name, this, configuration->Configuration(name) ) ]);
   }
}

//If possible return an array containing alle sensors that can be found 
// in the sensornetwork.
array find_sensors( )
{
   //Default return manual sensor entry
   array var = SensorBaseParameters;
   var+= ({ }) ;
   return ({ ([ "name":"manual","module":ModuleProperties->name,"parameters":var ])});
}

mixed GetParameter( string Param )
{
   return configuration[Param];
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
      ModuleReload();
}

void got_answer(int command, string name, mixed parameters)
{

}

//Reload Stuff When a Parameter Changes
void ModuleReload()
{
}

void close()
{
   foreach(values(sensors),object sensor)
      sensor->close();
   configuration = 0;   
}

void rpc_command( string sender, string receiver, int command, mapping parameters)
{
   array split = split_server_module_sensor_value(receiver);
 
   //Check if the modules has sensors, and if the request is for a sensor.
   if( (ModuleProperties->module_type & MODULE_SENSOR) && sizeof(split) > 2 )
   {
      if ( ! has_index(sensors,split[0]+"."+split[1]+"."+split[2]) )
      {
         switchboard( receiver,sender,COM_ERROR, ([ "error":sprintf("Sensor %s in module %s not found, sender %s, receiver %s\n",split[2],split[1],sender,receiver) ]) );
      }
      else
      {
      //Call the requested module
         call_out(sensors[split[0]+"."+split[1]+"."+split[2]]->rpc_command, 0, sender, receiver, command, parameters );
      }
   }
   //This module is the receiver.
   else
   {
      if( command < 0 )
      {
         got_answer(command, sender, parameters);
         return;
      }
      switch(command)
      {
         case COM_PARAM:
         {
            if ( parameters && mappingp(parameters) )
               SetParameters(parameters);
            switchboard( receiver,sender, -command, GetParameters() );
         }
         break;
         case COM_PROP:
         {
            switchboard( receiver,sender, -command, ModuleProperties );
         }
         break;
         case COM_LIST:
         {
            switchboard( receiver,sender, -command, indices(sensors)  );
         }
         break;
         case COM_FIND:
         {
            switchboard( receiver,sender, -command, find_sensors());
         }
         break;
         case COM_ADD: //Add Sensor
         {
            //What if this isn't a sensor-type module?
            string sensor_name = ModuleProperties->name + "." + parameters->name;
            mapping params = parameters->parameters+([]);
            if( !has_index( configuration, "sensor" ) )
               configuration->sensor=({});
            if( has_value( configuration->sensor, sensor_name ) )
            {
               switchboard( receiver,sender, COM_ERROR, 
                           (["error": sprintf("There already exists a sensor with name %s",sensor_name) ]) );
               return;
            }
            configuration->sensor+= ({ sensor_name });
            object cfg = configuration->Configuration( sensor_name );
            //FIXME set default value if parameters is not in the mapping
            foreach( params; string index; mixed value )
            {
               cfg[index]=value;
            }
            init_sensors( ({ sensor_name }) );
            switchboard(receiver,sender, -command, 0 );
         }
         break;
         case COM_DROP: //drop sensor
         {
            string sensor_name = parameters->name;
            if(!has_index ( sensors, sensor_name ) )
            {
               switchboard( receiver,sender, COM_ERROR, (["error": sprintf("Can't Delete unknown sensor %s",sensor_name) ]) );
               return;
            }
            sensors[sensor_name]->close();
            m_delete(sensors,sensor_name);
            configuration->sensor -= ({ sensor_name });
            m_delete(configuration, sensor_name ); 
            switchboard( receiver,sender,-command,UNDEFINED); 
         }
         break;
         case COM_ERROR:
            logerror(parameters->error);
         break;
         default:
         switchboard( receiver,sender, COM_ERROR, ([ "error":sprintf("Module %s unknown command %d",split[0],command) ]) );
      }
   }
}

/*
* Helper / Short functions for Modules
*/

void logdebug(mixed ... args)
{
   if( (int) configuration->debug == 1 )
      call_out(switchboard, 0, ModuleProperties->name, "broadcast", COM_LOGEVENT, ([ "level":LOG_DEBUG, "error":sprintf(@args) ]) );
}

void logerror(mixed ... args)
{
   call_out(switchboard, 0, ModuleProperties->name, "broadcast", COM_LOGEVENT, ([ "level":LOG_ERR, "error":sprintf(@args) ]) );

}

void logdata(string name, string|int|float data, int|void tstamp)
{
   mapping params = ([ "name":name,"data":data ]);
   if ( intp(tstamp) )
     params+= ([ "stamp":tstamp ]);
   call_out(switchboard, 0, name, "broadcast", COM_LOGDATA, params );
}

void retrlogdata(string sensor, string sender, mapping parameters)
{
   parameters["name"] = sensor;
   call_out(switchboard, 0, sender, "broadcast", COM_RETRLOGDATA, parameters );
}

class sensor
{
inherit Sensor;

}
