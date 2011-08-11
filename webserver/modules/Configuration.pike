#include <module.h>


protected object domotica;
protected object configuration;


mapping tags = ([
"configuration": DMLConfiguration,
]);

mapping emit = ([
"parameters": EmitParameters,
]);

mapping containers = ([
]);


void create( object domi , object Config)
{
   domotica= domi;
   configuration = Config;
}

array EmitParameters( mapping args, mapping query )
{
   if( has_index(args,"name" ) )
   {
       //FIXME Convert to mapping
       return domotica->parameters(args->name);
   }
   return ({});
}

array DMLConfiguration(Parser.HTML p,
               mapping args, mapping query )
{
   string ret="";
   if( has_index(args,"name") )
   {
      array params = domotica->parameters(args->name);
      //Check if the save button was pressed.
      if ( has_index( query->entities->form, "Save") && 
           query->entities->form["Save"] == "save" )
      {
         mapping tosave = ([]);
         foreach(params, array param)
         {
            if ( has_index( query->entities->form, param[0] ) )
               tosave+=([ param[0]:query->entities->form[param[0]] ]);
         }
         params = domotica->write_parameters(args->name, tosave);
      }
      if(!sizeof(params) )
      return ({});
      ret+="<form method='GET'>";
      ret+="<input type='hidden' name='name' value='"+args->name +"' />";
      ret+="<table>";
      domotica->log(LOG_DEBUG,"%O\n",params);
      foreach(params, array param)
      {
         switch(param[1])
         {
         case PARAM_STRING:
            ret+="<tr><td>"+param[3]+"</td><td><input type='text' name='"+param[0]+"' value='"+param[5]+"' /></td></tr>";
            break;
         case PARAM_BOOLEAN:
            ret+="<tr><td>"+param[3]+"</td><td>";
            ret+="<select name='"+param[0]+"'>";
            if((int) param[5] == 1)
            {
               ret+="<option value='1' selected >On";
               ret+="<option value='0' >Off";
            }
            else
            {
               ret+="<option value='1' >On";
               ret+="<option value='0' selected >Off";
            }
            ret+="</select></td></tr>";
            break;
         }
      }
      ret+="<tr><td></td><td><input type='submit' name='Save' value='save' /></td></tr>";
      ret+="</table></form>";
      return ({ret});
   }
   return ({});
}
