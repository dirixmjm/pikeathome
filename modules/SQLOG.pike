#include <module.h>
inherit Module_LOG;

int module_type = MODULE_LOG;
string module_name = "SQLOG";
Sql.Sql DB;

void module_init() 
{
}

void log_data( string module, string name, mapping data, int|void tstamp )
{
   DB = Sql.Sql(configuration->database);
   int stamp;
   if ( zero_type(tstamp) )
      stamp = time();
   else
      stamp = tstamp;
   foreach( indices(data), string index )
   {
      //Check wether int or float (and upscale to int if float).
      int value = (int) ((float) data[index]*(int) configuration->precision);
      DB->query( "INSERT INTO log (module,sensor,variable,stamp,value) " +
                 " VALUES (:module,:sensor,:variable,to_timestamp(:timestamp),:value );",
                 ([ ":module":module,
                    ":sensor":name,
                    ":variable":index,
                    ":timestamp":stamp,
                    ":value":value]) );
   }
}
