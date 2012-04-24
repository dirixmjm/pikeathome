#define XMLRPCDEBUG
#include <module.h>

string module_name = "XMLRPC";

protected object HTTPServer;
object domotica,configuration;

void create( string URI, object Domo )
{
   domotica = Domo;
   configuration = domotica->configuration(module_name);
#ifdef DEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"Init XMLRPC Interface\n");
#endif
   Standards.URI U = Standards.URI(URI);

   HTTPServer = Protocols.HTTP.Server.Port( http_callback, (int) U->port?U->port:4096, U->host?U->host:"127.0.0.1" );
//FIXME Check if interface is open.
#ifdef XMLRPCDEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"Create Interface Port %d\n", U->port?U->port:4096);
#endif

}


void close()
{
   HTTPServer->close();
   configuration = 0;
   domotica = 0;
}   

//FIXME Create better error / failure reporting.
void http_callback( Protocols.HTTP.Server.Request request )
{
   object call;
   call  = Protocols.XMLRPC.decode_call(request->body_raw);
   array answer = ({});
#ifdef XMLRPCDEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"XMLRPC Received call %s with command %O\n",call->method_name,call->params[0]);
#endif
   call_out(domotica->switchboard,0, call->method_name, call->params[0], call->params[1], xmlrpcanswer, request);
}

void xmlrpcanswer( array|mapping|int|float|string answer, object request )
{
#ifdef XMLRPCDEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"XMLRPC Sending Answer %O\n",answer);
#endif
   if(!request)
      domotica->log(LOG_EVENT,LOG_ERR,"XMLRPC Lost connection\n");

   //FIXME Handle Errors.
   mapping response = ([ "data": Protocols.XMLRPC.encode_response(({ answer })) ]);
   request->response_and_finish(response);
}
