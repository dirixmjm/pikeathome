#include <module.h>


protected mapping modules = ([]);
protected array loggers = ({});
object config;
protected object configuration;
protected mapping run_config;

void create( mapping rconfig)
{
   run_config = rconfig;
   config = Config( run_config->database );
   configuration = config->Configuration("main");
   init_modules( arrayp(configuration->module)?configuration->module:({configuration->module}) );
}

void log( int log_type, mixed ... args )
{
    switch( log_type)
    {
       case 1:
          foreach(loggers, string logger)
          {
             modules[logger]->log_data( @args );
          }
          break;
       case 2: 
          foreach(loggers, string logger)
          {
             modules[logger]->log_event( @args );
          }
#ifdef DEBUG
       logout(@args);
#endif
    }
}

void logout(int log_level, mixed ... args )
{
   Stdio.stdout.write(@args);
}

/* Split a sensor or module pointer into an array.
 * The array contains ({ module, sensor, attribute });
*/
array split_module_sensor_value(string what)
{
   array ret = ({});
   string parse = what;
   int i=search(what,".");
   while(i>0)
   {
      if( what[++i] != '.' )
      {
         ret += ({ what[..i-2] });
         what = what[i..];
         i=0;
      }
      i++;
      i=search(what,".",i);
   }
   if(sizeof(what))
      ret+= ({ what });
   return ret;
}

/* Find the module or sensor
 *
 */
protected object get_module_sensor(array split )
{
   //A module is requested
   if ( sizeof(split) == 1 && has_index(modules,split[0]) )
      return modules[split[0]];
   //A module with a parameter is requested, the module is returned
   //if a sensorname = parameter name, the sensor is returned.
   else if ( sizeof(split) == 2 && !has_index(modules[split[0]]->sensors,split[1]) )
      return modules[split[0]];
   //A sensor is requested.
   else if ( sizeof(split) >= 2 && has_index(modules[split[0]]->sensors,split[1]) )
      return modules[split[0]]->sensors[split[1]];
}



mixed info( string sensor, int|void new )
{
   array split = split_module_sensor_value(sensor);
   object sense = get_module_sensor(split);
   if( sense )
   {
      if(sizeof(split) > 2 )
         return sense->info(new)[split[2]];
      else
         return sense->info(new);
   }
   else
      return UNDEFINED;
}

/* write a mapping (module.sensor) to a sensor
 * or write one value (module.sensor.variable) to a sensor
 * or write on value to a (module.variable) to a module
 * Returns the current value, or mapping of current values.
 */
mixed write( string sensor, mixed values )
{
   array split = split_module_sensor_value(sensor);
   object sense = get_module_sensor(split);
   if( sense )
      if ( mappingp(values) )
      {
         return sense->write(values);
      }
      else
         return sense->write(([split[-1]:values]));
   else
      return UNDEFINED;
}

// Returns all module or sensor parameters in an array(mapping)
// The mapping contains, "name","type","default","description","value"
array parameters( string module_sensor )
{
   array split = split_module_sensor_value(module_sensor);
   object sense = get_module_sensor(split);
   if( sense )  
      return sense->getvar();
}

mixed `->(string key)
{
   switch(key)
   {
   case "sensors":
      array sensors = ({});
      foreach( values(modules), object module)
      {
         if( ! (module->module_type & MODULE_SENSOR) )
            continue;
         foreach( values(module->sensors), object sensor )
            sensors+=({ module->module_name + "." + sensor->sensor_name });
      }
      return sensors;
   case "init_modules":
      return init_modules;
   case "modules":
      return indices(modules);
   case "write":
      return write;
   case "info":
      return info;
   case "log":
     return log;
   case "configuration":
     return config->Configuration;
   case "parameters":
     return parameters;
   case "close":
      return close;
   default:
     return UNDEFINED; 
   }
}

//FIXME Should this be in here?
void init_modules( array names )
{
   foreach(names, string name)
   {
      object mod_conf = config->Configuration(name);
      if ( has_index( mod_conf, "debug" ) && (int) mod_conf->debug == 1 )
         master()->CompatResolver()->add_predefine(upper_case(name)+"DEBUG","1");
      else
         master()->CompatResolver()->remove_predefine(upper_case(name)+"DEBUG");
      mixed catch_result = catch {
           modules+= ( [name:
                    compile_file(run_config->installpath + "/modules/" + name + ".pike")(this )]);

      };
      if(catch_result)
      {
         werror("Error Module INIT %O\n%s\t\t%s\n%O\n",catch_result,name,describe_error(catch_result),backtrace());
         continue;
      }
      //Cache loggers, so they don't have to be search for every log.
      if( modules[name]->module_type & MODULE_LOG )
         loggers+= ({ name });
   }

}

void close()
{
   foreach(values(modules), object module)
   {
      module->close();
      destruct(module);
   }
}
