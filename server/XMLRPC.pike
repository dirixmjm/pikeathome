#define XMLRPCDEBUG
#include <module.h>
#define MAXREQUESTTIME 30

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

//FIMXE prune the request_buffer with timeouts?
void request_timeout()
{
   foreach( request_buffer; string key;  array reqs )
   {
      array req_out = ({});
      foreach( reqs, mapping req )
      {
         if ( req->time < time()+MAXREQUESTTIME )
         {
            destruct(req->request );
         }
         else
            req_out+= ({ req } );
      }
      if( sizeof(req_out) )
         request_buffer[key] = req_out;
      else
         m_delete(request_buffer, key);
   }
}

mapping request_buffer = ([]);

//FIXME Create better error / failure reporting.
void http_callback( Protocols.HTTP.Server.Request request )
{
   object call;
   call  = Protocols.XMLRPC.decode_call(request->body_raw);
   array answer = ({});
#ifdef XMLRPCDEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"XMLRPC Received call %s with command %O\n",call->method_name,call->params[0]);
#endif
   mapping req = ([ "time":time(1), "request":request ]);
   request_buffer[call->method_name] += ({ req });
   call_out( request_timeout, MAXREQUESTTIME );   
   //switchboard( sender, receiver, command, parameters)
   switchboard("xmlrpc", call->method_name, call->params[0], call->params[1]);
}



void rpc_command( string sender, string receiver, int command, mapping parameters )
{
   //Maybe the request timed out.
   if( !has_index( request_buffer, sender ) )
   {
      return;
   }

   foreach( request_buffer[sender], mapping req )
   {
      //We don't check for internal timeout here, because if we have the value
      //we might as well return it.
      if(!req->request)
         domotica->log(LOG_EVENT,LOG_ERR,"XMLRPC Lost connection\n");
      else
         xmlrpcanswer( parameters, req->request );
   }
   //At this point all requests for this sender should have been handled.
   m_delete( request_buffer, sender);
}

void xmlrpcanswer( array|mapping|int|float|string answer, object request )
{
#ifdef XMLRPCDEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"XMLRPC Sending Answer %O\n",answer);
#endif

   //FIXME Handle Errors. 
   //FIMXE Handle UNDEFINED answer.
   mapping response = ([ "data": Protocols.XMLRPC.encode_response(({ answer })) ]);
   request->response_and_finish(response);
}


/*
* Helper Function for sensors to call the switchboard
*/
void switchboard ( mixed ... args )
{
   call_out( domotica->switchboard,0, @args );
}
