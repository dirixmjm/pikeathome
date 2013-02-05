// Copyright (c) 2009-2010, Marc Dirix, The Netherlands.
//                         <marc@electronics-design.nl>
//
// This script is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//
#include <syslog.h>
#include <parameters.h>
#include <command.h>

inherit Base_func;

object configuration;
object HTTPServer;
object dml;
object Configparser;
mapping run_config;
protected object Config;

protected string name="";

constant ServerParameters = ({
                   ({ "port",PARAM_STRING,"8080","Listen Port",POPT_RELOAD }),
                   ({ "username",PARAM_STRING,"","Username",0 }),
                   ({ "password",PARAM_STRING,"","Password",0 }),
                   ({ "peers",PARAM_MAPPING,"","Server Peer URLs",0}),
                   ({ "inlineconfig",PARAM_BOOLEAN,0,"Show Configuration Parameters Inline",0}),
                   ({ "debug",PARAM_BOOLEAN,0,"Show Debug Information",0}),
                   });

void create( mapping rconfig )
{
   //Get basic parameters: run_config 
   run_config=rconfig; 
   name = run_config->name;
   //Open Log.
   System.openlog("pikeathomewebserver",LOG_PID,LOG_DAEMON);
   //Open config database.
   Config = master()->resolv("Config")( run_config->database );
   //Open Webserver configuration
   configuration = Config->Configuration(name);

   //Webpath and port are the static values leading, so changes
   // to both take effect after restart. Maybe they shouldn't even
   // be in the dynamic configuration
   if ( !has_index(run_config, "webpath" ))
   {
      log(LOG_ERR,"No webpath undefined in config file, exiting\n");
      exit(11);
   }

   configuration->webpath=run_config->webpath;

   if ( !has_index(configuration, "port" ))
   {
      log(LOG_ERR,"No Port defined, using default port 8080\n");
      configuration["port"]="8080";
   }

   //The dynamic values here can be newer then the static ones.
   if( !has_index(configuration,"username") && has_index(run_config,"username" ) )
      configuration["username"]=run_config->username;
   if( !has_index(configuration,"password") && has_index(run_config,"password" ) )
      configuration["password"]=run_config->password;

   //Open the dml parser
   dml = master()->resolv("DML")( name, this , run_config, Config );

   //Start webserver.
   log(LOG_DEBUG,"Create Web Interface Port %d\n",(int) configuration->port );
   HTTPServer = Protocols.HTTP.Server.Port( http_callback, (int) configuration->port);


}

void http_callback( Protocols.HTTP.Server.Request request )
{
   mapping response = ([ "server":"Domotica DML Webserver" ]);
   //Check Auth. Require only auth if username is set in the database.
   //FIXME add multiple auth and user management
   if( has_index(configuration,"username") )
   {
      string auth = "Basic "+ MIME.encode_base64(configuration->username +":"+configuration->password);
      if ( !has_index( request->request_headers, "authorization" ) ||
           request->request_headers["authorization"] != auth)
      {
         response += ([
                             "data": "<title>Access Denied</title><h2 align=center>Access Denied</h2>",
                             "error":401,
                             "extra_heads": ([ "WWW-Authenticate":"Basic realm=\"User\""]),
                           ]);
         request->response_and_finish( response );
         return;
      }
   }

   Stdio.File req = find_file(request);
   if ( ! req )
   {
      string data = "No such file";
      response += ([ "data":data,"error":404,"type":"text/plain" ]);
   }
   else
   {
      if ( req->is_dml_file )
      {
         response+= ([ "type":req->file_type ]);
         response+=([ "file":req,"error":req->return_code ]);
         response+= ([ "extra_heads":req->return_data ]);
      }
      else
         response+=([ "file":req ]);
   }
   request->response_and_finish(response);
}

Stdio.File find_file(object request)
{
    while(has_prefix(request->not_query,"/"))
       request->not_query = request->not_query[1..];
    if( request->not_query=="" )
       request->not_query="index.dml";
    request->not_query = replace(request->not_query,({"%20"}),({" "}));
    if ( Stdio.is_file( run_config->webpath + request->not_query ) )
    {
       array v = request->not_query/".";
       if ( sizeof(v) >= 2 && v[-1]=="dml" )
       {
          string data = Stdio.read_file(run_config->webpath + request->not_query );
          return dml->parse(request,data);
       }
       else
          return Stdio.File(run_config->webpath + request->not_query,"R");
    }
    else
       return 0;
}

mixed internal_command( string receiver, int command, mapping parameters )
{
   array split = split_server_module_sensor_value(receiver);
   switch(command)
   {
      case COM_PARAM:
      {
        if ( parameters && mappingp(parameters) )
        {
            foreach(ServerParameters, array var)
            {
               if( has_index( parameters, var[0] ) )
                  configuration[var[0]] = parameters[var[0]];
            }
         }
         array ret = ({});
         foreach(ServerParameters, array var)
            ret+= ({ var + ({ configuration[var[0]] }) });
         return ret;
      }
      break;
      case COM_WRITE:
      if( sizeof(split) > 1 && split[1] == "parameters" && parameters)
      {
         array var = ({});
         foreach( ServerParameters, array thisvar )
         {
            //Set parameters if given
            if(parameters && has_index(parameters,thisvar[0] ) )
               configuration[thisvar[0]]=parameters[thisvar[0]];

            if( has_index( configuration, thisvar[0] ) )
               var += ({ thisvar + ({ configuration[thisvar[0]] }) });
            else
               var += ({ thisvar });
         }
         return var;
      }
      case COM_LIST:
         return configuration->module + ({ name + ".DML" });
      break;
      case COM_FIND:
      {
         array compiled_modules = ({});
         array failed_modules = ({});
         object moddir = Filesystem.Traversion(run_config->installpath+"/modules" );
         foreach( moddir; string dirname; string filename )
         {
            string name="";
            if( !has_suffix(filename,".pike")) continue;
            sscanf(filename,"%s\.pike",name);
            object themodule;
            mixed catch_result = catch {
               themodule = compile_file(dirname+filename)(name,this);
            };
            if( catch_result)
            {
               failed_modules+= ({ ([ "name":name, "error":"Compilation Failed" ]) });
#ifdef DEBUG
         log(LOG_ERR,"Error:%O\n",catch_result);
#endif
            }
            else
            {
               compiled_modules += ({ ([ "name":name,
                             "parameters":themodule->ModuleParameters +
                             ({  })
                              ]) });
            }

         }
         return compiled_modules+failed_modules;
      }
      break;
      case COM_ADD:
      {
         string module_name = name+"."+parameters->name;
         mapping params = parameters->parameters+([]);
         if( configuration->module && has_value( configuration->module, module_name ) )
         {
            log(LOG_ERR, "There already exists a module instance with name %s\n",module_name);
            return ([ "error":sprintf("There already exists a module instance with name %s\n",module_name)]);

         }
         configuration->module+=({module_name});
         object cfg = Config->Configuration(module_name);
         foreach( params; string index; mixed value )
            cfg[index]=value;
         dml->init_modules( ({ module_name }));
         return UNDEFINED;
      }
      break;
      default:
         log(LOG_ERR,"Unknown Command %d\n",command);
         return ([ "error":sprintf("Unknown Command %d\n",command) ]);
   }
}

void log( int log_level, string format, mixed ... args )
{
   System.syslog( log_level, sprintf(format,@args) );
#ifdef DEBUG
      Stdio.stdout.write(format,@args);
#endif
}

