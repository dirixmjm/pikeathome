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

array DMLConfiguration(Parser.HTML p, mapping args, mapping query )
{

   string name = args->name || "webserver";

   if(!name || !sizeof(name) )
      return ({});
   array name_split = webserver->split_module_sensor_value(name);

   //Name should be module or module.sensor
   if( sizeof(name_split) > 2 )
      return ({ "<H1>Error</H1><p>Configuration not available for values" });

   //Find Parameters of the module or sensor.
   array|mapping params = webserver->xmlrpc( args->name, COM_PARAM, 0 );

   if( mappingp(params) && has_index(params,"error"))
      return ({ sprintf("<H1>Server Return An Error</H1><p>%O",params->error) });
   else if( mappingp(params) )
      return ({ "<H1>Error<H1><p>Server returned mapping, array was expected",
                sprintf("%O\n",params) });
     
   //Check for save button, formref and write values.
      werror("%O\n",query->entities); 
   if( has_index( query->entities->form, "Save" ) && 
       has_index( query->entities->form, "formref" ) &&
       query->entities->form->formref == name )
   {
      mapping tosave=form_to_save(params,query,name);

      if(sizeof(tosave))
          params = webserver->xmlrpc( args->name, COM_PARAM, tosave );
   }
  
   if( has_index( query->entities->form, "add_mod_sensor" ) )
   {
      array module_sensors = webserver->xmlrpc( name, COM_LIST, ([ "new":1]) );
      foreach(module_sensors, mapping module_sensor)
      {
         if( has_index(module_sensor, "sensor" ) && has_index( query->entities->form, module_sensor->sensor  ) )
         {
            mapping tosave=form_to_save(module_sensor->parameters,query,module_sensor->sensor);
            if(sizeof(tosave))
            {
               tosave+= ([ "sensor":module_sensor->sensor ]);
               mapping serv = webserver->xmlrpc( args->name, COM_ADD, tosave );
               if( serv && has_index( serv, "error" ) )
                  return ({ "<H1>Error<H1><p>Module or Sensor add failed with:",
                            sprintf("%O\n",serv) });
            }
         }
         else if( has_index(module_sensor, "module" ) && has_index( query->entities->form, module_sensor->module  ) )
         {
            mapping tosave=form_to_save(module_sensor->parameters,query,module_sensor->module);
            if(sizeof(tosave))
            {
               tosave+= ([ "module":module_sensor->module ]);
               mapping serv = webserver->xmlrpc( args->name, COM_ADD, tosave );
               if( serv && has_index( serv, "error" ) )
                  return ({ "<H1>Error<H1><p>Module or Sensor add failed with:",
                            sprintf("%O\n",serv) });
            }
         }
      }
   }

   if( has_index( query->entities->form, "Delete" ) )
   {
      mapping tosave = (["name":query->entities->form->Delete]);
      mapping serv = webserver->xmlrpc( args->name, COM_DROP, tosave);
      //Check that I'm deleting one of my own (server->module, module->sensor)
   } 
   
   array ret = ({});
   //Build form code
   if(params && arrayp(params)  )
   {
      ret+=({ "<FORM method=\"POST\">" });
      ret+=({ sprintf("%O",query->request->variables) });
      ret+=({ "<input type=\"hidden\" name=\"formref\" value=\""+name+"\" />" });
      ret+=({ "<table>" });
      foreach( params, array param )
      {
         ret+=({  sprintf("<tr><td>%s</td><td>",(string) param[3] ) });
         ret+= make_form_input(param,query,name);
         ret+= ({ "</td></tr>" });
      }
      ret+=({ "<tr><td>&nbsp;</td><td><input type=\"submit\" name=\"Save\" value=\"Save\" />" }); 
      if( sizeof(name_split) == 1 )
      {
         if( name=="webserver" || name=="server" )
            ret+=({ "<input type=\"submit\" name=\"find_sensor\" value=\"Add Module\" /></td></tr>" }); 
         else   
            ret+=({ "<input type=\"submit\" name=\"find_sensor\" value=\"Add Sensor\" /></td></tr>" }); 
      }
      ret+=({ "</table>" });
      ret+=({ "</FORM>" });
   } //FIXME No Params.
   else
   {
      ret+= ({ "<H1>This Module Has No Parameters</H1>\n" });
   }

   //Check if this is a module, and check if it contains sensor's, 
   //then list them
   if( sizeof(name_split) == 1 ) 
   {
      array module_sensors = ({});
      if( name == "webserver" )
         module_sensors = ({});
      else
      //FIXME make general "module_sensor_list" command
         module_sensors = webserver->xmlrpc( name, COM_LIST, 0 );
      ret+=({ "<FORM method=\"POST\" > " });
      ret+=({ "<input type=\"hidden\" name=\"update_mod_sensor\" value=\"1\"/>" });
      ret+=({ "<table border=\"1\">" });
      foreach( module_sensors, string sensor )
      {
         array module_sensor_split = webserver->split_module_sensor_value(sensor);
         string module_sensor_name = "";
         if( sizeof(module_sensor_split) == 2 )
            module_sensor_name = module_sensor_split[1];
         else 
            module_sensor_name = sensor;

         ret+=({ "<tr><td align=\"left\" >"});
         ret+=({ sprintf("<a href=\"module.dml?name=%s\">%s</a>",sensor,module_sensor_name ) });
         ret+=({ "</td>" });
         array params = webserver->xmlrpc( sensor, COM_PARAM, 0  );
         foreach( params, array param )
         {
            ret+=({ sprintf( "<td align=\"lef\">%s&nbsp;",(string) param[0]) });
            ret+= make_form_input(param,query,sensor);
            ret+= ({ "</td>"});
         }
         ret+= ({ sprintf("<td><input type=\"submit\" name=\"%s\""+
                                  " value=\"Update\" /></td>",sensor) });
         ret+=({ "<td>" });
         ret+=({ sprintf("<a href=\"module.dml?name=%s&Delete=%s\"><img src=\"/icons/Delete.png\" height=\"15px\" /></a>",name,sensor ) });

         ret+=({ "</td></tr>" });

      } 
      ret+=({ "</FORM> " });
      ret+=({ "</table>" });
      //List sensors That can be added
      if( has_index( query->entities->form, "find_sensor" ) )
      {
         array module_sensors = webserver->xmlrpc( name, COM_LIST, ([ "new":1]) );
         ret+=({ "<FORM method=\"POST\">" });
         ret+=({ "<input type=\"hidden\" name=\"add_mod_sensor\" value=\"1\"/>" });
         ret+=({ "<table border=\"1\">" });
         foreach(module_sensors, mapping module_sensor)
         {
            ret+=({ "<tr><td align=\"left\" >"});
             //FIXME else? 
            if( has_index( module_sensor, "sensor" ) )
               ret+=({ sprintf("%s",module_sensor->sensor ) });
            else if( has_index( module_sensor, "module" ) )
               ret+=({ sprintf("%s",module_sensor->module ) });
            if( has_index( module_sensor, "error" ) )
            {
               ret+=({ sprintf( "<td align=\"lef\" colspan=\"10\">%s</td>",(string) module_sensor->error) });
            }
            else
            {
               foreach( module_sensor->parameters, array param )
               {
                  ret+=({ sprintf( "<td align=\"lef\">%s&nbsp;",(string) param[0]) });
                  //FIXME else? 
                  if( has_index( module_sensor, "sensor" ) )
                     ret+= make_form_input(param,query,module_sensor->sensor);
                  else if( has_index( module_sensor, "module" ) )
                     ret+= make_form_input(param,query,module_sensor->module);
                  ret+= ({ "</td>"});
               }
               if( has_index( module_sensor, "sensor" ) )
               {
                  ret+= ({ sprintf("<td><input type=\"submit\" name=\"%s\""+
                                  " value=\"Add\" /></td>",module_sensor->sensor) });
               }
               else if( has_index( module_sensor, "module" ) )
               {
                  ret+= ({ sprintf("<td><input type=\"submit\" name=\"%s\""+
                                  " value=\"Add\" /></td>",module_sensor->module) });
               }
            }
            ret+=({ "</tr>" });
         }
         ret+=({ "</table>" });
         ret+=({ "</FORM>" });
      }
   }

   return ret;
}

mapping form_to_save(array params, mapping query, string name)
{
   mapping tosave=([]);
   foreach(params, array param)
   {
      string inname = (string) hash( name + (string) param[0] );
      switch( param[1] )
      {
         case PARAM_SENSOROUTPUT:
         case PARAM_SENSORINPUT:
         case PARAM_STRING:
         //Don't save if the paramater hasn't changed
         if( has_index(query->entities->form, inname) && 
             (sizeof(param)<6 || 
                        param[5] != query->entities->form[inname]))
            tosave+=([ param[0]:query->entities->form[inname] ]);
         break;
         case PARAM_INT:
         case PARAM_BOOLEAN:
         //Don't save if the paramater hasn't changed
         if( has_index(query->entities->form, inname) && 
             (sizeof(param)<6 || 
                        (int) param[5] != (int) query->entities->form[inname]))
            tosave+=([ param[0]:(int) query->entities->form[inname] ]);
         break;
         case PARAM_SCHEDULE:
            if( !has_index(query->entities->form,"schedule_"+inname) )
               continue;
            int count = (int) query->entities->form["schedule_"+inname];
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
   return tosave;
}

//param contains the parameters, name is the hash seed.
array make_form_input(array param, mapping query, string name)
{
   array ret=({});
   string inname = (string) hash( name + (string) param[0] );
   switch( param[1] )
   {
   case PARAM_STRING:
   case PARAM_INT:
   {
      string value= sizeof(param)>5?(string)param[5]:(string)param[2];
      ret= ({ sprintf("<input type=\"text\" name=\"%s\" value=\"%s\" />"
                         ,inname,value) });
   }
   break;
   case PARAM_BOOLEAN:
   {
      int value= sizeof(param)>5?(int)param[5]:(int)param[2];
      ret= ({ sprintf("<select name=\"%s\">",inname),
           sprintf("<option value=\"0\" %s>Off</option>",
                                               value==0?"selected":""),
           sprintf("<option value=\"1\" %s>On</option></select>",
                                               value==1?"selected":"") });
   }
   break;
   case PARAM_SENSOROUTPUT:
   case PARAM_SENSORINPUT:
   {
      string value= sizeof(param)>5?(string)param[5]:(string)param[2];
      ret+= ({ sprintf("<select name=\"%s\">",inname), });
      array sensors = webserver->xmlrpc( "server", COM_LIST, 0 );
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
      ret+=({ "</select>"});
   }
   break;
   case PARAM_SCHEDULE:
   {
      ret+= ({ "<table>"});
      int count=0;
      //If there was no form-post fill the form with database variables.
      if ( ! has_index( query->entities->form,"schedule_"+inname ) )
      {
         array theschedule= sizeof(param)>5?param[5]:([]);
         foreach( theschedule, mapping schedule )
         {
            count++;
            ret+=makescheduleline(count,inname,(string) schedule->start,
                                  (string) schedule->dow, 
                                  (string) schedule->value );
         }  
      }
      else
      {
         int formcount = (int) query->entities->form["schedule_"+inname];
         for( int i = 1; i<=formcount; i++ )
         {
            string findit = inname+"_"+(string) i;
            //remove empty lines.
            if( !query->entities->form["start_"+findit] || 
                query->entities->form["start_"+findit]=="" )
               continue;
            count++;
            ret+=makescheduleline(count, inname,
                     (string) query->entities->form["start_"+findit],
                     (string) query->entities->form["dow_"+findit],
                     (string) query->entities->form["value_"+findit]);
         }
      }
      count++;
      ret+= makescheduleline(count,inname,"","","");
      ret += ({"<tr><td><input type=\"submit\" name=\"Add Schedule\" value=\"add_schedule\" /></td></tr>"});
      ret+=({"</table>"});
      ret += ({ sprintf("<input type=\"hidden\" name=\"schedule_%s\" value=\"%d\" ",inname,count) });
   }
   break;
   default:
      ret+=({ sprintf( "Unknown Parameters Type" ) });
   }
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
