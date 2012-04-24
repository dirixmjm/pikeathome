#include <module.h>
inherit Module_LOG;

int module_type = MODULE_LOG;
string module_name = "SQLOG";
Sql.Sql DB;

array defvar = ({
                   ({ "database",PARAM_STRING,"","Database URI", POPT_RELOAD }),
                   ({ "precision",PARAM_INT,"","Float Storage Multiplier" }),                  });



void init() 
{
}

void log_data( string name, float|int data, int|void tstamp )
{
   DB = Sql.Sql(configuration->database);
   array split = split_module_sensor_value(name);
 
   int stamp;
   if ( zero_type(tstamp) )
      stamp = time();
   else
      stamp = tstamp;
   //Check wether int or float (and upscale to int if float).
   int value = (int) ((float) data*(int) configuration->precision);

   DB->query( "INSERT INTO log (module,sensor,variable,stamp,value) " +
                 " VALUES (:module,:sensor,:variable,to_timestamp(:timestamp),:value );",
                 ([ ":module":split[0],
                    ":sensor":split[1],
                    ":variable":split[2],
                    ":timestamp":stamp,
                    ":value":value]) );
}

mapping retr_data( string name, int|void start, int|void end)
{
   DB = Sql.Sql(configuration->database);
   array split = split_module_sensor_value(name);
   int stamp_start=0,stamp_end;
   if ( zero_type(end) )
      stamp_end = time();
   else
      stamp_end = end;
   if ( !zero_type(start) )
      stamp_start = start;
   array res = DB->query( "SELECT stamp,value FROM log "+
                          "WHERE module=:module AND "+
                          " sensor=:sensor AND "+
                          " variable=:variable AND "+
                          " stamp >= to_timestamp(:stampstart) AND "+
                          " stamp <= to_timestamp(:stampend);",
                 ([ ":module":split[0],
                    ":sensor":split[1],
                    ":variable":split[2],
                    ":stampstart":stamp_start,
                    ":stampend":stamp_end]) );
  
  return ([ "timestamp":res->stamp,"value":res->value ]);
}
    
