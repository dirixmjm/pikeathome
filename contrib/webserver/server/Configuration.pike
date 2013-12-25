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
   //Set name to the value of the current object we're configuring
   string name = query->entities ->form->name || dml->servername;

   array ret = ({});
   ret+= ({ "<div class=\"modules\">",
            "&nbsp;Modules<br />"});
   //First start with the webserver 
   ret+= ({ sprintf("<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",dml->servername,dml->servername) });
   array|mapping modules = dml->rpc( dml->servername, COM_LIST );
   if( mappingp(modules) && has_index(modules,"error") )
      ret+=({ modules->error });
   else if ( arrayp(modules) ) 
   {
      foreach( sort(modules) , string module )
      {
         array module_split = split_server_module_sensor_value(module); 
         ret+= ({ sprintf("&nbsp;<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",module,module_split[1]) });
      }
   }
   // Next list all peers
   foreach( sort(indices(configuration->peers || ({}))), string peername )
   {
      ret+= ({ sprintf("<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",peername,peername) });
      array|mapping modules = dml->rpc( peername, COM_LIST );
      if( mappingp(modules) && has_index(modules,"error") )
         ret+=({ modules->error });
      else if ( arrayp(modules) ) 
      {
         foreach( sort(modules) , string module )
         {
            array module_split = split_server_module_sensor_value(module); 
            ret+= ({ sprintf("&nbsp;<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",module,module_split[1]) });
            if( has_prefix(name, module) )
            {
               array|mapping sensors = dml->rpc( module, COM_LIST );
               if( mappingp(sensors) && has_index(sensors,"error") )
                  ret+=({ sensors->error });
               if( arrayp(sensors) )
                  foreach( sort(sensors) , string sensor )
                  {
                     array sensor_split = split_server_module_sensor_value(sensor); 
                     ret+= ({ sprintf("&nbsp;&nbsp;<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",sensor,sensor_split[2]) });
                     if( has_prefix(name, sensor))
                     {
                        array|mapping variables = dml->rpc( sensor, COM_READ );
                        if( mappingp( variables))
                           foreach( sort(indices(variables)) , string variable )
                           {
                              ret+= ({ sprintf("&nbsp;&nbsp;&nbsp;<a href=\"/configuration/index.dml?name=%s\">%s</a><br />",sensor+"."+variable,variable) });
                           }
                     }
                  }
            }
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

   //Find Parameters of the module or sensor.
   array|mapping params = dml->rpc( name , COM_PARAM );
   //Find Runtime Properties of the module or sensor.
   array|mapping prop = dml->rpc( name , COM_PROP );

   if( mappingp(params) && has_index(params,"error"))
      return ({ sprintf("<H1>Server Returned An Error</H1><p>%O",params->error) });
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
         return ({ sprintf("<H1>Server Returned An Error</H1><p>%s",module_sensors->error) });
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
      mapping tosave = (["name":name]);
      //A Delete should be send to one layer up.
      mapping serv = dml->rpc( name_split[0..sizeof(name_split)-2]*".", COM_DROP, tosave);
      //Check that I'm deleting one of my own (server->module, module->sensor)
   } 
   
   array ret = ({});
   //Build form code
   if( params && arrayp(params) )
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
      else if ( sizeof(name_split) == 2)
      { 
      if( mappingp(prop) && 
                (prop["module_type"] & (MODULE_SENSOR |MODULE_SCHEDULE)))
         ret+=({ "<input type=\"submit\" name=\"find_sensor\" value=\"Add Sensor\" />" }); 
         ret+=({ "<input type=\"submit\" name=\"Delete\" value=\"Delete Module\" /></td></tr>" }); 
      }
      else if ( sizeof(name_split) == 3)
         ret+=({ "<input type=\"submit\" name=\"Delete\" value=\"Delete Sensor\" /></td></tr>" }); 

      ret+=({ "</table>" });
      ret+=({ "</FORM>" });
   }
   //Variable
   else if ( sizeof(name_split) == 4 ) 
   {
      array|mapping variable = dml->rpc( name, COM_READ );
      if( mappingp(variable) && has_index(variable,"error"))
         return ({ sprintf("<H1>Server Returned An Error</H1><p>%s",variable->error) });
      if ( mappingp(variable) )
      {
         ret+=({ "<FORM method=\"POST\">" });
         if( (int) configuration->debug )
            ret+=({ sprintf("%O",query->request->variables) });
         ret+=({ "<input type=\"hidden\" name=\"formref\" value=\""+name+"\" />" });
         ret+=({ "<table border=\"1\" >" });
            ret+=({ "<tr><td>Direction</td><td align=\"left\" >" });
            switch( variable->direction )
            {
               case DIR_RO:
                  ret+=({ "R" });
                  break;
               case DIR_RW:
                  ret+=({ "RW" });
                  break;
               case DIR_WO:
                  ret+=({ "W" });
                  break;
            }
            ret+=({ "</td></tr>" });
            ret+=({ "<tr><td>Type</td><td align=\"left\">" });
            switch( variable->type )
            {
               case VAR_INT:
                  ret+=({ "INT" });
                  break;
               case VAR_FLOAT:
                  ret+=({ "FLOAT" });
                  break;
               case VAR_BOOLEAN:
                  ret+=({ "BOOL" });
                  break;
               case VAR_STRING:
                  ret+=({ "STRING" });
                  break;
            }
            ret+=({ "</td></tr>" });
            ret+=({ "<tr><td>Log</td><td align=\"left\">" });
            ret+=({ "<select name=\"log\">" });
            ret+=({ sprintf("<option value=\"1\" %s>ON",variable->log?"selected":"") });
            ret+=({ sprintf("<option value=\"0\" %s>OFF",variable->log?"":"selected") });
            ret+=({ "</select>" });
            ret+=({ "</td></tr>" });
            ret+=({ "</td></tr>" });
            ret+=({ "<tr><td>Log Time</td><td align=\"left\">" });
            ret+=({ sprintf("<input type=\"text\" value=\"%d\" name=\"logtime\" />",variable->logtime) });
            ret+=({ "<tr><td>&nbsp;</td><td><input type=\"submit\" name=\"SaveVar\" value=\"Save\" />" }); 
         ret+=({ "</table>" });
         ret+=({ "</FORM>" });
      }
   }
   else
   {
      ret+= ({ "<H1>This Module Has No Parameters</H1>\n" });
   }
   if( prop && mappingp(prop))
   {
      if( has_index(prop, "memory" ) )
      {
      ret+=({"<table>"});
         foreach(sort(indices(prop->memory)),string index )
            ret+=({ sprintf("<tr><td>%s</td><td>%d</td></tr>",index,prop->memory[index])});
      ret+=({"</table>"});
      }
      if( has_index(prop, "references" ) )
      {
      ret+=({"<table>"});
         foreach(prop->references;string index; int count )
            ret+=({ sprintf("<tr><td>%s</td><td>%d</td></tr>",index,count)});
      ret+=({"</table>"});
      }
   }
   //Check if this is a server or a module, and check if it contains sensor's, 
   //then list them
   if( sizeof(name_split) <= 2 ) 
   {
      //List sensors That can be added
      if( has_index( query->entities->form, "find_sensor" ) )
      {
         array|mapping module_sensors = dml->rpc( name, COM_FIND );
         if( mappingp(module_sensors) && has_index(module_sensors,"error"))
            return ({ sprintf("<H1>Server Returned An Error</H1><p>%s",module_sensors->error) });
         ret+=({ "<FORM method=\"POST\">" });
         ret+=({ "<input type=\"hidden\" name=\"add_mod_sensor\" value=\"1\"/>" });
         ret+=({ "<table border=\"1\">" });
         foreach(sort(module_sensors || ({})), mapping module_sensor)
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
   /*
   //This is a sensor, list all variables
   else if ( sizeof(name_split) == 3)
   {
         array|mapping variables = dml->rpc( name, COM_READ );
         if( mappingp(variables) && has_index(variables,"error"))
            return ({ sprintf("<H1>Server Returned An Error</H1><p>%s",variables->error) });
         if ( mappingp(variables) )
         {
            ret+=({ "<table border=\"1\">" });
         }
   }
   */

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
         case PARAM_SELECT:
         case PARAM_STRING:
         case PARAM_RO:
         case PARAM_MODULELOGDATA:
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
         case PARAM_SENSOROUTPUTARRAY:
         case PARAM_SENSORINPUTARRAY:
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
   case PARAM_RO:
   {
      string value= sizeof(param)>5?(string)param[5]:(string)param[2];
      ret= ({ sprintf("<input type=\"text\" name=\"%s\" value=\"%s\" readonly />"
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
      array|mapping sensors = dml->rpc( name_split[0], COM_ALLSENSOR, 0 );
      if( ! sensors )
         return ({});
      if( mappingp(sensors) && has_index(sensors,"error"))
         return ({ sprintf("<H1>Server Returned An Error</H1><p>%s",sensors->error) });
      sensors = sort( sensors->name );
      ret += make_sensor_select(inname,sensors,value,param[1]);
   }
   break;
   case PARAM_MODULELOGDATA:
   {
      string value= sizeof(param)>5?(string)param[5]:(string)param[2];
      array|mapping modules = dml->rpc( name_split[0], COM_LIST, 0 );
      if( ! modules )
         return ({});
      if( mappingp(modules) && has_index(modules,"error"))
         return ({ sprintf("<H1>Server Returned An Error</H1><p>%s",modules->error) });
      modules = sort(modules );
      ret += make_module_select(inname,modules,value,param[1]);
   }
   break;
   case PARAM_SENSOROUTPUTARRAY:
   case PARAM_SENSORINPUTARRAY:
   {
      array Values = sizeof(param)>5?param[5]:(param[2]||({}));
      int count = 0;
      array|mapping sensors = dml->rpc( name_split[0], COM_ALLSENSOR, 0 );
      if( ! sensors )
         return ({});
      if( mappingp(sensors) && has_index(sensors,"error"))
         return ({ sprintf("<H1>Server Returned An Error</H1><p>%s",sensors->error) });
      sensors = sort(sensors );
      foreach( Values; string index; string value )
      {
         count++;
         string svalue = inname+"_value_"+(string) count;
         ret += make_sensor_select(svalue,sensors,value,param[1]);
         ret += ({"<br />"});
      }
      count++;
      string svalue = inname+"_value_"+(string) count;
      ret += make_sensor_select(svalue,sensors,"",param[1]);
      ret += ({ sprintf("<input type=\"hidden\" name=\"array_%s\" value=\"%d\" ",inname,count) });
   }
   break;
   case PARAM_ARRAY:
   {
      ret+= ({ "<table>"});
      array Values = sizeof(param)>5?param[5]:(param[2]||({}));
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
      mapping Values = sizeof(param)>5?param[5]:(param[2]||([]));
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
   case PARAM_SELECT:
   {
      string current="";
      if( sizeof(param)>5 && param[5] )
         current = (string) param[5];
      
      ret= ({ sprintf("<select name=\"%s\">",inname) });
      foreach(param[2]; string ind; mixed value )
      {
          ret+=({ sprintf("<option value=\"%s\" %s>%s</option>",
                                               (string) value,((string)value)==current?"selected":"",ind) });
      }
      ret+= ({ "</select>" });
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

protected array make_sensor_select(string inname,array sensors, string value,int type)
{
   int typeoutput = 0;
   if( type == PARAM_SENSOROUTPUT || type == PARAM_SENSOROUTPUTARRAY )
     typeoutput = 1;
   array ret= ({ sprintf("<select name=\"%s\">",inname),
                 "<option value="">No Sensor Selected</option>" });
   foreach( sort(sensors), string sensor )
   {
      mapping prop = dml->rpc(sensor,COM_PROP);
      if( mappingp(prop) && prop->sensor_type &  (typeoutput?SENSOR_OUTPUT:SENSOR_INPUT) )
      {
         mapping vars = dml->rpc(sensor,COM_READ) || ([]);
         //vars = sort(vars);
         foreach( indices(vars), string key )
         {
            if( typeoutput && vars[key]->direction == DIR_RO )
               continue;
            string sname = prop->name +"."+key;
            ret+=({ sprintf("<option value=\"%s\" %s>%s</option>",
                                 sname,sname==value?"selected":"",sname)});
         }
      }
   }
   ret+=({ "</select>"});
   return ret;
}

protected array make_module_select(string inname,array modules, string value,int type)
{
   int moduletype = 0;
   if( type == PARAM_MODULELOGDATA )
      moduletype = MODULE_LOGDATA;
   else if ( type == PARAM_MODULELOGEVENT )
      moduletype = MODULE_LOGEVENT;

   array ret= ({ sprintf("<select name=\"%s\">",inname),
                 "<option value="">No Sensor Selected</option>" });
   foreach( sort(modules), string module )
   {
      mapping prop = dml->rpc(module,COM_PROP);
      if( mappingp(prop) && (prop->module_type & moduletype) )
      {
            string sname = prop->name;
            ret+=({ sprintf("<option value=\"%s\" %s>%s</option>",
                                 sname,sname==value?"selected":"",sname)});
      }
   }
   ret+=({ "</select>"});
   return ret;
}
