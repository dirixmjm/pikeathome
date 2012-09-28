#include <module.h>
#include <parameters.h>
#include <command.h>

protected object configuration;

protected object domotica;

int module_type = 0;
string name = "module";


//The Sensor Mapping should contain all sensors
mapping sensors=([]);

//The module_var mapping should contain all runtime variables
mapping module_var = ([
                      ]);

//The defvar mapping should contain all configuration variables
//defvar should contain arrays  ({ "name","type","default","description"})
constant defvar = ({});

//Sensor Parameters
//sensvar should contain arrays ({ "name","type","default","description"})
constant sensvar = ({});

void create( string _name, object _domotica )
{
   domotica = _domotica;
   //Maybe decrepate "name"
   name = _name;
   module_var->name=_name;
   configuration = domotica->configuration(_name);
   //Maybe decrepate direct "module_type" variable?
   module_var->module_type=module_type;
}

void init()
{
   logdebug("Init Module %s\n",module_var->name);
   if( (module_type & MODULE_SENSOR) && has_index(configuration,"sensor") )
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
   array var = sensvar;
   var+= ({ ({ "name",PARAM_STRING,"default","Name"}) }) ;
   return ({ ([ "sensor":"manual","module":name,"parameters":var ])});
}

array getvar()
{
   array ret = ({});
   foreach(defvar, array var)
      ret+= ({ var + ({ configuration[var[0]] })});
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

void got_answer(mixed parameters)
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
         got_answer(parameters);
         return;
      }
      switch(command)
      {
         case COM_PARAM:
         {
            if ( parameters && mappingp(parameters) )
               setvar(parameters);
            switchboard( receiver,sender, -command, getvar() );
         }
         break;
         case COM_PROP:
         {
            switchboard( receiver,sender, -command, module_var );
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
            string sensor_name = name + "." + parameters->name;
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
   call_out(switchboard, 0, module_var->name, domotica->name, COM_LOGEVENT, ([ "level":LOG_DEBUG, "error":sprintf(@args) ]) );
}

void logerror(mixed ... args)
{
   call_out(switchboard, 0, module_var->name, domotica->name, COM_LOGEVENT, ([ "level":LOG_ERR, "error":sprintf(@args) ]) );

}

void logdata(string name, string|int|float data, int|void tstamp)
{
   mapping params = ([ "name":name,"data":data ]);
   if ( intp(tstamp) )
     params+= ([ "stamp":tstamp ]);

   call_out(switchboard, 0, module_var->name, domotica->name, COM_LOGDATA,
                     params );
}

array split_server_module_sensor_value(string module_sensor_value)
{
   return domotica->split_server_module_sensor_value(module_sensor_value);
}
