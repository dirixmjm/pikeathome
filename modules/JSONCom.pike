#include <module.h>
#include <command.h>
inherit Base_func;
inherit Module;

int module_type = MODULE_INTERFACE;

constant ModuleParameters = ({
                   ({ "debug",PARAM_BOOLEAN,0,"Turn On / Off Debugging",POPT_NONE }),
                   ({ "listenaddress",PARAM_STRING,"127.0.0.1","Listen Address", POPT_RELOAD }),
                   ({ "port",PARAM_STRING,"8000","Listen Port",POPT_RELOAD }),
                   ({ "timeout",PARAM_STRING,"128","Connection Timeout",0}),
                   ({ "webpath",PARAM_STRING,"","Physical Web Location",POPT_RELOAD }),
                   ({ "users",PARAM_MAPPING,([]),"Username and Password",0 }),
                   ({ "origin",PARAM_ARRAY,({}),"Webserver URLs (CORS)",0 }),
                    });

protected object HTTPServer;

constant htmlservername = "Pike At Home JSON HTTP Server";

void init()
{
   logdebug("Init JSONCom Interface\n");
   //Check if webpath is configured and available.
   if ( !configuration->webpath || ! sizeof( configuration->webpath ) 
                                || !file_stat(configuration->webpath) )
   {
      logerror("Web path not specified or found, not opening port\n");
      return;
   }
   HTTPServer = Protocols.HTTP.Server.Port( http_callback, 
                 sizeof(configuration->port)?configuration->port:8000, 
                 sizeof(configuration->listenaddress)?configuration->listenaddress:"0.0.0.0");
}

void http_callback( Protocols.HTTP.Server.Request request )
{
   //FIXME does time(1) differentiate enough between requests?
   logdebug("JSONCom Request\n%O\n",request->request_headers);
   string sensorname = ModuleProperties->name + "." + (string) time(1);
   RequestHandler RQH = RequestHandler( sensorname, configuration, this, request);
   sensors+=([ sensorname:RQH ]); 
   return;
}

void request_done(string sensorname)
{
   destruct(sensors[sensorname]);
   m_delete(sensors,sensorname);
}

/*The request handler acts as a sensor having only a short lifetime
* since the module has not MODULE_SENSOR set, it should not be shown in
* the sensor list
*/
class RequestHandler
{

protected object configuration;
protected string name;
protected object module;
protected Protocols.HTTP.Server.Request request;
protected mapping NextToken = ([]);

void create( string _name, object _configuration, object _module, Protocols.HTTP.Server.Request _request )
{
   name = _name;
   configuration = _configuration;
   module = _module;
   request = _request;
   //Check if Token is not expired:
   if ( !checkauth() )
     return;
   //Error no Auth, send token
   if ( ! has_index(request->variables,"command") || ! has_index(request->variables,"receiver" ) )
   {
      logerror("Received JSON query without the necessary parameters\n");
      return_error("Unknown Command");
   }
   else
   {
      //FIXME use connection_timeout_delay?
      logdebug("JSON connection timeout delay %d\n",request->connection_timeout_delay);
      logdebug("JSON send timeout delay %d\n",request->send_timeout_delay);
      call_out(return_error,(int) (configuration->timeout?configuration->timeout:128),"Request TimeOut");
      //FIXME Sanity check variables!
      switchboard(name,(string) request->variables->receiver,(int) request->variables->command,request->variables->parameters?request->variables->parameters:([]));
   }
}

int checkauth()
{
  //Check if a token is present, and validate
  if ( has_index( request->variables, "username" ) && 
       has_index( request->variables,"password") && 
       has_index( configuration->users, request->variables->username) && 
       configuration->users[request->variables->username] == request->variables->password )
  {
           return 1;
  }
  logdebug("No Auth\n");
  return_no_auth();
  return 0;
}



void rpc_command( string sender, string receiver, int command, mapping|array parameters )
{
   remove_call_out( return_error );
   if( command > 0 )
   {
      switch(command)
      {
      case COM_ERROR:
         //logerror(parameters->error);
         //Send Error to the client
         return_data_and_finish(parameters);
         break;
      default:
         logerror("%s is trying to communicate with fake sensor in JSON module\n",sender);
         call_out(request_done,0,name);
      }
   }
   else
   {
      //FIXME sanity check command?
      array answer = ({});
      //FIXME maybe change all return code to resemble array(mapping)?
      if ( (command == -2) && mappingp(parameters) )
      {
         foreach( indices(parameters), string paramindex )
         {
            if ( mappingp(parameters[paramindex]) )
               answer+= ({ ([ "name":paramindex])+parameters[paramindex] });
            else if ( stringp(parameters[paramindex]) 
                         || intp(parameters[paramindex]) || floatp(parameters[paramindex]  ))
               answer+= ({ ([ "name":paramindex, 
                                     "value":parameters[paramindex]  ]) });
         }
      }
      else
         answer = parameters;
      return_data_and_finish(answer);
   }
}

protected void return_no_auth()
{
   mapping extra_heads = ([
                            "WWW-Authenticate":"Basic realm=\"User\""
                           ]);
   if ( has_index(request->request_headers,"origin" ) &&
        has_index(configuration,"origin" ) &&
        has_value(configuration->origin, request->request_headers->origin) )
   {
        extra_heads += (["Access-Control-Allow-Origin":request->request_headers->origin]);
   }
   else if ( has_index(request->request_headers,"origin" ) )
   {
      logerror("Untrusted origin %s\n",request->request_headers->origin );
   }

   request->response_and_finish( ([
                                 "data":"{\"error\":\"No Auth\"}",
                                 "type":"text/plain",
                                 "error":401,
                                 "server":module->htmlservername,
                                 "extra_heads": extra_heads 
                                  ]));
   call_out(request_done,0,name);
}

protected void return_error(string _error)
{
   mapping extra_heads = ([]);
   if ( has_index(request->request_headers,"origin" ) &&
        has_index(configuration,"origin" ) &&
        has_value(configuration->origin, request->request_headers->origin) )
   {
        extra_heads += (["Access-Control-Allow-Origin":request->request_headers->origin]);
   }
   else if ( has_index(request->request_headers,"origin" ) )
   {
      logerror("Untrusted origin %s\n",request->request_headers->origin );
   }
   request->response_and_finish( ([
                                 "data":"{\"error\":\""+_error+"\"}",
                                 "type":"text/plain",
                                 "error":500,
                                 "server":module->htmlservername,
                                 "extra_heads": extra_heads 
                                 ]));
   call_out(request_done,0,name);
}

protected void return_data_and_finish(array parameters)
{
   mapping extra_heads = ([]);
   if ( has_index(request->request_headers,"origin" ) &&
        has_index(configuration,"origin" ) &&
        has_value(configuration->origin, request->request_headers->origin) )
   {
        extra_heads += (["Access-Control-Allow-Origin":request->request_headers->origin]);
   }
   else if ( has_index(request->request_headers,"origin" ) )
   {
      logerror("Untrusted origin %s\n",request->request_headers->origin );
   }
   request->response_and_finish( ([
                                 "data":Standards.JSON.encode(parameters,2),
                                 "type":"text/plain",
                                 "server":module->htmlservername,
                                 "extra_heads": extra_heads 
                                 ]));
   call_out(request_done,0,name);
}

/*
* Helper Function for sensors to call the switchboard
*/
void request_done ( string name )
{
   call_out(module->request_done,0,name);
}

void switchboard ( mixed ... args )
{
   module->switchboard( @args );
}

void logdebug(mixed ... args)
{
   werror("logit\n");
   module->logdebug(@args);
}

void logerror(mixed ... args)
{
   module->logerror(@args);
}

}
