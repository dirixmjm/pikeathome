#include <module.h>
#include <parameters.h>
#include <command.h>

protected object configuration;

protected object domotica;

int module_type = 0;

//The Sensor Mapping should contain all sensors
mapping sensors=([]);

//The ModuleProperties mapping should contain all runtime variables
mapping ModuleProperties = ([
                      ]);

//The ModuleParameters mapping should contain all configuration variables
//ModuleParameters should contain arrays  ({ "name","type","default","description"})
constant ModuleParameters = ({});

//Sensor Parameters
//SensorBaseParameters should contain arrays ({ "name","type","default","description"})
constant SensorBaseParameters = ({});

void create( string _name, object _domotica )
{
   domotica = _domotica;
   ModuleProperties->name=_name;
   configuration = domotica->configuration(_name);
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
      sensors+= ([ name: sensor( name, this, domotica->configuration(name) ) ]);
   }
}

//If possible return an array containing alle sensors that can be found 
// in the sensornetwork.
array find_sensors( )
{
   //Default return manual sensor entry
   array var = SensorBaseParameters;
   var+= ({ ({ "name",PARAM_STRING,"default","Name"}) }) ;
   return ({ ([ "sensor":"manual","module":ModuleProperties->name,"parameters":var ])});
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

void got_answer(int command, mixed parameters)
{

}


class sensor
{
inherit Sensor;

}

void reload()
{
   foreach(values(sensors),object sensor)
      sensor->close();
   init(); 
}

void close()
{
   foreach(values(sensors),object sensor)
      sensor->close();
   domotica = 0;
   configuration = 0;   
}

void rpc_command( string sender, string receiver, int command, mapping parameters)
{
   array split = split_server_module_sensor_value(receiver);
 
   //Check if the request is for a sensor.
   if( sizeof(split) > 2 )
   {
      if ( ! has_index(sensors,split[0]+"."+split[1]+"."+split[2]) )
      {
         switchboard( receiver,sender,COM_ERROR, ([ "error":sprintf("Sensor %s in module %s not found",split[1],split[0]) ]) );
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
         got_answer(command,parameters);
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
            m_delete(parameters,"name");
            if( !has_index( configuration, "sensor" ) )
               configuration->sensor=({});
            if( has_value( configuration->sensor, sensor_name ) )
            {
               switchboard( receiver,sender, COM_ERROR, 
                           (["error": sprintf("There already exists a sensor with name %s",sensor_name) ]) );
               return;
            }
            configuration->sensor+= ({ sensor_name });
            object cfg = domotica->configuration( sensor_name );
            foreach( parameters; string index; mixed value )
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
            m_delete(domotica->config, sensor_name ); 
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
* Helper Function for sensors to call the switchboard
*/
void switchboard ( mixed ... args )
{
   call_out( domotica->switchboard,0, @args );
}

/*
* Helper / Short functions for Modules
*/

void logdebug(mixed ... args)
{
   if( (int) configuration->debug == 1 )
      call_out(switchboard, 0, ModuleProperties->name, domotica->name, COM_LOGEVENT, ([ "level":LOG_DEBUG, "error":sprintf(@args) ]) );
}

void logerror(mixed ... args)
{
   call_out(switchboard, 0, ModuleProperties->name, domotica->name, COM_LOGEVENT, ([ "level":LOG_ERR, "error":sprintf(@args) ]) );

}

void logdata(string name, string|int|float data, int|void tstamp)
{
   mapping params = ([ "name":name,"data":data ]);
   if ( intp(tstamp) )
     params+= ([ "stamp":tstamp ]);

   call_out(switchboard, 0, name, domotica->name, COM_LOGDATA,
                     params );
}

array split_server_module_sensor_value(string module_sensor_value)
{
   return domotica->split_server_module_sensor_value(module_sensor_value);
}
