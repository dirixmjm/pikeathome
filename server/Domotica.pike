#include <module.h>


protected mapping modules = ([]);
protected array loggers = ({});
//object xmlrpc;
object config,ICom;
protected object server_configuration;
protected mapping run_config;
protected string name ="";


void create( mapping rconfig)
{
   run_config = rconfig;
   name = run_config->name;
   config = Config( run_config->database );
   server_configuration = config->Configuration(name);

//   xmlrpc = .XMLRPC( run_config->xmlrpcserver, this );
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
array split_server_module_sensor_value(string what)
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
#ifdef DEBUG
         log(LOG_EVENT,LOG_ERR,"Error:%O\n",catch_result);
#endif
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
            log(LOG_EVENT,LOG_ERR,error);
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
      default:
      switchboard(name, sender, 30, ([ "error":sprintf("Unknown Command %d for server",command) ]) );
   }
}

/*
* There are two ways to get values from an sensor 
* Either a direct call to the switchboard with receiver and sender
* or add a hook to a given sensor / variable and receive it everytime
* the variable enters the switchboard
*/

mapping follow = ([]);

//void add_hook ( string module_sensor_value

void switchboard( string sender, string receiver, int command, mixed parameters )
{

#ifdef DEBUG
         log(LOG_EVENT,LOG_DEBUG,"Switchboard received command %d for %s from %s \n",command,receiver, sender);
#endif

   //A receiver should always be given
   if( !receiver || !sizeof(receiver ))
   {
      call_out(switchboard, 0, "switchboard", sender, 30, ([ "error":"No module,sensor or value is requested" ]) );
      log(LOG_EVENT,LOG_ERR,"Switchboard called without any receiver\n");
   }

   array split = split_server_module_sensor_value(receiver);
   //FIXME Remove concatenating by preventing it in split_server_module_sensor.
   // ({ server, server.module,server.module.sensor,server.module.sensor.value})
   //Something went wrong and the switchboard is called
   //Switchboard message for the current server
   if ( split[0] == name)
   {
      //Message for the server
      //Propagate to a module
      if( sizeof( split) > 1)
      {
         if ( ! has_index(modules,split[0]+"."+split[1]) )
         {
            call_out(switchboard, 0, "switchboard", sender, 30, ([ "error":sprintf("Module %s not found",split[0])+"."+split[1] ]) );
            log(LOG_EVENT,LOG_ERR,"Switchboard called with unknown module %s\n",split[0]+"."+split[0] );
         }
         else
         {
         //Call the requested module
            call_out(modules[split[0]+"."+split[1]]->rpc_command, 0, sender, receiver, command, parameters );
         }
      }
      //Command for the server
      else
         call_out(rpc_command, 0, sender, receiver, command, parameters );
      
   }
   else if( split[0] == "switchboard" )
   {
      if( command = COM_ERROR )
         log(LOG_EVENT,LOG_ERR,"Switchboard received error %O\n",parameters->error);
      else
         log(LOG_EVENT,LOG_ERR,"Switchboard received unknown command %d\n",command);
      return;
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
         log(LOG_EVENT,LOG_ERR, "Error Module %s Compilation Failed\n",name);
         continue;
      }
      else
      {
         themodule->init(); 
         modules+= ( [name: themodule ]);
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
