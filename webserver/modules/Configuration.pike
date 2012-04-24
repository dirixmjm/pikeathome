#include <module.h>
#include <parameters.h>
string abc="wa-wa-wa-waaaa\n";

protected object webserver;
protected object configuration;


mapping tags = ([
"configuration": DMLConfiguration,
]);

mapping emit = ([
]);

mapping containers = ([
]);


void create( object webserver_ , object Config)
{
   webserver= webserver_;
   configuration = Config;
}

array EmitModuleParameters( mapping args, mapping query )
{
   array params,ret=({});
   if( has_index( args, "new" ) && has_index(args,"module") )
   {
      foreach( webserver->compilemodules(0) , mapping mod )
      {
         if( args->module == mod->name )
            params = mod->parameters;
      }
   }
   else if( has_index(args,"name" ) )
       params = webserver->xmlrpc( args->name, COM_PARAM, 0 );
   else
      return ({});

   array index = ({ "key","type","default","description","options" });
   foreach( params, array par )
   {
      if( sizeof(index) == sizeof(par) )
         ret += ({ mkmapping(index,par) });
      else if ( sizeof(index) == sizeof(par)-1 )
         ret += ({ mkmapping(index+({"value"}),par) });
      else 
      {
          webserver->log(LOG_ERR,"Parameter size mismatch\n");
         continue;
      }
   }
   return ret;
}

array EmitSensorParameters( mapping args, mapping query )
{
   array ret=({});

   if( has_index( args, "new" ) && has_index(args,"module") && has_index(args,"sensor") )
   {
      //FIXME This should be fixed in the server. The sensor should be able
      // to list its own parameters.

      array sensors = webserver->xmlrpc( args->module, COM_SENSLIST, ([ "new":1, "manual":0]) );
      foreach(sensors, mapping sens)
      {
         if( sens->sensor == args->sensor )
         {
            array index = ({ "key","type","default","description" });
            foreach( sens->parameters, array par )
            {
               if( sizeof(index) == sizeof(par) )
                  ret += ({ mkmapping(index,par) });
               else if ( sizeof(index) == sizeof(par)-1 )
                  ret += ({ mkmapping(index+({"value"}),par) });
               else 
               {
                  webserver->log(LOG_ERR,"Parameter size mismatch\n");
                  continue;
                }
            }
         }
      }
   }
   else if( has_index(args,"name" ) )
      ret = webserver->xmlrpc( args->name, COM_PARAM, 0 );
   return ret;
}

array EmitCompiledModules( mapping args, mapping query )
{
   array ret = ({});
   foreach( webserver->compilemodules( (int) args["compile"] ), mapping mod )
   {
      m_delete(mod,"parameters");
      ret += ({ mod });
   }
   return ret;
}
array EmitFindSensors( mapping args, mapping query )
{
   if( !has_index(args,"module" ) )
      return ({});
   array ret=({});
   array sensors = webserver->xmlrpc( args->module, COM_SENSLIST, ([ "new":1, "manual": args->manual?1:0]) );
   foreach(sensors, mapping sens)
   {
      ret += ({ ([ "sensor":sens->sensor ]) });
   }
   return ret;
}

array DMLConfiguration(Parser.HTML p, mapping args, mapping query )
{

   string name = args->name || "webserver";

   if(!name || !sizeof(name) )
      return ({});
   array name_split = webserver->split_module_sensor_value(name);

   //Name should be module or module.sensor
   if( sizeof(name_split) > 2 )
      return ({ "<H1>Error<H1><p>Configuration not available for values" });

   //Find Parameters of the module or sensor.
   array|mapping params = webserver->xmlrpc( args->name, COM_PARAM, 0 );

   //FIXME what if module,sensor doesn't exist?
   if( mappingp(params) && has_index(params,"error"))
      return ({ sprintf("<H1>Error<H1><p>%O",params->error) });
   else if( mappingp(params) )
      return ({ "<H1>Error<H1><p>Server returned mapping, array was expected",
                sprintf("%O\n",params) });
     
   //Check for save button, formref and write values.
      werror("%O\n",query->entities); 
   if( has_index( query->entities->form, "Save" ) && 
       has_index( query->entities->form, "formref" ) &&
       query->entities->form->formref == name )
   {
      mapping tosave=([]);

      foreach(params, array param)
      {
         switch( param[1] )
         {
            case PARAM_SENSOROUTPUT:
            case PARAM_SENSORINPUT:
            case PARAM_STRING:
            //Don't save if the paramater hasn't changed
            if( has_index(query->entities->form, param[0]) && 
                (sizeof(param)<6 || 
                           param[5] != query->entities->form[param[0]]))
               tosave+=([ param[0]:query->entities->form[param[0]] ]);
            break;
            case PARAM_INT:
            case PARAM_BOOLEAN:
            //Don't save if the paramater hasn't changed
            if( has_index(query->entities->form, param[0]) && 
                (sizeof(param)<6 || 
                           param[5] != (int) query->entities->form[param[0]]))
               tosave+=([ param[0]:(int) query->entities->form[param[0]] ]);
            break;
            case PARAM_SCHEDULE:
               if( !has_index(query->entities->form,"schedule_"+param[0]) )
                  continue;
               int count = (int) query->entities->form["schedule_"+param[0]];
               array(mapping) theschedule = ({});
               for( int i = 1; i<=count; i++ )
               {
                  string findit = param[0]+"_"+(string) i;
                  //remove empty lines.
                  if( !query->entities->form["start_"+findit] || 
                     query->entities->form["start_"+findit]=="" )
                  continue;
                  theschedule+= ({ ([
                                "start":query->entities->form["start_"+findit],
                                "dow":query->entities->form["dow_"+findit],
                                "value":query->entities->form["value_"+findit]
                                ])});   
               }
               tosave+=([ param[0]:theschedule ]);
            break;
            default:
               webserver->log(LOG_ERR,"Can't save unknown paramter type\n");
         }
      }
      if(sizeof(tosave))
          params = webserver->xmlrpc( args->name, COM_PARAM, tosave );
   }
   array ret = ({});
   //Build form code
   if(params && sizeof(params) )
   {
   ret+=({ "<FORM method=\"POST\">" });
   ret+=({ sprintf("%O",query->request->variables) });
   ret+=({ "<input type=\"hidden\" name=\"formref\" value=\""+name+"\" />" });
   ret+=({ "<table>" });
   foreach( params, array param )
   {
      switch( param[1] )
      {
         case PARAM_STRING:
         case PARAM_INT:
         {
         string value= sizeof(param)>5?(string)param[5]:(string)param[2];
         ret+=({ 
                 sprintf("<tr><td>%s</td><td>"+
                         "<input type=\"text\" name=\"%s\" value=\"%s\" />"+
                         "</td></tr>",(string) param[3],(string) param[0],value),
               });
         }
         break;
         case PARAM_BOOLEAN:
         {
         int value= sizeof(param)>5?(int)param[5]:(int)param[2];
         ret+= ({ sprintf("<tr><td>%s</td><td>",(string) param[3]),
                  sprintf("<select name=\"%s\">",param[0]),
                  sprintf("<option value=\"0\" %s>Off</option>",
                                               value==0?"selected":""),
                  sprintf("<option value=\"1\" %s>On</option>",
                                               value==1?"selected":""),
                  "</select></td></tr>",
                });
         }
         break;
         case PARAM_SENSOROUTPUT:
         case PARAM_SENSORINPUT:
         {
         string value= sizeof(param)>5?(string)param[5]:(string)param[2];
         werror("%s\n",value);
         ret+= ({ sprintf("<tr><td>%s</td><td>",(string) param[3]),
                  sprintf("<select name=\"%s\">",param[0]), });
         array sensors = webserver->xmlrpc( "server", COM_SENSLIST, 0 );
         sensors = sort(sensors);
         foreach( sensors, string sensor )
         {
            //FIXME I should be able to designate output variables from input values
            mapping info = webserver->info(sensor,0);
            if( info->sensor_type &  (param[1]==PARAM_SENSOROUTPUT?SENSOR_OUTPUT:SENSOR_INPUT) )
            {
               foreach( indices(info), string key )
               {
                  if( key=="module" || key=="name" || key=="sensor_type" )
                     continue;
                  string sname = info->name +"."+key;
                  ret+=({ sprintf("<option value=\"%s\" %s>%s</option>",
                                    sname,sname==value?"selected":"",sname)});
               }
            }
         }
         ret+=({         "</select></td></tr>",
                });
         }
         break;
         case PARAM_SCHEDULE:
         {
         ret+= ({ sprintf("<tr><td>%s</td><td>",(string) param[3]),
                     "<table>"
                 });
         int count=0;
         //If there was no form-post fill the form with database variables.
         if ( ! has_index( query->entities->form,"schedule_"+param[0] ) )
         {
            array theschedule= sizeof(param)>5?param[5]:([]);
            foreach( theschedule, mapping schedule )
            {
               count++;
               ret+=makescheduleline(count,param[0],(string) schedule->start,
                                     (string) schedule->dow, 
                                     (string) schedule->value );
            }  
         }
         else
         {
            int formcount = (int) query->entities->form["schedule_"+param[0]];
            for( int i = 1; i<=formcount; i++ )
            {
               string findit = param[0]+"_"+(string) i;
               //remove empty lines.
               if( !query->entities->form["start_"+findit] || 
                   query->entities->form["start_"+findit]=="" )
                  continue;
               count++;
               ret+=makescheduleline(count, param[0],
                        (string) query->entities->form["start_"+findit],
                        (string) query->entities->form["dow_"+findit],
                        (string) query->entities->form["value_"+findit]);
            }
         }
         count++;
         ret+= makescheduleline(count,param[0],"","","");
         ret += ({"<tr><td><input type=\"submit\" name=\"Add Schedule\" value=\"add_schedule\" /></td></tr>"});
         ret+=({"</table>"});
         ret += ({ sprintf("<input type=\"hidden\" name=\"schedule_%s\" value=\"%d\" ",param[0],count) });
         }
         break;
         default:
         ret+=({ 
                 sprintf("<tr><td>%s</td><td>"+
                         "Unknown Parameters Type"+
                         "</td></tr>",param[3]),
               });
   
      }
   }
   ret+=({ "<tr><td>&nbsp;</td><td><input type=\"submit\" name=\"Save\" value=\"Save\" /></td></tr>" }); 
   ret+=({ "</table>" });
   ret+=({ "</FORM>" });
   } //No Params.


 
   //Check if this is a module, and check if it contains sensor's, 
   //then list them
//   if( sizeof(name_split) == 1 && 

   return ret;
}

protected array makescheduleline(int i, string name, string start, string dow, string output)
{
   array ret = ({
"<tr>",
sprintf("<td>Start in Minutes<input type=\"text\" name=\"start_%s_%d\" value=\"%s\" /></td>",name,i,start),
sprintf("<td>Day Of the Week<input type=\"text\" name=\"dow_%s_%d\" value=\"%s\"/></td>",name,i,dow),
sprintf("<td>Output Value <input type=\"text\" name=\"value_%s_%d\" value=\"%s\"/></td>",name,i,output),
"</tr>"
               });
   return ret;
}

array DMLModule(Parser.HTML p, mapping args, mapping query )
{
   string scope= args->scope || "form";
   string ret="";
   if( has_index(args,"save" ) )
   {
      if( !has_index(args,"name") )
         return ({});
      mapping tosave=([]);
      array params = webserver->parameters(args->name);
      foreach( params, array par )
      {
         if( has_index( query->entities[scope], par[0] ) )
         {
            tosave+=([ par[0]:query->entities[scope][par[0]] ]);
         }
      }
       params = webserver->xmlrpc( args->name, COM_PARAM, tosave );
   }
   else if( has_index(args,"add") )
   {
      if( !has_index(args, "module" ) || !has_index( args, "name" ) )
         return ({});
      array params;
      foreach( webserver->compilemodules( 0 ), mapping mod )
      {
         if( args->module == mod->name )
            params = mod->parameters;
      }
      string name = args->name;
      mapping tosave = ([
                        "module":query->entities[scope]["module"]
                        ]);
      foreach(params, array param)
      {
         if ( has_index( query->entities->form, param[0] ) )
            tosave+=([ param[0]:query->entities[scope][param[0]] ]);
      }
   }
   else if( has_index(args,"drop") )
   {
      if( has_index ( args, "name" ) )
         webserver->dropmodule(args->name);
   }
   else if( has_index(args,"reload") )
   {
      if( has_index ( args, "name" ) )
         webserver->reloadmodule(args->name);
   }
   return ({});
}


array DMLSensor(Parser.HTML p, mapping args, mapping query )
{
   string scope= args->scope || "form";
   string ret="";
   if( has_index(args,"add") )
   {
      if( !has_index(args, "module" ) || !has_index( args, "name" ) )
         return ({});
      array sensors = webserver->xmlrpc( args->module, COM_SENSLIST, ([ "new":1, "manual":args->manual?1:0 ]) );

      foreach(sensors, mapping sens)
      {
         if( sens->sensor == args->sensor )
         {
            string name = args->module+"."+args->name;
            werror("%s\n",name);
            mapping tosave = ([ "sensor":args->sensor, "module":args->module ]);
            foreach( sens->parameters, array par )
            {
               if( has_index( query->entities[scope], par[0] ) )
               {
                  switch(par[1])
                  {
                     case PARAM_SCHEDULE:
                     array schedule = ({});
                     if( has_index(args,schedule) )
                     {
                        for( int i = 1; i <= (int) args->schedule; i++ )
                        {
                           schedule+=({ ([
                                      "start": args[sprintf("start_%d",i)],
                                      "dow": args[sprintf("dow_%d",i)],
                                      "Output": args[sprintf("output_%d",i)],
                                     ]) });
                        }
                     }
                     break;
                     default:
                     tosave+=([ par[0]:query->entities[scope][par[0]] ]);
                  }
               }
            }
            webserver->addsensor(name,tosave);
            break;
         }
      }
   }
   if( has_index(args,"drop") )
   {
      webserver->dropsensor(args->name);
   }
   return ({});
}

