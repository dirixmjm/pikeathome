#include <module.h>
#include <command.h>
inherit Base_func;
inherit Module;

int module_type = MODULE_INTERFACE;

constant ModuleParameters = ({
                   ({ "listenaddress",PARAM_STRING,"127.0.0.1","Listen Address", POPT_RELOAD }),
                   ({ "port",PARAM_STRING,"8000","Listen Port",POPT_RELOAD }),
                   ({ "timeout",PARAM_STRING,"128","Connection Timeout",0}),
                   ({ "webpath",PARAM_STRING,"","Physical Web Location",POPT_RELOAD }),
                   ({ "username",PARAM_STRING,"","Username",0 }),
                   ({ "password",PARAM_STRING,"","Password",0 }),
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

void create( string _name, object _configuration, object _module, Protocols.HTTP.Server.Request _request )
{
   name = _name;
   configuration = _configuration;
   module = _module;
   request = _request;
   //FIXME Check Auth.
   string filename = Protocols.HTTP.uri_decode(request->not_query);
    while(has_prefix(filename,"/"))
       filename = filename[1..];
   //FIXME Is this save, how about "../" ?
   if ( Stdio.is_file( configuration->webpath + filename ) )
   {
      request->response_and_finish( ([
                                 "file":Stdio.File(configuration->webpath + filename,"R"),
                                 "server":module->htmlservername ]) );
      call_out(request_done,0,name);
   }
   else if ( Stdio.is_dir(configuration->webpath+filename) && Stdio.is_file( configuration->webpath + filename + "/index.html" ) )
   {
      request->response_and_finish( ([
                                 "type":"text/html",
                                 "file":Stdio.File(configuration->webpath + filename+"/index.html","R"),
                                 "server":module->htmlservername ]) );
      call_out(request_done,0,name);
   }
   else if ( has_suffix(filename, "json") )
   {
      if ( ! has_index(request->variables,"command") || ! has_index(request->variables,"receiver" ) )
      {
         logerror("Received JSON query without the necessary parameters\n");
         return_not_found();
      }
      else
      {
         //FIXME use connection_timeout_delay?
         logdebug("JSON connection timeout delay %d\n",request->connection_timeout_delay);
         logdebug("JSON send timeout delay %d\n",request->send_timeout_delay);
         call_out(return_not_found,(int) (configuration->timeout?configuration->timeout:128));
         //FIXME Sanity check variables!
         switchboard(name,(string) request->variables->receiver,(int) request->variables->command,request->variables->parameters?request->variables->parameters:([]));
      }
   }
   else
      return_not_found();
}


void rpc_command( string sender, string receiver, int command, mapping|array parameters )
{
   remove_call_out( return_not_found );
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
      if ( mappingp(parameters) )
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

protected void return_not_found()
{
   request->response_and_finish( ([
                                 "data":"File Not Found",
                                 "error":404,
                                 "type":"text/plain",
                                 "server":module->htmlservername ]));
   call_out(request_done,0,name);
}

protected void return_data_and_finish(array parameters)
{
   request->response_and_finish( ([
                                 "data":Standards.JSON.encode(parameters,2),
                                 "type":"text/plain",
                                 "server":module->htmlservername ]));
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
   module->logdebug(@args);
}

void logerror(mixed ... args)
{
   module->logerror(@args);
}

}
