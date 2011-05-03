#include <module.h>


//FIXME Protect with Mutex?
protected Sql.Sql db;
protected object domotica;
protected object configuration;
Parser.HTML parser;


mapping tags = ([
"include":DMLInclude,
"write":DMLWrite,
"set":DMLSet,
"inc":DMLInc,
"dec":DMLDec,
"redirect":DMLRedirect,
"date":DMLDate,
"rrdgraph":DMLRRDgraph,
]);

mapping emit = ([
"sensors": EmitSensors,
"sensor": EmitSensor,
"modules": EmitModules,
"parameters": EmitParameters,
]);

mapping containers = ([
"emit":DMLEmit,
"if":DMLIf,
]);


void create( object domi , object Config)
{
   domotica= domi;
   parser = DML.Parser();
   parser->add_tags(tags);
   parser->add_containers(containers);
   parser->add_entity ( "lt", 0);
   parser->add_entity ( "gt", 0 );
   parser->add_entity("amp",0);
   parser->_set_entity_callback( entity_callback );
   parser->lazy_entity_end(1);
   configuration = Config;
}

array entity_callback(Parser.HTML p, 
               string entity, mapping query )
{
   
   string scope="",variable="";
   int scan = sscanf(entity,"&%s.%s;",scope,variable);
   if( scan < 2 || !has_index( query->entities, scope ) || 
       !has_index(query->entities[scope],variable) )
      return ({ entity });
   return ({ query->entities[scope][variable] });
}

string resolve_entity(string entity, mapping query )
{
   string scope="",variable="";
   int scan = sscanf(entity,"%s.%s",scope,variable);
   if( scan < 2 || !has_index( query->entities, scope ) || 
       !has_index(query->entities[scope],variable) )
      return entity;
   return (string) query->entities[scope][variable];
}

void set_entity(int|float|string value, string entity, mapping query )
{
   string scope="",variable="";
   int scan = sscanf(entity,"%s.%s",scope,variable);
   if( scan < 2 || !has_index(query->entities, scope) )
      return;
   query->entities[scope][variable] = (string) value;

}

int exists_entity(string entity, mapping query )
{
   string scope="",variable="";
   int scan = sscanf(entity,"%s.%s",scope,variable);
   if( scan < 2 || !has_index( query->entities, scope ) || 
       !has_index(query->entities[scope],variable) )
      return 0;
   return 1;
}

array EmitModules( mapping args, mapping query )
{
  array ret=({});
  foreach( domotica->modules, string name)
     ret+= ({  ([ "name":name ]) });
  return ret;
}

array EmitParameters( mapping args, mapping query )
{
   if( has_index(args,"name" ) )
   {
      if ( has_value( domotica->sensors, args->name ) || has_value( domotica->modules, args->name ))
      {
         return domotica->parameters(args->name);
      }
   }
   return ({});
}


array EmitSensors( mapping args, mapping query )
{
   int sensor_type = 0;
   if( has_index(args,"input") )
       sensor_type |= SENSOR_INPUT;
   if( has_index(args,"output") )
       sensor_type |= SENSOR_OUTPUT;
   if( has_index(args,"schedule") )
       sensor_type |= SENSOR_SCHEDULE;
   if( has_index(args,"all") || ( !has_index(args,"input") && 
                   !has_index(args,"output") && !has_index(args,"schedule") ) )
       sensor_type = SENSOR_INPUT | SENSOR_OUTPUT | SENSOR_SCHEDULE;
   array ret = ({});
   foreach( domotica->sensors,string sensor )
   {
      if( domotica->info(sensor,0)->sensor_type & sensor_type )
         ret += ({ domotica->info( sensor, args->new?1:0 ) });
   }
   return ret;
}

array EmitSensor( mapping args, mapping query )
{
   if( has_index(args,"name" ) )
   {
      if ( has_value( domotica->sensors, args->name ) )
         return ({ domotica->info(args->name, args->new?1:0 ) });
   }
   return ({});
}

array DMLEmit(Parser.HTML p, 
               mapping args, string content, mapping query )
{
   if(!has_index(args,"source") || !has_index(emit,args->source) )
      return ({"Source not found<br />"});
   string ret="";
   array data = emit[args->source](args, query);
   foreach( data, mapping values)
   {
      mapping q = query +([]);
      m_delete(q->entities,"_");
      foreach( indices(values), string ind )
         q->entities["_"] += ([ ind: (string) values[ind] ]);
      object emitparser = parser->clone();
      emitparser->set_extra(q);
      emitparser->feed(content);
      ret+= emitparser->read();
   }
   m_delete(query->entities,"_");
   return ({ ret });
}

string DMLWrite(Parser.HTML p, 
               mapping args, mapping query )
{
   
   if( !has_index( args, "name" ))
      return "";
   domotica->write(args->name,args->value);
   return "";
}

string DMLInclude(Parser.HTML p, 
               mapping args, mapping query )
{
   if( !has_index( args, "file") || !Stdio.is_file( configuration->webpath + args->file ) )
      return "Error, argument file not given, or file doesn't exist<br />";
   return Stdio.read_file(configuration->webpath + args->file);
   
   
}

string DMLIf(Parser.HTML p, 
               mapping args, string content, mapping query )
{
   if ( has_index( args, "variable" ) )
   {
      array arr = args->variable/" ";
      if( !exists_entity(arr[0],query ) )
         return "";
      else if ( sizeof(arr) == 1 )
      {
            return content;
      }

      if ( sizeof(arr) == 2 )
      {
         return "";
      }
      string var = resolve_entity(arr[0],query);
      string is = arr[2..]*" ";

      if ( arr[1] == "=" || arr[1] == "==" || arr[1] == "is" )
      {
         if ( var == is )
            return content;
         else 
            return "";
      } 
      else if ( arr[1] == "!=" ) 
      {
         if ( var != is )
            return content;
         else 
            return "";
      }
   }
   return "No argument given for if tag<br />";
}

string DMLInc(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( has_index( args, "variable" ) )
   {
      float value = 1.0;
      if( !exists_entity(args->variable,query ) )
         return "";
      float var = (float) resolve_entity(args->variable,query);
      
      if ( has_index( args, "value" ) )
         value = (float) resolve_entity(args->value,query);
      set_entity( var+value, args->variable, query);
   }
   else
      return "variable argument missing";
}

string DMLDec(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( has_index( args, "variable" ) )
   {
      float value = 1.0;
      if( !exists_entity(args->variable,query ) )
         return "";
      float var = (float) resolve_entity(args->variable,query);
      
      if ( has_index( args, "value" ) )
         value = (float) resolve_entity(args->value,query);
      set_entity( var-value, args->variable, query);
   }
   else
      return "variable argument missing";
}

string DMLSet(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( has_index( args, "variable" ) && has_index( args, "value" ) )
   {
      string value = resolve_entity(args->value,query);
      set_entity( value, args->variable, query);
   }
   else
      return "variable argument missing";
}

string DMLRedirect(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( has_index( args, "to" ) )
   {
      string to = resolve_entity(args->to,query);
      query["state"]=([ "return_code":302, "Location": to ]);
      return ""; 
   }
   else
      return "Missing argument to";
}

array DMLRRDgraph(Parser.HTML p, 
               mapping args, mapping query )
{
   if ( !has_index( args, "graph" ) || !has_index( args, "name") )
      return ({});
   
   mixed err = catch { Public.Tools.RRDtool.graph(configuration->webpath + "/img/" + args->name + ".png",
                               args->graph/" " );
   };
   if( !err )
      return ({ "<img src=\"/img/" + args->name + ".png\" />" });
}

string DMLDate(Parser.HTML p, 
               mapping args, mapping query )
{
   mapping date = Calendar.Minute()->datetime();
   //FIXME Calendar.Minute()->format?
   string ret = sprintf("%02d-%02d-%d",date->day,date->month,date->year);
   if( has_index(args, "time") )
      ret += sprintf(" %0d:%02d",date->hour,date->minute);
   return ret;
}

object parse(object Request,string data)
{
   mapping query;
   query = ([ "request":Request]);
   query["args"] = Protocols.HTTP.Server.http_decode_urlencoded_query(Request->query);
//   query["configuration"] = configuration;

   //FIXME Pathdata
   query["entities"] = ([ "form": Request->variables, "var":([]) ]);
   object clone = parser->clone();
   clone->set_extra(query);
   clone->ignore_tags(1);
   clone->feed(data);
   string pass_1 = clone->finish()->read();
   clone->ignore_tags(0);
   clone->feed(pass_1);
   object File = DML.File( clone->finish()->read(), clone->get_extra()[0] );
   
   return File;
}
