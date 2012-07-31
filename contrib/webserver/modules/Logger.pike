#include <module.h>


protected object webserver;
protected object configuration;


mapping tags = ([
]);

mapping emit = ([
"log":EmitLog,
]);

mapping containers = ([
]);


void create( object webserver_ , object Config)
{
   webserver= webserver_;
   configuration = Config;
}


array EmitLog( mapping args, mapping query )
{
   //FIXME Check arguments.
   int start = (int) args->start | 0;
   int end = (int) args->end | time(1);

   mapping values = webserver->xmlrpc( args->logger,
                       COM_LOGDATA, ([ "name":args->sensor, "start":start,
                                       "end":end ]) );
   werror("%O\n",values);
   return ({});
}
