#!/usr/bin/pike
// Copyright (c) 2011, Marc Dirix, The Netherlands.
//                         <marc@dirix.nu>
//
// This script is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//
#include <module.h>
inherit Module;

protected object DML;
protected object configuration;


#define SEP ","

mapping tags = ([
]);

mapping emit = ([
]);

mapping containers = ([
   "math":DMLMath,
]);


void create( object dml_ , object Config)
{
   DML = dml_;
   configuration = Config;
}

array DMLMath(Parser.HTML p, 
               mapping args, string content, mapping query )
{
   float value = 0.0;
   if ( sizeof( content ) )
   {
      value= (float) content;
   }
   else if ( has_index( args, "variable" ) )
   {
      value = (float) DML->resolve_entity(args->variable, query ); 
   }
   else if ( has_index ( args, "value" ) )
   {
      value = (float) args->value;
   }
  
   if( has_index( args, "mult" ) )
   {
      value = value * (float) args->mult;
   }
   if( has_index( args, "add" ) )
   {
      value = value + (float) args->mult;
   }
   if( has_index( args, "round" ) )
   {
      value = round(value);
   }
   if( has_index( args, "floor" ) )
   {
      value = floor(value);
   }
   if( has_index( args, "ceil" ) )
   {
      value = ceil(value);
   }

   return ({ value }); 
}

