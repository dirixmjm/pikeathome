#define XMLRPCDEBUG
#include <module.h>

inherit Base_func;

protected object HTTPServer;
protected object dml,configuration;

void create( object dml_, object configuration_)
{
   dml = dml_;
   configuration=configuration_;
#ifdef DEBUG
   logdebug("Init XMLRPC Interface\n");
#endif
   Standards.URI U = Standards.URI(configuration->listenaddress);

   HTTPServer = Protocols.HTTP.Server.Port( http_callback, (int) U->port?U->port:4096, U->host?U->host:"127.0.0.1" );
//FIXME Check if interface is open.
#ifdef XMLRPCDEBUG
   logdebug("Create Interface Port %d\n", U->port?U->port:4096);
#endif

}


void close()
{
   HTTPServer->close();
}   

void http_callback( Protocols.HTTP.Server.Request request )
{
   object call;
   call  = Protocols.XMLRPC.decode_call(request->body_raw);
   array answer = ({});
#ifdef XMLRPCDEBUG
   logdebug("XMLRPC Received call %s with command %O\n",call->method_name,call->params[0]);
#endif
   //switchboard( sender, receiver, command, parameters)
  //FIXME amend for bidirectional communication
   if ( call->params[0] != COM_ANSWER )
   {
      logerror("The Webserver does not handle requests\n");
   }
   cache[ call->params[1]] = call->params[3];
   request->response_and_finish((["data":"Ok"]));
   werror("%O\n",cache);
}

mapping cache=([]);

mixed switchboard ( string receiver, int command, mixed|void parameters)
{
#ifdef DEBUG
   logdebug("XMLRPC: Send Request %s %d\n",receiver, command );
   logdebug("XMLRPC: %O\n",parameters );
#endif

   array split = split_module_sensor_value(receiver);
   if( split[0] == dml->servername )
      return dml->switchboard(receiver,command,parameters);

   //external host, check if we know the host and do a query
   if( !has_index( configuration->peers, split[0] ) )
   {
      logerror("Unknown peer %s\n",split[0]);
      return UNDEFINED;
   }
   string data = Protocols.XMLRPC.encode_call(receiver,({command,
                dml->servername,configuration->listenaddress,parameters}) );
   object req = Protocols.HTTP.do_method("POST",
                                           configuration->peers[split[0]],0,
                                           (["Content-Type":"text/xml"]),
                                           0,data);
   if(!req)
   {
      logerror("XMLRPC: Lost Connection\n" );
      return UNDEFINED;
   }
   if(req->status != 200 )
   {

      logerror("XMLRPC: Server returned with \"%d\"\n",req->status );
      return UNDEFINED;
   }

   // always return the cached value
   // do split caching
   if ( has_index( cache, receiver ) )
     return cache[receiver];
  else
     return UNDEFINED;
}
