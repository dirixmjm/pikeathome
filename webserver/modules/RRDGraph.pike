#include <module.h>


//FIXME Protect with Mutex?
protected object domotica;
protected object configuration;


mapping tags = ([
"rrdgraph":DMLRRDgraph,
]);

mapping emit = ([
]);

mapping containers = ([
]);


void create( object domi , object Config)
{
   domotica= domi;
   configuration = Config;
}

array DMLRRDgraph(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( !has_index( args, "graph" ) || !has_index( args, "name") )
      return ({});
   string name = args->filename || args->name; 
   mixed err = catch { Public.Tools.RRDtool.graph(configuration->webpath + "/img/" + name + ".png",
                               args->graph/" " );
   };
   if( !err )
      return ({ "<img src=\"/img/" + name + ".png\" />" });
}
