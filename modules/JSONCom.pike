#include <module.h>
#include <command.h>
inherit Base_func;
inherit Module;

int module_type = MODULE_INTERFACE;

constant ModuleParameters = ({
                   ({ "listenaddress",PARAM_STRING,"","Listen Address", 0 }),
                    });

protected object HTTPServer;
string name;

void init()
{
   logdebug("Init JSONCom Interface\n");
   Standards.URI U = Standards.URI(configuration->listenaddress);
   Protocols.HTTP.Server.Port HTTPServer = Protocols.HTTP.Server.Port( http_callback, U->port?U->port:4090, U->host?U->host:"127.0.0.1");
}

mapping sockets = ([]);

void http_callback( Protocols.HTTP.Server.Request request )
{
   while(has_prefix(request->not_query,"/"))
      request->not_query = request->not_query[1..];
   if ( request->not_query=="" )
   {
      request->response_and_finish( ([ 
                               "data": "<title>No Sensor Provided</title>",
                               "error":404
                                    ]) );
      return;
   }
   //remove any trailing "/"
   while(has_suffix(request->not_query,"/"))
      request->not_query = request->not_query[..sizeof(request->not_query)-2];
   //Replace "/" by ".".
   string smsv = replace(request->not_query,"/",".");
   //If the servername is missing add it, and with that constrain requests to this server.
   smsv = servername + "." + smsv;
   //Store the connection for the reply. The index is the fake sensor name
   string peername = (string) time(1); 
   sockets+= ([ peername: request]);
   //Fake add a sensor, such that we recognize the answer for the correct peer.
   switchboard(ModuleProperties->name+"."+peername,smsv,COM_READ,([]));
   return;
}

void deletepeer(string peername)
{
   m_delete(sockets,peername);
}

void got_answer( string receiver, string sender, int command, mapping parameters )
{
   array receiver_split = split_server_module_sensor_value(receiver);
   if ( sizeof(receiver_split) > 2 )
   {
      if( has_index( sockets, receiver_split[2] ))
      {
         sockets[receiver_split[2]]->response_and_finish( ([
                         "data":Standards.JSON.encode(parameters) ]));
         deletepeer(receiver_split[2]);
      }
      else
         logerror("JSONCom: Unknown receiver %s\n",receiver);
   }
}
