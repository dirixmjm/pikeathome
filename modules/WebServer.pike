#include <module.h>
inherit Module;

int module_type = MODULE_INTERFACE;
string module_name = "WebServer";

protected object HTTPServer;
array defvar = ({ 
                   ({ "webpath","string","","directory containing webserver files" }),
		   ({ "port","string",8080,"Port the website listens on, default 8080"}),
                   ({ "debug","boolean",0,"Turn Debugging On / Off"}),
                   ({ "username", "string","","Username for entering the webpages"}),
                   ({ "password", "string","","Password to protect the websites"}),
                   });
object dmlparser;

void module_init(  )
{
   if( !has_index(configuration,"port") )
   {
      werror("No index port %O\n",configuration->port);
//       configuration["port"]="8080";
   }
   dmlparser = DML.DML( domotica , configuration );
#ifdef WEBSERVERDEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG,"Create Web Interface Port %d\n",(int) configuration->port );
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

