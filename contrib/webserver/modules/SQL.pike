// Copyright (c) 2011,2012 Marc Dirix, The Netherlands.
//                         <marc@dirix.nu>
//
// This script is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

#include <module.h>
inherit DMLModule;

mapping emit = ([
"sql":EmitSql,
]);

constant ModuleParameters = ({
                   ({ "database",PARAM_STRING,"","Database URL", POPT_NONE }),
                   });

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
