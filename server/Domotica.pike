#include <module.h>


protected mapping modules = ([]);
protected array loggers = ({});
object config,xmlrpc;
protected object server_configuration;
protected mapping run_config;
protected array compiled_modules=({});

void create( mapping rconfig)
{
   run_config = rconfig;
   config = Config( run_config->database );
   server_configuration = config->Configuration("main");
   xmlrpc = XMLRPC( run_config->xmlrpcserver, this ); 
   if ( server_configuration->module )
      moduleinit( server_configuration->module );
}

object configuration(string name )
{
   return config->Configuration(name);
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

void run_command( int command, mapping parameters, function callback, mixed ... callback_args )
{
   switch( command )
   {
      case COM_MODLIST:
      {
         array failed_modules=({});
         if( parameters && has_index(parameters,"compile") )
         {
            if( !sizeof(compiled_modules) || parameters->new )
            {
               compiled_modules = ({});
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
                     failed_modules += ({ ([  "name":name,
                                  "error": "Compilation Failed" ]) });
#ifdef DEBUG
         log(LOG_EVENT,LOG_ERR,"Error:%O\n",catch_result);
#endif
                  }
                  else
                  {
                     compiled_modules += ({ ([ "name":name,
                                   "parameters":themodule->defvar ]) });
                  }
               }
            }
            call_out(callback, 0, compiled_modules + failed_modules ,@callback_args );
         }
         else
            call_out(callback, 0, indices(modules) ,@callback_args );
      }
      break;
      case COM_SENSLIST:
      {
         array sensors=({});
         foreach( indices(modules), string module)
         {
           if( ! (modules[module]->module_type & MODULE_SENSOR) )
              continue;
           foreach( values(modules[module]->sensors), object sensor )
              sensors+=({ sensor->sensor_name });
         }
         call_out(callback, 0, sensors ,@callback_args );
      }
      break;
      case COM_ADD:
      {
         string name = parameters->name;
         m_delete(parameters,"name");
         if ( has_value(server_configuration->module, name ) )
         {
            string error=sprintf("There already exists a module instance with name %s\n",name);
            log(LOG_EVENT,LOG_ERR,error);
         call_out(callback, 0, ([ "error":error ]) ,@callback_args );
         }
         server_configuration->module+=({name});
         object cfg = config->Configuration( name );
         foreach ( parameters; string index; mixed value )
           cfg[index]=value;
         moduleinit(({ name } ) );
         call_out(callback, 0, 0 ,@callback_args );
      }
      break;
      case COM_DROP:
      {
         if( !has_index(modules, parameters->name ))
           call_out(callback, 0, (["error": sprintf("Can't Delete unknown module %s",parameters->name) ]) ,@callback_args );
         modules[parameters->name]->close();
         m_delete(modules,parameters->name);
         server_configuration->module -= ({ parameters->name });
         m_delete(config, parameters->name );
      }
      break;
      default:
      call_out(callback, 0, ([ "error":sprintf("Unknown Command %d for server",command) ]),@callback_args );
   }
}

mapping follow = ([]);

//void add_hook ( string module_sensor_value

void switchboard( string module_sensor_value, int command, mapping parameters, function callback, mixed ... callback_args )
{
#ifdef DEBUG
         log(LOG_EVENT,LOG_DEBUG,"Switchboard received command %d for module/sensor %s\n",command,module_sensor_value);
#endif
   if( !module_sensor_value || !sizeof(module_sensor_value ))
      call_out(callback, 0, ([ "error":"No module,sensor or value is requested" ]),@callback_args );

   //Server Parameters
   if( module_sensor_value == "server" )
   {
      call_out(run_command, 0, command, parameters, callback, @callback_args );
      return;
   }

   array split = split_module_sensor_value(module_sensor_value);

   if ( ! has_index(modules,split[0]) )
   {
      call_out(callback, 0, ([ "error":sprintf("Module %s not found",split[0]) ]),@callback_args );
   }
   else
   {
   //Call the requested module
      call_out(modules[split[0]]->rpc, 0, module_sensor_value, command, parameters, callback, @callback_args );
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
