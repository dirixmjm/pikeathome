#include <command.h>
#include <module.h>
#include <sensor.h>
#include <variable.h>

//inherit Base_func;
inherit DMLModule;

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

//Mapping holding the webserver modules
protected mapping  modules=([]);

string servername;
Parser.HTML parser;

constant ModuleParameters = ({
                   });

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

   parser = DMLParser(tags,containers);
   //parser->add_tags(tags);
   //parser->add_containers(containers);
   parser->add_entity ( "lt", 0);
   parser->add_entity ( "gt", 0 );
   parser->add_entity("amp",0);
   parser->_set_entity_callback( entity_callback );
   //parser->lazy_entity_end(1);

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
         logerror("Error Module INIT\n %O\n%s\t\t%s\n%O\n",catch_result,name,describe_error(catch_result),backtrace());
         continue;
      }
      modules+=([ name:mod ]);
      parser->add_tags(mod->tags);
      parser->add_containers(mod->containers);
      emit += mod->emit; 
   }
}


array entity_callback(Parser.HTML p, 
               string entity, mapping query )
{
   string variable;
   sscanf(entity,"&%s;",variable);
   mixed val = resolve_entity(variable,query);
   if ( zero_type(val) )
      return ({ entity });
   else 
      return ({ (string) val });
}

mixed resolve_entity(string entity, mapping query )
{
   array split = split_server_module_sensor_value(entity);
   //FIXME should this not also search for server-values?
   if( !split || sizeof(split) < 2 )
      return UNDEFINED;
   //First check if the value fits in the webserver dynamic scope.
   if( sizeof(split) == 2 && has_index( query->entities, split[0] ) )
   {
      if( has_index( query->entities[split[0]],split[1] ))
         return  query->entities[split[0]][split[1]];
      else
         return UNDEFINED;
   }
   //Only server.module.variable or server.sensor.variable allowed.
   //So local scope (sizeof(split) ==2) doesn't get mixed
   else if ( sizeof(split) >= 3 )
   {
      mapping ett =  rpc( entity, COM_READ);
      if( ett )
         return ett->value;
      else 
         return UNDEFINED;
   }
   else
      return UNDEFINED;
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
   array sensors = ({});
   if( has_index( args, "name" ) )
     sensors = rpc( args->name, COM_ALLSENSOR ) || ({}); 
   else 
   {
      foreach ( indices(configuration->peers || ({})), string peername )
         sensors+= rpc( peername, COM_ALLSENSOR ) || ({});
   }
   if ( has_index( args, "sort" ) )
   {
      sensors=sort(sensors);
   }
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
      mapping Variable_Data = rpc( args->name, COM_READ );
      if( !Variable_Data )
         return ({});
      foreach( Variable_Data; string Var; mapping Data )
      {
         res+= ({ ([ "variable":Var]) + Data });
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
      //FIXME this should be made independant of spaces.
      array arr = args->variable/" ";
      if ( sizeof(arr) == 1 )
      {
            if( resolve_entity(arr[0],query)) 
               return content;
            else
               return "";
      }
      else if ( sizeof(arr) == 2 )
      {
         return "";
      }
      else if ( arr[1] == "=" || arr[1] == "==" || arr[1] == "is" )
      {
         string var = (string) resolve_entity(arr[0],query);
         string is = arr[2..]*" ";
         if ( var == is )
            return content;
         else 
            return "";
      } 
      else if ( arr[1] == "!=" ) 
      {
         string var = (string) resolve_entity(arr[0],query);
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
   if ( has_index( args, "variable" ) && has_index( args, "from" ) )
   {
      string value = (string) resolve_entity(args->from,query);
      set_entity( value, args->variable, query);
   }
   if ( has_index( args, "variable" ) && has_index( args, "value" ) )
   {
      set_entity( args->value, args->variable, query);
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

/*
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
*/

void switchboard( string sender, string receiver, int command, mixed|void parameters)
{
#ifdef DEBUG
   logdebug("RPC: Receive Request %s %d\n",sender, command );
   logdebug("RPC: %O\n",parameters );
#endif
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
   else if ( parameters || zero_type(parameters)==0 ) 
   {
     rpc_cache[sender][abs(command)]->data=parameters;
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
   if( !has_index(rpc_cache, receiver) || 
       !has_index(rpc_cache[receiver],command) ) 
   {
      if( !has_index(rpc_cache, receiver) )
         rpc_cache[receiver]= ([]);
      rpc_cache[receiver][command] = ([ "timeout":time(1),"data":UNDEFINED ]);
      call_out(ICom->rpc_command,0, receiver, command, parameters);
   }
   else if (rpc_cache[receiver][command]->timeout <= (time(1)-10))
   {
      call_out(ICom->rpc_command,0, receiver, command, parameters);
   }
   
   // always return the cached value
   mixed toret = rpc_cache[receiver][command]->data;

   return toret;
 
}

mixed internal_command( string receiver, int command, mapping parameters )
{
   array split =  split_server_module_sensor_value( receiver );
   //Check if the command is for the WebServer
   if ( sizeof (split) == 1 ) 
   {
     return webserver->internal_command( receiver, command, parameters);
   }
   else if ( split[1] == "DML" )
   {
      switch(command)
      {
         case COM_PARAM:
         {
            if( parameters && mappingp(parameters) )
               SetParameters(parameters);
            return GetParameters();
         }
      }
   }
   else if ( has_index ( modules, receiver ) )
   {
      switch(command)
      {
         case COM_PARAM:
         {
            if( parameters && mappingp(parameters) )
               modules[receiver]->SetParameters(parameters);
            return modules[receiver]->GetParameters();
         }
         break;
      }
   }
   else
   {
      logerror("Unknown Modules %s\n",receiver);
   }
   
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
