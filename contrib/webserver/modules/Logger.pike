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

mapping emit = ([
"log":EmitLog,
]);

array EmitLog( mapping m, mapping query )
{
   
   mapping parameters = ([]);
   if ( !has_index(m,"name") )
   {
      DML->logerror("<emit log> has no name parameter\n");
      return UNDEFINED;
   }
  
   if ( has_index(m, "aggregate" ) )
      parameters->aggregate = upper_case(m->aggregate);

   string name = m->name;
   string precision;
   object precision_interval;
   int precision_count;
   if ( has_index(m, "precision") )
   {
      parameters->precision = m->precision;
      sscanf(lower_case(m->precision||""),"%d%*[ ]%[a-z]",precision_count,precision);
      //Remove plural s.
      if ( has_suffix(precision,"s") )
         precision = precision[0..sizeof(precision)-2];
      switch(precision)
      {
         case "second":
            precision_interval = precision_count * Calendar.Second();
            break;
         case "minute":
            precision_interval = precision_count * Calendar.Minute();
            break;
         case "hour":
            precision_interval = precision_count * Calendar.Hour();
            break;
         case "month":
            precision_interval = precision_count * Calendar.Month();
            break;
         case "year":
            precision_interval = precision_count * Calendar.Year();
            break;
      }
   }
   else
   {
      //FIXME Error or should the database make up the precision?
      DML->logerror("<emit log> has no precision parameters\n");
      return UNDEFINED;
   }
   switch(precision)
   {
      case "day":
      case "month":
      case "year":
         if ( has_index(m,"start") )
            parameters->start = Calendar.dwim_day(m->start)->unix_time();
         if ( has_index(m,"end") )
         {
            if ( lower_case(m->end) == "now" )
               parameters->end = Calendar.now()->unix_time();
            else
               parameters->end = Calendar.dwim_day(m->end)->unix_time();
         }
      break;
      case "second":
      case "hour":
      default:
         if ( has_index(m,"start") )
            parameters->start = Calendar.dwim_time(m->start)->unix_time();
         if ( has_index(m,"end") )
         {
            if ( lower_case(m->end) == "now" )
               parameters->end = Calendar.now()->unix_time();
            else
               parameters->end = Calendar.dwim_time(m->end)->unix_time();
         }
   }

   if ( has_index(m, "span" ) )
   {
      int span_count;
      string span;
      sscanf(lower_case(m->span||""),"%d%*[ ]%[a-z]",span_count,span);
      //Remove plural s.
      if ( has_suffix(span,"s") )
         span = span[0..sizeof(span)-2];
    
      object interval; 
      switch(span)
      {
         case "second":
            interval = span_count * Calendar.Second();
            break;
         case "minute":
            interval = span_count * Calendar.Minute();
            break;
         case "hour":
            interval = span_count * Calendar.Hour();
            break;
         case "day":
            interval = span_count * Calendar.Day();
            break;
         case "week":
            interval = span_count * Calendar.Week();
            break;
         case "month":
            interval = span_count * Calendar.Month();
            break;
         case "year":
            interval = span_count * Calendar.Year();
            break;
        
      } 
      if ( has_index( parameters, "start" ) )
         parameters->end = (Calendar.Second("unix",parameters->start)+interval)->unix_time();
      else if ( has_index( parameters, "end" ) )
         parameters->start = (Calendar.Second("unix",parameters->end)-interval)->unix_time();
      else 
      {
         parameters->end = Calendar.now()->unix_time();
         parameters->start = (Calendar.Second("unix",parameters->end)-interval)->unix_time();
      }
   }
#ifdef DEBUG
   DML->logdebug("%O\n",parameters);
#endif
   //FIXME if date parameter differs, storage overwrites data
   mapping response =	DML->rpc(name, COM_RETRLOGDATA, parameters);
   if ( response && has_index(response,"data" ) )
      return response["data"];
   else
      return ({});
}
