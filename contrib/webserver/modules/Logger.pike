#include <module.h>
inherit DMLModule;

mapping emit = ([
"log":EmitLog,
]);

array EmitLog( mapping args, mapping query )
{
   //FIXME Check arguments.
   int start = (int) args->start | 0;
   int end = (int) args->end | time(1);

   mapping ret = dml->rpc( args->logger,
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
