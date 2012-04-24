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
#ifdef DEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"Init Module %s\n",name);
#endif
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
array find_sensors( int|void manual)
{
   array ret = ({});
   //manual is 2 per XMLRPC.pike module.sensor.add.manual
   if( manual == 2 )
      ret+= ({ ([ "sensor":"manual","module":name,"parameters":sensvar ])});
   return ret;
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
      //Find the parameter, and check if it has changed.
      if( has_index( params, option[0] ) && params[option[0]] != configuration[option[0]] )
      {
         configuration[option[0]]=params[option[0]];
         mod_options |= option[4];
      }
   }
   if( mod_options & POPT_RELOAD ) 
      reload();
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

void rpc( string module_sensor_value, int command, mapping parameters, function callback, mixed ... callback_args)
{
   array split = split_module_sensor_value(module_sensor_value);
 
   //Check if the request is for this module.
   //Check if the request is for a sensor.
   if( sizeof(split) > 1)
   {
      if ( ! has_index(sensors,split[0]+"."+split[1]) )
      {
         call_out(callback, 0, ([ "error":sprintf("Sensor %s in module %s not found",split[1],split[0]) ]),@callback_args );
      }
      else
      {
      //Call the requested module
         call_out(sensors[split[0]+"."+split[1]]->rpc, 0, module_sensor_value, command, parameters, callback, @callback_args );
      }
   }
   else
   {
      switch(command)
      {
         case COM_INFO:
         {
            call_out(callback, 0, module_var ,@callback_args );
         }
         break;
         case COM_PARAM:
         {
         if( parameters && sizeof( parameters ) > 0 )
            setvar(parameters);
         call_out(callback, 0, getvar() ,@callback_args );
         }
         break;

         case COM_SENSLIST:
         {
         //FIXME This should probably callbacks too.
         if( parameters && parameters->new )
            call_out(callback, 0, 
              find_sensors( parameters?parameters->manual:0)  ,@callback_args );
         else
            call_out(callback, 0, indices(sensors) ,@callback_args );
         
         }
         break;
         
         case COM_ADD: //Add Sensor
         {
            //FIXME Should I add module_name at this point?
            string name = parameters->name;
            m_delete(parameters,"name");
            if( has_value( configuration->sensor, name ) )
            {
               call_out(callback, 0, (["error": sprintf("There already exists a sensor with name %s",name) ]) ,@callback_args );
               return;
            }
            configuration->sensor+= ({ name });
            object cfg = domotica->configuration( name );
            foreach( parameters; string index; mixed value )
            {
               cfg[index]=value;
            }
            init_sensors( ({ name }) );
            call_out(callback, 0, 0 ,@callback_args );
         }
         break;

         case COM_DROP: //drop sensor
         {
            if(!has_index ( sensors, parameters->name ) )
            {
               call_out(callback, 0, (["error": sprintf("Can't Delete unknown sensor %s",parameters->name) ]) ,@callback_args );
               return;
            }
            sensors[parameters->name]->close();
            m_delete(sensors,parameters->name);
            configuration->sensor -= ({ parameters->name });
            //FIXME Is this the correct way to do this?
            m_delete(domotica->config, parameters->name ); 
            call_out(callback,0 ,0 , @callback_args ); 
         }
         break;
         default:
         call_out(callback, 0, ([ "error":sprintf("Module %s unknown command %d",split[0],command) ]),@callback_args );
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
   domotica->log(LOG_EVENT,LOG_DEBUG,@args);
}

void logerror(mixed ... args)
{
   call_out(domotica->log(LOG_EVENT,LOG_ERR,@args),0);
}

void logdata(mixed ... args)
{
   call_out(domotica->log(LOG_DATA,@args),0);
}

array split_module_sensor_value(string module_sensor_value)
{
   return domotica->split_module_sensor_value(module_sensor_value);
}
