#include <module.h>
inherit Module_LOG;

int module_type = MODULE_LOGDATA | MODULE_LOGEVENT;
string module_name = "SQLOG";
Sql.Sql DB;

array ModuleParameters = ({
                   ({ "database",PARAM_STRING,"","Database URI", 0 }),
                   ({ "precision",PARAM_INT,1,"Default Multiplier", 0 }),
                   ({ "logdataquery",PARAM_STRING,"","Query for logging data", 0 }),
                   ({ "logeventquery",PARAM_STRING,"","Query for logging events", 0 }),
                   ({ "retrdataquery",PARAM_STRING,"","Query for retrieving data", 0 }),
                   ({ "retreventquery",PARAM_STRING,"","Query for retrieving events", 0 }),
                  });



void init() 
{
}

void log_data( string name, float|int data, int|void tstamp )
{
   DB = Sql.Sql(configuration->database);
   array split = split_server_module_sensor_value(name);
 
   int stamp;
   if ( zero_type(tstamp) )
   {
      stamp = time();
   }
   else
      stamp = tstamp;

   //Check wether int or float (and upscale to int if float).
   int value = (int) ((float) data*(int) configuration->precision);
   mixed error = catch {
   DB->query( configuration->logdataquery,
                 ([ ":server":split[0],
                    ":module":split[1],
                    ":sensor":split[2],
                    ":variable":split[3],
                    ":timestamp":stamp,
                    ":value":(int) value]) );
   };
   if( error )
     logerror("Data Insert Failed %s with %O\n",name, DB->error());
     
}

mapping retr_data( mapping parameters )
{
   DB = Sql.Sql(configuration->database);
   array split = split_server_module_sensor_value(parameters->name);
   mapping queryparam = ([ ":server":split[0],
                    ":module":split[1],
                    ":sensor":split[2],
                    ":variable":split[3]]);

   if ( has_index( parameters,"end" ) )
   {
      queryparam += ([ ":end":sprintf( "to_timestamp(%d)",(int) parameters->end) ]);
   }
   else
      queryparam += ([ ":end":"current_timestamp"]);

   //Just select a default here for compatability with other Logging modules.
   queryparam[":aggregate"]= parameters->aggregate || "AVERAGE";

   if ( has_index( parameters,"start" ) )
   {
      queryparam += ([ ":start":sprintf( "to_timestamp(%d)",(int) parameters->start) ]);
   }
      queryparam += ([ ":start":"to_timestamp(0)" ]);

   string query = "SELECT stamp,value FROM retrieve_archive ( :server, "+
                  " :module, :sensor, :variable, :aggregate, :start, :end ";
   if( has_index ( parameters, "precision" ) )
   {
      query += ",:precision";
      queryparam[":precision"]=parameters->precision;
   }
   query += ");";
   array res = DB->query( query, queryparam);
   return ([ "timestamp":res->stamp,"value":res->value ]);
}

void log_event( int level, string sender, string format, mixed ... args )
{
   DB = Sql.Sql(configuration->database);
   int stamp = time();
   catch {
   array res = DB->query( configuration->logeventquery,
                          ([
                             ":level":level,
                             ":timestamp":stamp,
                             ":event":sprintf( format, @args),
                             ":sender":sender,
                             ]) );
   };
}
