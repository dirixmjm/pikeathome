#include <module.h>


protected object DML;
protected object configuration;


mapping tags = ([
]);

mapping emit = ([
"log":EmitLog,
]);

mapping containers = ([
]);


void create( object DML_ , object Config)
{
   DML= DML_;
   configuration = Config;
}


array EmitLog( mapping args, mapping query )
{
   //FIXME Check arguments.
   int start = (int) args->start | 0;
   int end = (int) args->end | time(1);

   mapping ret = DML->rpc( args->logger,
                       COM_RETRLOGDATA, ([ "name":args->sensor, "start":start,
                                       "end":end, "precision":args->precision,
                                       "aggregate":args->aggregate ]) );
   werror("%O\n",ret);
   if( ret && has_index( ret, "data" ) )
   {
       return ret["data"];
   }
   
   return ({});
}
