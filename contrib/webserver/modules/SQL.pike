#include <module.h>


protected object webserver;
protected object configuration;


mapping tags = ([
]);

mapping emit = ([
"sql":EmitSql,
]);

mapping containers = ([
]);


void create( object webserver_ , object Config)
{
   webserver= webserver_;
   configuration = Config;
}


array EmitSql( mapping args, mapping query )
{
   //FIXME Check argument query.
   mapping bindings = ([]);
   if( has_index(args, "bindings" ) )
   {
      foreach(args->bindings/",",string bind )
      {
        array split = bind/"=";
        bindings+= ([ split[0]:split[1] ]);
      }
   }
   
   Sql.Sql db = getdb();
   array res = db->query(args->query, bindings);
   if( res )
     return res;
   else
     return ({});
}

Sql.Sql mdb;

Sql.Sql getdb()
{
  if( !mdb  )  
    mdb = Sql.Sql(configuration->database);
  return mdb;
}
