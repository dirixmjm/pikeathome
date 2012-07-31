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

object configuration;
object HTTPServer;
object dmlparser;
object Configparser;
mapping run_config;
protected object Config;

protected string name="";

constant defvar = ({
                   ({ "port",PARAM_STRING,"8080","Listen Port",POPT_RELOAD }),
                   ({ "username",PARAM_STRING,"","Username",0 }),
                   ({ "password",PARAM_STRING,"","Password",0 }),
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

   if ( !has_index(run_config, "webpath" ))
   {
      log(LOG_ERR,"No webpath undefined in config file, exiting\n");
      exit(11);
   }
   if ( !has_index(configuration, "port" ))
   {
      log(LOG_ERR,"No Port defined, using default port 8080\n");
      configuration["port"]="8080";
   }
   if( !has_index(configuration,"username") && has_index(run_config,"username" ) )
      configuration["username"]=run_config->username;
   if( !has_index(configuration,"password") && has_index(run_config,"password" ) )
      configuration["password"]=run_config->password;
   if( !has_index(configuration,"xmlrpcserver" ))
      configuration->xmlrpcserver=run_config->xmlrpcserver;

   //Start webserver.
   dmlparser = master()->resolv("DML")( name, this , run_config, Config );
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
          return dmlparser->parse(request,data);
       }
       else
          return Stdio.File(run_config->webpath + request->not_query,"R");
    }
    else
       return 0;
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

mixed internal_command( string method, int command, mapping parameters )
{
   switch(command)
   {
      case COM_PARAM:
      array server_module_split =  split_module_sensor_value( method );
      if( sizeof(server_module_split) == 1  )
      {
         array var = ({});
         foreach( defvar, array thisvar )
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
      else
      {
         //FIXME make interface for module variables
         return ({});
      }
      break;
      case COM_LIST:
      if( parameters && has_index(parameters, "new" ) )
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
               failed_modules+= ({ ([ "module":name, "error":"Compilation Failed" ]) });
#ifdef DEBUG
         log(LOG_ERR,"Error:%O\n",catch_result);
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
         return compiled_modules+failed_modules;
      }
      else
      {
         return configuration->module +({});
      }
      break;
      case COM_ADD:
      {
         string module_name = name+"."+parameters->name;
         m_delete(parameters,"name");
         if( configuration->module && has_value( configuration->module, module_name ) )
         {
            log(LOG_ERR, "There already exists a module instance with name %s\n",module_name);
            return ([ "error":sprintf("There already exists a module instance with name %s\n",module_name)]);

         }
         configuration->module+=({module_name});
         object cfg = Config->Configuration(module_name);
         foreach( parameters; string index; mixed value )
            cfg[index]=value;
         dmlparser->init_modules( ({ module_name }));
         return UNDEFINED;
      }
      break;
      default:
         log(LOG_ERR,"Unknown Command %d\n",command);
         return ([ "error":sprintf("Unknown Command %d\n",command) ]);
   }
}

mixed xmlrpc( string method, int command, mapping|void parameters )
{
   //Check if the method is internal
   if ( method == name || has_prefix( method, name ) )
   {
      return internal_command(method, command,parameters );
   }

   //FIXME, maybe have multiple servers, with different names?

#ifdef DEBUG
   log(LOG_DEBUG,"XMLRPC: Send Request %s %d\n",method, command );
   log(LOG_DEBUG,"XMLRPC: %O\n",parameters );
#endif
   string data = Protocols.XMLRPC.encode_call(method,({command,parameters}) );
   object req = Protocols.HTTP.do_method("POST",
                                           run_config->xmlrpcserver,0,
                                           (["Content-Type":"text/xml"]),
                                           0,data);
   if(!req)
   {
      log(LOG_ERR,"XMLRPC: Lost Connection\n" );
      return UNDEFINED;
   }
   if(req->status != 200 )
   {
      log(LOG_ERR,"XMLRPC: Server returned with \"%d\"\n",req->status );
      return UNDEFINED;
   }
#ifdef DEBUG
   log(LOG_DEBUG,"XMLRPC: %O\n",Protocols.XMLRPC.decode_response(req->data() ));
#endif
   array res = Protocols.XMLRPC.decode_response(req->data());
   if( mappingp( res[0] ) && has_index(res[0],"error") )
      log(LOG_ERR,"XMLRPC: Server returned with \"%s\"\n",res[0]->error );
   return res[0];
}

void log( int log_level, string format, mixed ... args )
{
   System.syslog( log_level, sprintf(format,@args) );
#ifdef DEBUG
      Stdio.stdout.write(format,@args);
#endif
}

