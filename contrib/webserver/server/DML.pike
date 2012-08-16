#include <module.h>
#include <command.h>

inherit Base_func;

//FIXME Protect with Mutex?
protected Sql.Sql db;
protected object webserver;
//The Config object has access to all configurations
//It is needed for module inits
protected object Config;
//The configuration object is used internally for the parser
protected object configuration;
//The configuration from the configurationfile
mapping run_config;
//The Configuration Module
protected object Configuration_Interface;
protected object ICom;

string servername;
Parser.HTML parser;


mapping tags = ([
"include":DMLInclude,
"write":DMLWrite,
"set":DMLSet,
"inc":DMLInc,
"dec":DMLDec,
"redirect":DMLRedirect,
"date":DMLDate,
]);

mapping emit = ([
"sensors": EmitSensors,
"sensor": EmitSensor,
"modules": EmitModules,
]);

mapping containers = ([
"emit":DMLEmit,
"if":DMLIf,
]);


void create( string server_name, object webserver_ , mapping run_config_, object Config_)
{
   webserver= webserver_;
   servername = server_name;
   run_config = run_config_;
   Config = Config_;
   configuration = Config->Configuration(servername);
   configuration->listenaddress=run_config->listenaddress;
   ICom = master()->resolv("InterCom")(this, configuration);

   parser = DMLParser();
   parser->add_tags(tags);
   parser->add_containers(containers);
   parser->add_entity ( "lt", 0);
   parser->add_entity ( "gt", 0 );
   parser->add_entity("amp",0);
   parser->_set_entity_callback( entity_callback );
   parser->lazy_entity_end(1);

   Configuration_Interface = master()->resolv("Configuration")(this, configuration);
   parser->add_tags(Configuration_Interface->tags);
   parser->add_containers(Configuration_Interface->containers);
   emit += Configuration_Interface->emit; 

   init_modules(configuration->module + ({}));
}

void init_modules( array names )
{
   foreach(names, string name)
   {
      object mod_conf = Config->Configuration(name);
      object mod;
      mixed catch_result = catch {
         mod = compile_file(run_config->installpath + "/modules/" + mod_conf->module + ".pike")( this, mod_conf );

      };
      if(catch_result)
      {
         logerror("Error Module INIT %O\n%s\t\t%s\n%O\n",catch_result,name,describe_error(catch_result),backtrace());
         continue;
      }
      parser->add_tags(mod->tags);
      parser->add_containers(mod->containers);
      emit += mod->emit; 
   }
}


array entity_callback(Parser.HTML p, 
               string entity, mapping query )
{
   //FIXME split_module_sensor?   
   string scope,variable,sensor;
   int scan = sscanf(entity,"&%s.%s;",scope,variable);
   if( scan < 2 )
      return ({ entity });
   //Must be a module.variable of module.sensor.variable key:
   if ( sscanf(variable,"%s.%s",sensor,variable) == 2 )
   {
      string val = (string) rpc( sprintf("%s.%s.%s",scope,sensor,variable),
                       COM_READ);
      return ({ val || entity });
   }
   if( has_index( query->entities, scope ) && has_index(query->entities[scope],variable) )
      return ({ query->entities[scope][variable] });
   return ({entity});
}

string resolve_entity(string entity, mapping query )
{
   string scope="",variable="";
   int scan = sscanf(entity,"%s.%s",scope,variable);
   if( scan < 2 || !has_index( query->entities, scope ) || 
       !has_index(query->entities[scope],variable) )
      return entity;
   return (string) query->entities[scope][variable];
}

void set_entity(int|float|string value, string entity, mapping query )
{
   string scope="",variable="";
   int scan = sscanf(entity,"%s.%s",scope,variable);
   if( scan < 2 || !has_index(query->entities, scope) )
      return;
   query->entities[scope][variable] = (string) value;

}

int exists_entity(string entity, mapping query )
{
   string scope="",variable="";
   int scan = sscanf(entity,"%s.%s",scope,variable);
   if( scan < 2 || !has_index( query->entities, scope ) || 
       !has_index(query->entities[scope],variable) )
      return 0;
   return 1;
}

array EmitModules( mapping args, mapping query )
{
  array ret=({});
  array modules = rpc( "xiserver", COM_LIST, 0 );
  foreach( modules, string name)
     ret+= ({  ([ "name":name ]) });
  return ret;
}

array EmitSensors( mapping args, mapping query )
{
   int sensor_type = 0;
   if( has_index(args,"input") )
       sensor_type |= SENSOR_INPUT;
   if( has_index(args,"output") )
       sensor_type |= SENSOR_OUTPUT;
   if( has_index(args,"schedule") )
       sensor_type |= SENSOR_SCHEDULE;
   if( has_index(args,"all") || ( !has_index(args,"input") && 
                   !has_index(args,"output") && !has_index(args,"schedule") ) )
       sensor_type = 0xFF;
   array ret = ({});
   array sensors = rpc( args->name, COM_ALLSENSOR ) + ({}); 
   foreach( sensors , string sensor )
   {
      mapping prop = rpc( sensor, COM_PROP );
      if( prop && has_index(prop,"sensor_type") && (prop->sensor_type & sensor_type) )
      {
         ret += ({ prop  });
      }
   }
   return ret;
}

array EmitSensor( mapping args, mapping query )
{
   if( has_index(args,"name" ) )
   {
      array res = ({});
      mapping data = rpc( args->name, COM_READ );
      if( !data )
         return ({});
      foreach( indices(data), string index )
      {
         res+= ({ ([ "index":index, "value":data[index] ]) });
      }
      return res;
   }
   return ({});
}

array DMLEmit(Parser.HTML p, 
               mapping args, string content, mapping query )
{
   if(!has_index(args,"source") || !has_index(emit,args->source) )
      return ({"Emit Source not found<br />"});
   string ret="";
   string scope = args->scope || "_";
   array data = emit[args->source](args, query);
   mapping scope_backup = ([]);
   if ( has_index( query->entities, scope ) )
   {
     scope_backup = ([ scope: query->entities[scope] ]);
     m_delete( query->entities, scope);
   }
   foreach( data, mapping values)
   {
      if( has_index(query->entities,scope) )
         m_delete(query->entities,scope);
      foreach( indices(values), string ind )
      {
         //FIXME What to do with objects?
         if(!objectp(values[ind]))
            query->entities[scope] += ([ ind: (string) values[ind] ]);
      }
      /*FIXME recursive? this->parse(request, clone)*/
      object emitparser = parser->clone();
      emitparser->set_extra(query);
      emitparser->ignore_tags(1);
      string pass_1 = emitparser->feed(content)->finish()->read();
      emitparser->ignore_tags(0);
      emitparser->feed(pass_1);
      ret+= emitparser->read();
   }
   m_delete(query->entities,scope);
   query->entities+=scope_backup;
   return ({ ret });
}

string DMLWrite(Parser.HTML p, 
               mapping args, mapping query )
{
   
   if( !has_index( args, "name" ))
      return "";
   array sensors = rpc( args->name, COM_WRITE, ([ "value":args->value]) ); 
   return "";
}

string DMLInclude(Parser.HTML p, 
               mapping args, mapping query )
{
   if( !has_index( args, "file") || !Stdio.is_file( configuration->webpath + args->file ) )
      return "Error, argument file not given, or file doesn't exist<br />";
   return Stdio.read_file(configuration->webpath + args->file);
   
   
}

string DMLIf(Parser.HTML p, 
               mapping args, string content, mapping query )
{
   if ( has_index( args, "variable" ) )
   {
      array arr = args->variable/" ";
      if( !exists_entity(arr[0],query ) )
         return "";
      else if ( sizeof(arr) == 1 )
      {
            return content;
      }
      else if ( sizeof(arr) == 2 )
      {
         return "";
      }
      else if ( arr[1] == "=" || arr[1] == "==" || arr[1] == "is" )
      {
         string var = resolve_entity(arr[0],query);
         string is = arr[2..]*" ";
         if ( var == is )
            return content;
         else 
            return "";
      } 
      else if ( arr[1] == "!=" ) 
      {
         string var = resolve_entity(arr[0],query);
         string is = arr[2..]*" ";
         if ( var != is )
            return content;
         else 
            return "";
      }
   }
   return "No argument given for if tag<br />";
}

string DMLInc(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( has_index( args, "variable" ) )
   {
      float value = 1.0;
      if( !exists_entity(args->variable,query ) )
         return "";
      float var = (float) resolve_entity(args->variable,query);
      
      if ( has_index( args, "value" ) )
         value = (float) resolve_entity(args->value,query);
      set_entity( var+value, args->variable, query);
   }
   else
      return "variable argument missing";
}

string DMLDec(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( has_index( args, "variable" ) )
   {
      float value = 1.0;
      if( !exists_entity(args->variable,query ) )
         return "";
      float var = (float) resolve_entity(args->variable,query);
      
      if ( has_index( args, "value" ) )
         value = (float) resolve_entity(args->value,query);
      set_entity( var-value, args->variable, query);
   }
   else
      return "variable argument missing";
}

string DMLSet(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( has_index( args, "variable" ) && has_index( args, "value" ) )
   {
      string value = resolve_entity(args->value,query);
      set_entity( value, args->variable, query);
   }
   else
      return "variable argument missing";
}

string DMLRedirect(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( has_index( args, "to" ) )
   {
      string to = resolve_entity(args->to,query);
      query["state"]=([ "return_code":302, "Location": to ]);
      return ""; 
   }
   else
      return "Missing argument to";
}

string DMLDate(Parser.HTML p, 
               mapping args, mapping query )
{
   mapping date = Calendar.Minute()->datetime();
   //FIXME Calendar.Minute()->format?
   string ret = sprintf("%02d-%02d-%d",date->day,date->month,date->year);
   if( has_index(args, "time") )
      ret += sprintf(" %0d:%02d",date->hour,date->minute);
   return ret;
}

object parse(object Request,string data)
{
   mapping query;
   query = ([ "request":Request]);
   query["args"] = Protocols.HTTP.Server.http_decode_urlencoded_query(Request->query);
//   query["configuration"] = configuration;

   //FIXME Pathdata
   query["entities"] = ([ "form": Request->variables, "var":([]) ]);
   object clone = parser->clone();
   clone->set_extra(query);
   clone->ignore_tags(1);
   clone->feed(data);
   string pass_1 = clone->finish()->read();
   clone->ignore_tags(0);
   clone->feed(pass_1);
   object File = DMLFile( clone->finish()->read(), clone->get_extra()[0] );
   
   return File;
}

class DMLFile
{
   inherit Stdio.FakeFile;

   int return_code = 200;
   mapping return_data = ([]);
   constant is_dml_file = 1;
   string file_type = "text/html";

   void create( string data, mapping request )
   {
      ::create( data, "R");
      if( has_index( request, "state" ) )
      {
         return_code = request->state->return_code;
         m_delete(request->state, "return_code");
         return_data = request->state;
      }
   }
}

class DMLParser
{
   inherit Parser.HTML;

   void create( )
   {
      lazy_entity_end (1);
      match_tag(0);
      xml_tag_syntax(2);
   }

}

void switchboard( string sender, string receiver, int command, mixed|void parameters)
{
   if ( command == COM_ERROR ) 
   {
     logerror("Server returned an error %O\n",parameters->error );
     return;
   }
   if( command > 0  )
   {
     logerror("Switchboard can only handle answers to requests\n" );
     return;
   }
   else if ( parameters ) 
   {
     rpc_cache[sender]+=([ abs(command):parameters]);
   }
}

mapping rpc_cache=([]);

mixed rpc( string receiver, int command, mapping|void parameters )
{
    //Check if the receiver is internal
   if ( receiver == servername || has_prefix( receiver, servername ) )
   {
      return internal_command(receiver, command,parameters );
   }

#ifdef DEBUG
   logdebug("RPC: Send Request %s %d\n",receiver, command );
   logdebug("RPC: %O\n",parameters );
#endif
   call_out(ICom->rpc_command,0, receiver, command, parameters);
   
   // always return the cached value
   // do split caching
   if ( has_index( rpc_cache, receiver ) && has_index( rpc_cache[receiver],command))
     return rpc_cache[receiver][command];
  else
     return UNDEFINED;
 
}

mixed internal_command( string receiver, int command, mapping parameters )
{
   array split =  split_server_module_sensor_value( receiver );
   //Check if the command is voor DML and it's sibblings, or for
   //the WebServer
   if ( sizeof (split) > 1 && split[1] == "DML" ) 
   {
     //TODO
   }
   else
     return webserver->internal_command( receiver, command, parameters);
}



void logerror( mixed ... args )
{
   webserver->log(LOG_ERR,@args);
}

void logdebug( mixed ... args )
{
   webserver->log(LOG_DEBUG,@args);
}

string parse_dml(string content, mixed ... args )
{
   object p = parser->clone();
   p->set_extra(@args);
   return p->finish(content)->read();
}
