// Copyright (c) 2009-2010, Marc Dirix, The Netherlands.
//                         <marc@electronics-design.nl>
//
// This script is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//
#include <syslog.h>

object configuration;
object HTTPServer;
object dmlparser;

void create( array run_config )
{
   //Open Log.
   System.openlog("pikeathomewebserver",LOG_PID,LOG_DAEMON);
   //Open config.
   object config = master()->resolv("Config")( run_config->database );
   configuration = config->Configuration("WebServer");
   //Start webserver.
   dmlparser = master()->resolv("DML")( this , configuration );
   log(LOG_DEBUG,"Create Web Interface Port %d\n",(int) configuration->port );
   HTTPServer = Protocols.HTTP.Server.Port( http_callback, (int) configuration->port);


}

void http_callback( Protocols.HTTP.Server.Request request )
{
   mapping response = ([ "server":"Domotica DML Webserver" ]);

   //Check Auth. Require only auth if username is set in the database.
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
    if ( Stdio.is_file( configuration->webpath + request->not_query ) )
    {
       array v = request->not_query/".";
       if ( sizeof(v) >= 2 && v[-1]=="dml" )
       {
          string data = Stdio.read_file(configuration->webpath + request->not_query );
          return dmlparser->parse(request,data);
       }
       else
          return Stdio.File(configuration->webpath + request->not_query,"R");
    }
    else
       return 0;
}

mixed info( string sensor, int|void new)
{
   return xmlrpc( "sensor.info", ({ ([ "name":sensor, "new":new ]) }) )[0];
}

array sensors()
{
   return xmlrpc( "sensors", ({  }) );
}

array modules()
{
   return xmlrpc( "modules", ({  }) );
}

protected array xmlrpc( string method, array variables )
{
   string data = Protocols.XMLRPC.encode_call(method,variables);
   object req = Protocols.HTTP.do_method("POST",
                                           configuration->xmlrpcserver,0,
                                           (["Content-Type":"text/xml"]),
                                           0,data);
   if(!req || req->status != 200 )
      return ({});
   return  Protocols.XMLRPC.decode_response(req->data());
}

void log( int log_level, mixed ... args )
{
   System.syslog( log_level, @args );
#ifdef DEBUG
      Stdio.stdout.write(@args);
#endif
}

