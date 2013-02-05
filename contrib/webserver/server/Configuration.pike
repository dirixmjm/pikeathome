#include <module.h>
#include <sensor.h>
#include <parameters.h>
#include <variable.h>

inherit DMLModule;



mapping tags = ([
"configuration": DMLConfiguration,
]);

mapping emit = ([
]);

mapping containers = ([
]);



array DMLConfiguration(Parser.HTML p, mapping args, mapping query )
{
   array ret = ({});
   ret+= ({ "<div class=\"modules\">",
            "&nbsp;Modules<br />"});
   //First start with the webserver 
   ret+= ({ sprintf("<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",dml->servername,dml->servername) });
   array|mapping module_sensors = dml->rpc( dml->servername, COM_LIST );
   if( mappingp(module_sensors) && has_index(module_sensors,"error") )
      ret+=({ module_sensors->error });
   else if ( arrayp(module_sensors) ) 
   {
      foreach( sort(module_sensors) , string module_sensor )
      {
         ret+= ({ sprintf("&nbsp;<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",module_sensor,module_sensor) });
      }
   }
   // Next list all peers
   foreach( sort(indices(configuration->peers || ({}))), string peername )
   {
      ret+= ({ sprintf("<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",peername,peername) });
      array|mapping module_sensors = dml->rpc( peername, COM_LIST );
      if( mappingp(module_sensors) && has_index(module_sensors,"error") )
         ret+=({ module_sensors->error });
      else if ( arrayp(module_sensors) ) 
      {
         foreach( sort(module_sensors) , string module_sensor )
         {
            ret+= ({ sprintf("&nbsp;<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",module_sensor,module_sensor) });
         }
      }
   }
   ret+= ({ "</div>"});
   ret += ({ "<div class=\"main\">" });
   ret += get_main_configuration(p,args,query);
   ret += ({ "</div>" });
   return ret;
}


array get_main_configuration( Parser.HTML p, mapping args, mapping query )
{
   //Set name to the value of the current object we're configuring
   string name = query->entities ->form->name || dml->servername;

   if(!name || !sizeof(name) )
      return ({});
   array name_split = split_server_module_sensor_value(name);

   //Name should be module or module.sensor
   if( sizeof(name_split) > 3 )
      return ({ "<H1>Error</H1><p>Configuration not available for values" });

   //Find Parameters of the module or sensor.
   array|mapping params = dml->rpc( name , COM_PARAM );
   //Find Runtime Properties of the module or sensor.
   array|mapping prop = dml->rpc( name , COM_PROP );

   if( mappingp(params) && has_index(params,"error"))
      return ({ sprintf("<H1>Server Return An Error</H1><p>%O",params->error) });
   else if( mappingp(params) )
      return ({ "<H1>Error<H1><p>Server returned mapping, array was expected",
                sprintf("%O\n",params) });
     
   //Check for save button, formref and write values.
   if( has_index( query->entities->form, "Save" ) && 
       has_index( query->entities->form, "formref" ) &&
       query->entities->form->formref == name )
   {
      mapping tosave=form_to_save(params,query,name);

      if(sizeof(tosave))
          params = dml->rpc( name , COM_PARAM, tosave );
   }
  
   if( has_index( query->entities->form, "add_mod_sensor" ) )
   {
      array|mapping module_sensors = dml->rpc( name, COM_FIND );
      if( mappingp(module_sensors) && has_index(module_sensors,"error"))
         return ({ sprintf("<H1>Server Return An Error</H1><p>%s",module_sensors->error) });
      foreach(sort(module_sensors), mapping module_sensor)
      {
         if( has_index(module_sensor, "name" ) && has_index( query->entities->form, module_sensor->name  ) )
         {
            mapping tosave=form_to_save(module_sensor->parameters,query,name+module_sensor->name);
            if(sizeof(tosave))
            {
               string inname = (string) hash( name+module_sensor->name + "name" );
               string newname;
               if( has_index(query->entities->form, inname) )
                  newname = query->entities->form[inname];
               else
                  //No Name field is given, continue
                  break;
               mapping parameters= ([ "name":newname, "parameters":tosave ]);
               mapping serv = dml->rpc( name, COM_ADD, parameters );
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
      mapping serv = dml->rpc( name, COM_DROP, tosave);
      //Check that I'm deleting one of my own (server->module, module->sensor)
   } 
   
   array ret = ({});
   //Build form code
   if(params && arrayp(params)  )
   {
      ret+=({ "<FORM method=\"POST\">" });
      if( (int) configuration->debug )
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
      //FIXME this should be configurable
      if( sizeof(name_split) == 1 )
         ret+=({ "<input type=\"submit\" name=\"find_sensor\" value=\"Add Module\" /></td></tr>" }); 
      else if ( sizeof(name_split) == 2 && mappingp(prop) && 
                (prop["module_type"] & (MODULE_SENSOR |MODULE_SCHEDULE)))
         ret+=({ "<input type=\"submit\" name=\"find_sensor\" value=\"Add Sensor\" /></td></tr>" }); 
      ret+=({ "</table>" });
      ret+=({ "</FORM>" });
   } //FIXME No Params.
   else
   {
      ret+= ({ "<H1>This Module Has No Parameters</H1>\n" });
   }

   //Check if this is a server or a module, and check if it contains sensor's, 
   //then list them
   if( sizeof(name_split) <= 2 ) 
   {
      array|mapping module_sensors = dml->rpc( name, COM_LIST );
      if( mappingp(module_sensors) && has_index(module_sensors,"error"))
         return ({ sprintf("<H1>Server Returned An Error</H1><p>%s",module_sensors->error) });
      ret+=({ "<FORM method=\"POST\" > " });
      ret+=({ "<input type=\"hidden\" name=\"update_mod_sensor\" value=\"1\"/>" });
      ret+=({ "<table border=\"1\">" });
      foreach( sort(module_sensors || ({})), string sensor )
      {
         array module_sensor_split = split_server_module_sensor_value(sensor);
         string module_sensor_name = "";
         if( sizeof(module_sensor_split) == 3 )
            module_sensor_name = module_sensor_split[2];
         else 
            module_sensor_name = sensor; 
         array params = dml->rpc( sensor , COM_PARAM );
         //Check if there was an update for this sensor
         if( has_index( query->entities->form, "update_mod_sensor" ) &&
             has_index( query->entities->form, sensor ) &&
             query->entities->form[sensor] == "Update" && params)
         {
            mapping tosave=form_to_save(params,query,sensor);
            if(sizeof(tosave))
               dml->rpc( sensor , COM_PARAM, tosave );
         }

         ret+=({ "<tr><td align=\"left\" >"});
         ret+=({ sprintf("<a href=\"index.dml?name=%s\">%s</a>",sensor,module_sensor_name ) });
         ret+=({ "</td>" });
         if ( (int) configuration->inlineconfig == 1 )
         {
            foreach( params|| ({}), array param )
            {
               ret+=({ sprintf( "<td align=\"lef\">%s&nbsp;",(string) param[0]) });
               ret+= make_form_input(param,query,sensor);
               ret+= ({ "</td>"});
            }
            ret+= ({ sprintf("<td><input type=\"submit\" name=\"%s\""+
                                  " value=\"Update\" /></td>",sensor) });
         }
         ret+=({ "<td>" });
         ret+=({ sprintf("<a href=\"index.dml?name=%s&Delete=%s\"><img src=\"/icons/Delete.png\" height=\"15px\" /></a>",name,sensor ) });

         ret+=({ "</td></tr>" });

      } 
      ret+=({ "</FORM> " });
      ret+=({ "</table>" });
      //List sensors That can be added
      if( has_index( query->entities->form, "find_sensor" ) )
      {
         array|mapping module_sensors = dml->rpc( name, COM_FIND );
         if( mappingp(module_sensors) && has_index(module_sensors,"error"))
            return ({ sprintf("<H1>Server Return An Error</H1><p>%s",module_sensors->error) });
         ret+=({ "<FORM method=\"POST\">" });
         ret+=({ "<input type=\"hidden\" name=\"add_mod_sensor\" value=\"1\"/>" });
         ret+=({ "<table border=\"1\">" });
         foreach(sort(module_sensors+({})), mapping module_sensor)
         {
            ret+=({ "<tr><td align=\"left\" >"});
             //FIXME sensor sends name, module too? 
            if( has_index( module_sensor, "name" ) )
            {
               array param = ({ "name",PARAM_STRING,module_sensor->name,"Name", 
                                module_sensor->name });
               ret+= make_form_input(param,query,name+module_sensor->name);
               //ret+=({ sprintf("%s",module_sensor->name ) });
            }
            else
               //If there is no name we can't distinguish it.
               continue;

            if( mappingp(module_sensor) && has_index( module_sensor, "error" ) )
            {
               ret+=({ sprintf( "<td align=\"lef\" colspan=\"10\">%s</td>",(string) module_sensor->error) });
            }
            else
            {
               foreach( module_sensor->parameters, array param )
               {
                  ret+=({ sprintf( "<td align=\"lef\">%s&nbsp;",(string) param[0]) });
                  ret+= make_form_input(param,query,name+module_sensor->name);
                  ret+= ({ "</td>"});
               }
               ret+= ({ sprintf("<td><input type=\"submit\" name=\"%s\""+
                               " value=\"Add\" /></td>",module_sensor->name) });
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
         if( has_index(query->entities->form, inname)) 
            tosave+=([ param[0]:query->entities->form[inname] ]);
         break;
         case PARAM_INT:
         case PARAM_BOOLEAN:
         //Don't save if the paramater hasn't changed
         if( has_index(query->entities->form, inname) )
            tosave+=([ param[0]:(int) query->entities->form[inname] ]);
         break;
         case PARAM_ARRAY:
         {
            if( !has_index(query->entities->form,"array_"+inname))
               continue;
            int count = (int) query->entities->form["array_"+inname];
            array Values = ({});
            for( int i = 1; i<=count; i++ )
            {
               string findit = inname+"_value_"+(string) i;
               //remove empty lines.
               if( !query->entities->form[findit] || 
                  query->entities->form[findit]=="" )
               continue;
               Values += ({ query->entities->form[findit] 
                         });
            }
            tosave+=([ param[0]:Values ]);
         }
         break;
         case PARAM_MAPPING:
         {
            if( !has_index(query->entities->form,"mapping_"+inname))
               continue;
            int count = (int) query->entities->form["mapping_"+inname];
            mapping Values = ([]);
            for( int i = 1; i<=count; i++ )
            {
               string findit = inname+"_index_"+(string) i;
               //remove empty lines.
               if( !query->entities->form[findit] || 
                  query->entities->form[findit]=="" )
               continue;
               Values += ([ query->entities->form[findit]: 
                            query->entities->form[inname+"_value_"+(string) i]
                         ]);
            }
            tosave+=([ param[0]:Values ]);
         }
         break;
         case PARAM_SCHEDULE:
         {
            if( !has_index(query->entities->form,"schedule_"+inname) )
               continue;
            int count = (int) query->entities->form["schedule_"+inname];
            array(mapping) theschedule = ({});
            for( int i = 1; i<=count; i++ )
            {
               string findit = inname+"_"+(string) i;
               //remove empty lines.
               if( !query->entities->form["start_"+findit] || 
                  query->entities->form["start_"+findit]=="" )
               continue;
               theschedule+= ({ ([
                             "start":query->entities->form["start_"+findit],
                             "dow":query->entities->form["dow_"+findit],
                             "value":query->entities->form["value_"+findit],
                             "antedate":query->entities->form["antedate_"+findit]
                             ])});   
            }
            tosave+=([ param[0]:theschedule ]);
         }
         break;
         default:
            logerror("Can't save unknown paramter type\n");
      }
   }
   return tosave;
}

//param contains the parameters, name is the hash seed.
array make_form_input(array param, mapping query, string name)
{
   array ret=({});
   array name_split = split_server_module_sensor_value(name);
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
      array|mapping sensors = dml->rpc( name_split[0], COM_ALLSENSOR, 0 );
      if( mappingp(sensors) && has_index(sensors,"error"))
         return ({ sprintf("<H1>Server Return An Error</H1><p>%s",sensors->error) });
      sensors = sort(sensors + ({}) );
      foreach( sort(sensors), string sensor )
      {
         //FIXME I should be able to designate output variables from input values
         mapping prop = dml->rpc(sensor,COM_PROP);
         if( mappingp(prop) && prop->sensor_type &  (param[1]==PARAM_SENSOROUTPUT?SENSOR_OUTPUT:SENSOR_INPUT) )
         {
            mapping vars = dml->rpc(sensor,COM_READ) +([]);
            //vars = sort(vars);
            foreach( indices(vars), string key )
            {
               if( param[1] == PARAM_SENSOROUTPUT && vars[key]->direction == DIR_RO )
                  continue;
               string sname = prop->name +"."+key;
               ret+=({ sprintf("<option value=\"%s\" %s>%s</option>",
                                 sname,sname==value?"selected":"",sname)});
            }
         }
      }
      ret+=({ "</select>"});
   }
   break;
   case PARAM_ARRAY:
   {
      ret+= ({ "<table>"});
      array Values = ({});
      if( sizeof(param)>5 && param[5] )
         Values = param[5];
      int count = 0;
      foreach( Values; string index; string value )
      {
         count++;
         string svalue = inname+"_value_"+(string) count;
         ret += ({ "<tr><td>" });
         ret += ({ sprintf("<input type=\"text\" name=\"%s\" value=\"%s\" />"
                         ,svalue,value) });
         ret += ({ "</td></tr>" });

      }
      count++;
      string svalue = inname+"_value_"+(string) count;
      ret += ({ "<tr><td>" });
      ret += ({ sprintf("<input type=\"text\" name=\"%s\" />"
                      ,svalue) });
      ret += ({ "</td></tr>" });
      ret+=({"</table>"}); 
      ret += ({ sprintf("<input type=\"hidden\" name=\"array_%s\" value=\"%d\" ",inname,count) });
   }
   break;
   case PARAM_MAPPING:
   {
      ret+= ({ "<table>"});
      mapping Values = ([]);
      if( sizeof(param)>5 && param[5] )
         Values = param[5];
      int count = 0;
      foreach( Values; string index; string value )
      {
         count++;
         string sindex = inname+"_index_"+(string) count;
         string svalue = inname+"_value_"+(string) count;
         ret += ({ "<tr><td>" });
         ret += ({ sprintf("<input type=\"text\" name=\"%s\" value=\"%s\" />"
                         ,sindex,index) });
         ret += ({ "</td><td>" });
         ret += ({ sprintf("<input type=\"text\" name=\"%s\" value=\"%s\" />"
                         ,svalue,value) });
         ret += ({ "</td></tr>" });

      }
      count++;
      string sindex = inname+"_index_"+(string) count;
      string svalue = inname+"_value_"+(string) count;
      ret += ({ "<tr><td>" });
      ret += ({ sprintf("<input type=\"text\" name=\"%s\" />"
                       ,sindex) });
      ret += ({ "</td><td>" });
      ret += ({ sprintf("<input type=\"text\" name=\"%s\" />"
                      ,svalue) });
      ret += ({ "</td></tr>" });
      ret+=({"</table>"}); 
      ret += ({ sprintf("<input type=\"hidden\" name=\"mapping_%s\" value=\"%d\" ",inname,count) });
   }
   break;
   case PARAM_SCHEDULE:
   {
      ret+= ({ "<table>"});
      int count=0;
      //If there was no form-post fill the form with database variables.
      if ( ! has_index( query->entities->form,"schedule_"+inname ) )
      {
         array theschedule= ({});
         if( sizeof(param)>5 && param[5] )
            theschedule = param[5];

         foreach( theschedule, mapping schedule )
         {
            count++;
            ret+=makescheduleline(count,inname,(string) schedule->start,
                                  (string) schedule->dow, 
                                  (string) schedule->value,
                                  (string) schedule->antedate );
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
                     (string) query->entities->form["value_"+findit],
                     (string) query->entities->form["antedate_"+findit]);
         }
      }
      count++;
      ret+= makescheduleline(count,inname,"","","","");
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

protected array makescheduleline(int i, string name, string start, string dow, string output,string antedate)
{
   array ret = ({
"<tr>",
sprintf("<td>Start in Minutes<input type=\"text\" name=\"start_%s_%d\" value=\"%s\" /></td>",name,i,start),
sprintf("<td>Day Of the Week<input type=\"text\" name=\"dow_%s_%d\" value=\"%s\"/></td>",name,i,dow),
sprintf("<td>Output Value <input type=\"text\" name=\"value_%s_%d\" value=\"%s\"/></td>",name,i,output),
sprintf("<td>Antedate <input type=\"text\" name=\"antedate_%s_%d\" value=\"%s\"/></td>",name,i,antedate),
"</tr>"
               });
   return ret;
}
