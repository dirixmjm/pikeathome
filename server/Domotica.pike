#include <module.h>


protected mapping modules = ([]);
protected array loggers = ({});
protected array dataloggers = ({});
//object xmlrpc;
object config,ICom;
protected object server_configuration;
protected mapping run_config;
string name ="";


void create( mapping rconfig)
{
   run_config = rconfig;
   name = run_config->name;
   config = Config( run_config->database );
   server_configuration = config->Configuration(name);

   //FIXME, should this be here?
   server_configuration->listenaddress = run_config->listenaddress;
   ICom = .InterCom( this,server_configuration ); 
   if ( server_configuration->module )
      moduleinit( server_configuration->module );
}

object configuration(string name )
{
   return config->Configuration(name);
}

//Array with server configuration parameters
//Goal is to keep it to a minimum and let modules worry about operation.
array defvar = ({});

void logout(int log_level, mixed ... args )
{
   Stdio.stdout.write(@args);
}

/* Split a sensor or module pointer into an array.
 * The array contains ({ module, sensor, attribute });
*/
array split_server_module_sensor_value(string what)
{
   array ret = ({});
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

/* Split a sensor or module pointer into an array.
 * The array contains ({ server, server.module, server.module.sensor,etc });
*/
array cumulative_split_server_module_sensor_value(string what)
{
   array ret = ({});
   string store = "";
   int i=search(what,".");
   if( (i < 0) && sizeof(what) )
      return ({ what });

   while(i>0)
   {
      if( what[++i] != '.' )
      {
         ret += ({ store + what[..i-2] });
         store = store + what[..i-2]+"." ;
         what = what[i..];
         i=0;
      }
      i++;
      i=search(what,".",i);
   }
   if(sizeof(what))
      ret+= ({ store + what });

   return ret;
}

void rpc_command( string sender, string receiver, int command, mapping parameters )
{
   array split = split_server_module_sensor_value(receiver);
   switch( command )
   {
      case COM_PARAM:
      {
        if ( parameters && mappingp(parameters) )
        {
            foreach(defvar, array var)
            {
               if( has_index( parameters, var[0] ) )
                  server_configuration[var[0]] = parameters[var[0]];
            }
         }
         array ret = ({});
         foreach(defvar, array var)
            ret+= ({ var + ({ server_configuration[var[0]] }) });
         switchboard(name, sender, -command, ret );
      }
      break;
      case COM_FIND:
      {
         array failed_modules=({});
         array compiled_modules = ({});
         object moddir = Filesystem.Traversion(run_config->installpath + "/modules" );
         foreach( moddir; string dirname; string filename )
         { 
            string name="";
            if( !has_suffix(filename,".pike")) continue;
            sscanf(filename,"%s\.pike",name);
            object themodule;
            mixed catch_result = catch { 
               themodule =compile_file(dirname+filename)(name,this);
            };
            if(catch_result)
            {
               failed_modules += ({ ([  "module":name,
                            "error": "Compilation Failed" ]) });
               logerror("Error:%O\n",catch_result);
            }
            else
            {
               compiled_modules += ({ ([ "module":name,
                             "parameters":themodule->defvar +
                             ({ ({ "name",PARAM_STRING,"default","Name"}) })
                              ]) });
            }
         }
         switchboard(name, sender, -command, compiled_modules + failed_modules );
      }
      break;
      case COM_LIST:
      {
         switchboard(name, sender, -command, indices(modules) );
      }
      break;
      case COM_ALLSENSOR:
      {
         array sensors=({});
         foreach( indices(modules), string module)
         {
           if( ! (modules[module]->module_type & MODULE_SENSOR) )
              continue;
           foreach( values(modules[module]->sensors), object sensor )
              sensors+=({ sensor->sensor_name });
         }
         switchboard(name, sender , -command, sensors);
      }
      break;
      case COM_ADD:
      {
         string module_name = name+"."+parameters->name;
         m_delete(parameters,"name");
         if ( has_value(server_configuration->module, module_name ) )
         {
            string error=sprintf("There already exists a module instance with name %s\n",module_name);
            switchboard(module_name, sender, 30, ([ "error":error ]));
         }
         server_configuration->module+=({module_name});
         object cfg = config->Configuration( module_name );
         foreach ( parameters; string index; mixed value )
           cfg[index]=value;
         moduleinit(({ module_name } ) );
         switchboard(name, sender, -command, UNDEFINED );
      }
      break;
      case COM_DROP:
      {
         if( !has_index(modules, parameters->name ))
           switchboard(name, sender, 30, (["error": sprintf("Can't Delete unknown module %s",parameters->name) ]) );
         modules[parameters->name]->close();
         m_delete(modules,parameters->name);
         server_configuration->module -= ({ parameters->name });
         m_delete(config, parameters->name );
      }
      break;
      case COM_ERROR:
         call_out(switchboard, 0, name, name, COM_LOGEVENT, ([ "level":LOG_ERR, "error":parameters->error ]) );
      break;
      case COM_LOGEVENT:
      foreach(loggers, string logger)
      {
         //Fixme Switchboard?
         modules[logger]->log_event( parameters->level, sender, parameters->error );
#ifdef DEBUG
       logout(parameters->level,parameters->error);
#endif
      }
      break;
      case COM_LOGDATA:
      foreach(dataloggers, string logger)
      {
         modules[logger]->log_data( parameters->name, parameters->data,has_index(parameters,"stamp")?parameters->stamp:UNDEFINED );
      }
      break;
      default:
      switchboard(name, sender, COM_ERROR, ([ "error":sprintf("Unknown Command %d for server",command) ]) );
   }
}

/*
* There are two ways to get values from an sensor 
* Either a direct call to the switchboard with receiver and sender
* or add a hook to a given sensor / variable and receive it everytime
* the variable enters the switchboard
*/

void switchboard( string sender, string receiver, int command, mixed parameters )
{

#ifdef DEBUG
         logout(LOG_DEBUG,"Switchboard received command %d for %s from %s \n",command,receiver, sender );
#endif

   //A receiver should always be given
   if( !receiver || !sizeof(receiver ))
   {
      call_out(switchboard, 0, name, sender, COM_ERROR, ([ "error":"No module,sensor or value is requested" ]) );
   }

   array split = cumulative_split_server_module_sensor_value(receiver);
   // ({ server, server.module,server.module.sensor,server.module.sensor.value})
   //Something went wrong and the switchboard is called
   //Switchboard message for the current server
   if ( split[0] == name)
   {
      //Message for the server

      //Propagate to a module
      if( sizeof( split) > 1)
      {
         if ( ! has_index(modules,split[1]) )
         {
            call_out(switchboard, 0, name, sender, 30, ([ "error":sprintf("Module %s not found",split[1]) ]) );
         }
         else
         {
         //Call the requested module
            call_out(modules[split[1]]->rpc_command, 0, sender, receiver, command, parameters );
         }
      }
      //Command for the server
      else
         call_out(rpc_command, 0, sender, receiver, command, parameters );
      
   }
   else
   {
      //Message is for a different server
      call_out(ICom->rpc_command, 0, sender, receiver, command, parameters );
   }


     
}

void moduleinit( array names )
{
   foreach(names, string name)
   {
      object mod_conf = config->Configuration(name);
      if ( has_index( mod_conf, "debug" ) && (int) mod_conf->debug == 1 )
         master()->CompatResolver()->add_predefine(upper_case(name)+"DEBUG","1");
      else
         master()->CompatResolver()->remove_predefine(upper_case(name)+"DEBUG");
      object themodule;
      mixed catch_result = catch {
                    
         themodule = compile_file(run_config->installpath + "/modules/" + mod_conf->module + ".pike")( name, this );
       

      };
      if(catch_result)
      {
         logerror("Error Module %s Compilation Failed\n",name);
         continue;
      }
      else
      {
         themodule->init(); 
         modules+= ( [name: themodule ]);
      } 
      //Cache loggers, so they don't have to be search for every log.
      if( modules[name]->module_type & MODULE_LOGEVENT )
         loggers+= ({ name });
      if( modules[name]->module_type & MODULE_LOGDATA )
         dataloggers+= ({ name });
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

/*
* Helper / Short functions for Modules
*/

void logdebug(mixed ... args)
{
   switchboard(name, name, COM_LOGEVENT, ([ "level":LOG_DEBUG, "error":sprintf(@args) ]) );
}

void logerror(mixed ... args)
{
   switchboard(name, name, COM_LOGEVENT, ([ "level":LOG_ERR, "error":sprintf(@args) ]) );

}
