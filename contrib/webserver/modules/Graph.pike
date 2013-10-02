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

protected object DML;
protected object configuration;


#define SEP ","

mapping containers = ([
   "graph":DMLGraph,
]);


void create( object dml_ , object Config)
{
   DML = dml_;
   configuration = Config;
}

array DMLGraph(Parser.HTML p, 
               mapping args, string content, mapping query )
{
if ( !has_index( args, "img" ) )
   return ({ "Need img parameter to store image data" });

//FIXME image location should be dynamic?
string filename = sprintf("/var/pikeathome/www/img/%s.jpg",args->img);
array imghtml = ({ sprintf( "<img src=\"/img/%s.jpg\" />",args->img) });

if( has_index( args, "keep" ) && Stdio.is_file(filename) )
{
   int keep_count,interval;
   string keep;
   sscanf(lower_case(args->keep||""),"%d%*[ ]%[a-z]",keep_count,keep);
   //Remove plural s.
   if ( has_suffix(keep,"s") )
      keep = keep[0..sizeof(keep)-2];
   switch(keep)
   {
           case "second":
            interval = keep_count;
            break;
         case "minute":
            interval = keep_count * 60;
            break;
         case "hour":
            interval = keep_count * 60*60;
            break;
         case "day":
            interval = keep_count * 60*60*24;
            break;
         case "week":
            interval = keep_count * 60*60*24*7;
            break;
         case "month":
            interval = keep_count * 60*60*24*30;
            break;
         case "year":
            interval = keep_count * 60*60*24*365;
            break;
   }
   int mtime = file_stat(filename)->mtime;
   if ( mtime+interval > time(1) )
      return imghtml;
}

content = replace(content, ({"\r\n","\r"}),({"\n","\n"}) );

mapping data = ([]);
data->xsize = (int) args->xsize || 640;
data->ysize = (int) args->ysize || 480;
data->type = "graph";
data->subtype = args->type || "line";
data->ymin = (int) args->ymin || 0;
data->format = "jpg";
data->name = args->name || "";

data->legend_texts = args->legend?args->legend/",":UNDEFINED;

DMLParser( ([ "source":get_source ]), ([ "data":get_data ]), query,data)->parse_html( content );


if( !data->data || ! sizeof(data->data) )
   return ({"No data for the diagram"});


if( data->orientation ) data->orient = data->orientation;
string img;
switch( args->type ||"line" )
{
   case "pie":
   img = Image.JPEG.encode(Graphics.Graph.pie(data));
   break;
   case "sumbars":
   img = Image.JPEG.encode(Graphics.Graph.sumbars(data));
   break;
   case "bars":
   img = Image.JPEG.encode(Graphics.Graph.bars(data));
   break;
   case "line":
   default:
   img = Image.JPEG.encode(Graphics.Graph.line(data));
}

Stdio.write_file(filename,img,0664);

return imghtml;

}

string get_data( mapping tag, mapping m, string content, mapping query, mapping data)
{
   string sep = m->separator || SEP;
   string linesep = m->lineseparator || "\n";
   
   if( !m->noparse)
      content = DML.parse_dml( content, query );

   array lines = content/linesep-({""});

   if ( sizeof(lines) == 0 )
   {
      data->data=({});
      return 0;
   }
   
   array bar = allocate(sizeof(lines));

   foreach( lines; int linen; string line )
   {
      //FIXME VOIDSYMBOL?
      bar[linen] = line / sep - ({""});
   }

   if (  sizeof(bar[0]) == 0 )
   {
      data->data = ({});
      return 0;
   }

   if ( has_index( m, "form") && m->form == "row" )
   {
      data->data = bar;
   }
   else
      data->data = Array.transpose(bar);

   if( has_index( m, "xnames" ) && (sizeof(data->data)>1))
   {
      data->xnames = data->data[0];
      data->data = data->data[1..];
   }
   if ( has_index(m,"xnamesvert"))
      data->orientation = "vert";

   //Convert data to floats
   foreach( data->data; int linen; array line )
      foreach( line; int datan; mixed value )
         data->data[linen][datan] = (float) data->data[linen][datan];
   return 0;
}

string get_source( mapping tag, mapping m, mapping query, mapping data)
{
   mapping parameters = ([]);
   if ( !has_index(m,"name") )
   {
      //FIXME Error?
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
      //FIXME Error or should the database make up the precision?
      return UNDEFINED;
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
   //FIXME if data parameter differs, storage overwrites data
   mapping response =	DML->rpc(name, COM_RETRLOGDATA, parameters);
   //Display code
   if( response && has_index( response, "data") )
   {
      array values = ({});
      array xnames = ({});
      array timeslots = ({});
      foreach( response->data, mapping value )
      {
        values += ({ (float) value->value });
        timeslots += ({ (int) value->stamp });
      }


      if ( has_index(m, "split") )
      {
         string split;
         int split_count;
         object split_interval,split_pointer;
         sscanf(lower_case(m->split||""),"%[a-z]",split);
         switch(split)
         {
            case "second":
               split_interval = Calendar.Second();
               split_pointer = Calendar.Second("unix",timeslots[0]);
               split_count = Calendar.Second() / precision_interval;
               break;
            case "minute":
               split_interval = Calendar.Minute();
               split_pointer = Calendar.Minute("unix",timeslots[0]);
               split_count = Calendar.Minute() / precision_interval;
               break;
            case "hour":
               split_interval = Calendar.Hour();
               split_pointer = Calendar.Hour("unix",timeslots[0]);
               split_count = Calendar.Hour() / precision_interval;
               break;
            case "month":
               split_interval = Calendar.Month();
               split_pointer = Calendar.Month("unix",timeslots[0]);
               split_count = Calendar.Month() / precision_interval;
               break;
            case "year":
               split_interval = Calendar.Year();
               split_pointer = Calendar.Year("unix",timeslots[0]);
               split_count = Calendar.Year() / precision_interval; 
               break;
            default:
               split_count = sizeof(values);
         }
         array legend =  ({ split_pointer->format_nice() });
         split_pointer = split_pointer+split_interval; 
         int loop_count=0,store_index=0;
         array(array) dataset = ({});
         array valuestore = zeros(split_count);
         foreach( timeslots; int index; int stamp )
         {
            if ( stamp < split_pointer->unix_time() )
            {
               if ( loop_count == 0 )
                  valuestore[split_count-store_index++-1] = values[index];
               else
                  valuestore[store_index++] = values[index];
            }
            else
            {
               legend +=  ({ split_pointer->format_nice() });
               split_pointer = split_pointer+split_interval; 
               loop_count = 1;
               //copy value to dataset
               dataset += ({ valuestore+({}) });
               valuestore = zeros(split_count);
               store_index = 0;
               valuestore[store_index++] = values[index];
            }
         }
         dataset += ({ valuestore+({}) });
         data->data += dataset;
         data->legend_texts = legend;
         array xnames = ({});
         for ( int index = 0; index < split_count; index ++ )
         {
            switch(precision)
            {
               case "minute":
               case "hour":
                  xnames += ({ ( split_interval + index*precision_interval )->format_mod() });
                  break;
               case "day":
                  xnames += ({ ( split_interval + index*precision_interval )->week_day_name() });
                  break;
               case "month":
                  xnames += ({ ( split_interval + index*precision_interval )->month_name() });
                  break;
               case "year":
                  xnames += ({ ( split_interval + index*precision_interval )->year_no() });
                  break;
               default:
                  xnames += ({ index });
            }
         }
         data->xnames = xnames;
      }
      else
      {
         switch(precision)
         {
            case "minute":
            case "hour":
               foreach ( timeslots, int stamp )
                  xnames += ({ Calendar.Minute("unix",stamp)->format_mod() });
               break;
            case "day":
               foreach ( timeslots, int stamp )
                  xnames += ({ Calendar.Day("unix",stamp)->week_day_name() });
               break;
            case "month":
               foreach ( timeslots, int stamp )
                  xnames += ({ Calendar.Month("unix",stamp)->month_name() });
               break;
            case "year":
               foreach ( timeslots, int stamp )
                  xnames += ({ Calendar.Year("unix", stamp)->year_no() });
               break;
            default: 
               foreach ( timeslots, int stamp )
                  xnames += ({ stamp });
         }
         data->data += ({ values });
         data->xnames = xnames;
      }

      if ( has_index(m,"xnamesvert"))
         data->orientation = "vert";
   }
}

array zeros(int size)
{
  array ret = ({});
  for( int index = 0; index < size; index++)
    ret += ({ 0.0 });
  return ret;
}
