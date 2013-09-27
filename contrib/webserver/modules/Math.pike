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
inherit DMLModule;

#define SEP ","

mapping containers = ([
   "math":DMLMath,
]);


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
      value = (float) dml->resolve_entity(args->variable, query ); 
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
      value = value + (float) args->add;
   }
   if( has_index( args, "round" ) )
   {
      int rnd = pow(10, (int) args->round||0);
      value = round(value*rnd)/rnd;
   }
   if( has_index( args, "floor" ) )
   {
      value = floor(value);
   }
   if( has_index( args, "ceil" ) )
   {
      value = ceil(value);
   }

   return ({ (string) value }); 
}

