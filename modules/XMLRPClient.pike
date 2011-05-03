#include <module.h>
inherit Module;

int module_type = MODULE_SENSOR;
string module_name = "XMLRPClient";

class sensor
{

   inherit Sensor;
   int sensor_type = SENSOR_INPUT | SENSOR_OUTPUT;

   protected mapping sensor_var = ([
                               "module":"XMLRPClient",
                               "name":"",
                               "sensor_type":sensor_type
                               ]);

   void getnew()
   {
         werror("Here %s\n", configuration->server);
         array req = xmlrpc("sensor.info",({ ([ "name":configuration->remote_name, "new":1 ]) }));
         if( req )
         {
            m_delete(req[0],"name");
            m_delete(req[0],"module");
            m_delete(req[0],"sensor_type");
            foreach(indices(req[0]), string ind )
               sensor_var[ind]=req[0][ind];
            
         }
         else
            sensor_var->online = 0;
   }

   mapping write( mapping towrite )
   {
      //FIXME Don't write if not OUTPUT
      array req = xmlrpc("sensor.write", ({ ([ "name":configuration->remote_name]) + towrite }) );
      //FIXME Should return something here.
      return ([]);
   } 
   
   
protected array xmlrpc( string method, array variables )
{
   string data = Protocols.XMLRPC.encode_call(method,variables);
   object req = Protocols.HTTP.do_method("POST", 
                                           configuration->server,0,
                                           (["Content-Type":"text/xml"]),
                                           0,data);
   if(!req || req->status != 200 )
      return ({});
   return  Protocols.XMLRPC.decode_response(req->data());
}

}
