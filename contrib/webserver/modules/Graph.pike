#include <module.h>


protected object domotica;
protected object configuration;


mapping tags = ([
]);

mapping emit = ([
]);

mapping containers = ([
   "graph":DMGraph,
]);


void create( object domi , object Config)
{
   domotica= domi;
   configuration = Config;
}

array DMLGraph(Parser.HTML p, 
               mapping args, mapping query )
{
//FIXME First get the data.
//FIXME Create image cache in SQLITE? With automatic delete?.
mapping data = ([]);
data->xsize = args->xsize || 640;
data->ysize = args->ysize || 480;

//FIXME Error if filename is not given?
string filename = args->img;


/*
mapping values = webserver->xmlrpc2( args->logger,
                       COM_LOGDATA, ([ "name":args->sensor, "start":0,
                                       "end":time() ]) );


data += ([ "xvalues":values->timestamp,"yvalues":values->values ]);

string img = Image.PNG.encode(Graphics.Graph.line(data));
int tag = time(1);

Stdio.FILE outfile = Stdio.FILE(sprintf("/img/%d.png",tag));
//FIXME
outfile->write(img->data);
return ({ sprintf( "<img src=\"/img/%d.png\" />",tag) });
*/
    
}
