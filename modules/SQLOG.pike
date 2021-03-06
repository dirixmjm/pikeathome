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

Sql.Sql getdb()
{
   if ( !DB )
   {
      DB = Sql.Sql(configuration->database);
   }
   return DB;
}

void log_data( string name, float|int data, int|void tstamp )
{
   DB = getdb();
 
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
                 ([ ":key":name,
                    ":timestamp":stamp,
                    ":value":(int) value]) );
   };
   if( error )
     logerror("Data Insert Failed %s with %O\n",name, DB->error());
}

mapping retr_data( mapping parameters )
{
   DB = getdb();
   mapping queryparam = ([ ":key":parameters->name]);

   if ( has_index( parameters,"end" ) )
   {
      queryparam += ([ ":end":(int) parameters->end ]);
   }
   else
      queryparam += ([ ":end":time(1) ]);

   //Just select a default here for compatability with other Logging modules.
   queryparam[":aggregate"]= parameters->aggregate || "AVERAGE";

   if ( has_index( parameters,"start" ) )
   {
      
      queryparam += ([ ":start": (int) parameters->start ]);
   }
   else
      queryparam += ([ ":start":0 ]);

   if( has_index ( parameters, "precision" ) )
      queryparam[":precision"]=parameters->precision;
   werror("RETR: %O\n",queryparam);
   array res=({});
   mixed error = catch {
      res = DB->query( configuration->retrdataquery, queryparam);
   };
   if( error )
     logerror("Retrieving Data Failed %s with %O\n",parameters->name, DB->error());
   if( res && sizeof(res) )
   {
      res = map(res, lambda(mapping dataunit){
         dataunit->value = (float) ((float) dataunit->value / (int) configuration->precision); 
         return dataunit;
                                           });
      return ([ "data":res ]);
   }
   else
      return UNDEFINED;
}

void log_event( int level, string sender, string format, mixed ... args )
{
   DB = getdb();
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

mapping retr_event( mapping parameters )
{
   DB = getdb();
   mapping queryparam = ([]);
   if ( has_index ( parameters, "sender" ) )
      queryparam += ([ ":name":"%"+parameters->sender+"%" ]);
   else
      queryparam += ([ ":name":"%%" ]);

   queryparam[":level"] = (int) parameters->level||255;
   
   mixed error = catch {
   array res = DB->query( configuration->retreventquery, queryparam );
   };
   if( error )
     logerror("Retrieving Events Failed with %O\n", DB->error());
   
}
