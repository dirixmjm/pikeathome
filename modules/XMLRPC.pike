#include <module.h>
inherit Module;

#define XXMLRPCDEBUG
int module_type = MODULE_INTERFACE;
string module_name = "XMLRPC";

protected object HTTPServer;

void module_init(  )
{

#ifdef XMLRPCDEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"Create Interface\n");
#endif
   HTTPServer = Protocols.HTTP.Server.Port( http_callback, (int) configuration->port);
}

void close()
{
   HTTPServer->close();
   configuration = 0;
   domotica = 0;
}   

void http_callback( Protocols.HTTP.Server.Request request )
{
   object call;
   call  = Protocols.XMLRPC.decode_call(request->body_raw);
   array answer = ({});
#ifdef XMLRPCDEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"XMLRPC Received call %s\n",call->method_name);
#endif
   switch(call->method_name)
   {
      case "modules":
         answer = domotica->modules;
         break;
      case "sensors":
         answer = domotica->sensors;
         break;
      case "sensor.info":
         foreach( call->params, mapping sensor )
         {
            //FIXME What if the sensor doesn't exist?
               answer += ({ domotica->info(sensor->name, sensor["new"] ) });
         }
         break;
      case "sensor.write":
         if ( ! sizeof(call->params) )
            break;
         foreach( call->params, mapping sensor )
         {
            if ( has_value(domotica->sensors, sensor->name ) )
               answer +=({  ([ "name":sensor->name, 
                "state": domotica->write(sensor->name,sensor)
                              ])
                         });
         }
         break;
   }
   mapping response;
   if ( sizeof(answer) )
         response = ([ "data": Protocols.XMLRPC.encode_response(answer) ]);
   else
         response = ([ "error":404 ]);
   request->response_and_finish(response);
}
