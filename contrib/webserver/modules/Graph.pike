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
//FIXME Create image cache in SQLITE? With automatic delete?.
//FIXME Should container-content not be preparsed in a parent container-callback?

content = replace(content, ({"\r\n","\r"}),({"\n","\n"}) );


mapping data = ([]);
data->xsize = (int) args->xsize || 640;
data->ysize = (int) args->ysize || 480;
data->type = "graph";
data->subtype = args->type || "line";
data->ymin = (int) args->ymin || 0;
data->format = "jpg";

//FIXME Error if filename is not given?

parse_html( content, ([]), ([ "data":get_data ]), query, data );


if( !data->data || ! sizeof(data->data) )
   return ({"No data for the diagram"});


string filename = args->img;
if( data->orientation ) data->orient = data->orientation;
string img = Image.JPEG.encode(Graphics.Graph.graph(data));

Stdio.write_file(sprintf("/var/pikeathome/www/img/%s.jpg",filename),img,0664);
return ({ sprintf( "<img src=\"/img/%s.jpg\" />",filename) });

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
