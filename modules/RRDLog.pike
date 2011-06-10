#include <module.h>
inherit Module_LOG;

int module_type = MODULE_LOG;
string module_name = "RRDLog";

void module_init() 
{
   if( !has_index(configuration,"logpath") )
      configuration["logpath"]="/tmp";
}

void log_data( string module, string name, mapping data, int|void tstamp )
{
   //RRD only take mapping(string:string)
   foreach(indices(data),string index)
   {
      data[index] = (string) data[index];
      //intp(data[index]) ? sprintf("%d",data[index]):sprintf("%f",data[index]);
   } 
   string filename = configuration->logpath + "/"+ name + ".rrd";
   mixed c_error = catch {
   if( !zero_type(tstamp ) )
   {
      int lastlog = Public.Tools.RRDtool.last( filename );
      if ( lastlog >= tstamp )
      {
#ifdef RRDLOGDEBUG
         domotica->log(LOG_EVENT, LOG_DEBUG, "Not logging tstamp < RRD Log\n" );
#endif
         return;
      }
      Public.Tools.RRDtool.update(filename, data, tstamp);
   }
   else 
      Public.Tools.RRDtool.update(filename, data );
   };
#ifdef RRDLOGDEBUG
   domotica->log(LOG_EVENT,LOG_DEBUG, "%d\t%O\n",tstamp,c_error);
#endif
}
