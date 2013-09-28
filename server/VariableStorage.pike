#include <variable.h>
#include <parameters.h>
#include <command.h>

/* 
This class functions as a stand-in for the former mapping variable storage in sensors. Although most times it should act as a mapping it is meant as an easy way to expand variable type information and at some point offer control over them.
*/


mapping Storage = ([]);
object Sensor;
protected object configuration;

void create ( object _configuration, void|mapping InitVariable )
{
   configuration = _configuration;
   if( InitVariable && mappingp(InitVariable) )
   {
      foreach ( InitVariable; string Name; mixed Data ) 
      {
         Storage+= ([ Name : Variable(Name,Data,configuration->Configuration(Name)) ]);
      }
   }
}

array GetParameters(string Key)
{
   if( has_index ( Storage, Key) )
      return Storage[Key]->GetParameters(); 
}

array SetParameters(string Key, array Parameters)
{
   if( has_index ( Storage, Key) )
      return Storage[Key]->SetParameters(Parameters); 
}

mixed `->(string Key)
{
   if ( Key == "GetParameters" )
      return GetParameters;
   if ( Key == "SetParameters" )
      return SetParameters;
   if( has_index ( Storage, Key) )
      return Storage[Key]->value; 
   return UNDEFINED;
}

mixed `[](string Key)
{
   if( has_index ( Storage, Key) )
      return Storage[Key]->value; 
   return UNDEFINED;
}

mixed `->=(string Key, mixed Value)
{
   if( has_index ( Storage, Key) )
   {
      //If a mapping is provided it is expected to be a full variable description. A Variable cannot be a mapping itself.
      if ( mappingp(Value) )
      {
         Storage[Key] = Value;
      }
      else
         Storage[Key]->value = Value;
   }
   else
   {
      Storage[Key] = Variable(Key,Value,configuration->Configuration(Key));
   }
}

mixed `[]=(string Key, mixed Value)
{
   if( has_index ( Storage, Key) )
   {
      //If a mapping is provided it is expected to be a full variable description. A Variable cannot be a mapping itself.
      if ( mappingp(Value) )
      {
         Storage[Key] = Value;
      }
      else
         Storage[Key]->value = Value;
   }
   else
   {
      Storage[Key] = Variable(Key,Value,configuration->Configuration(Key));
   }
}

array _indices(object|void context, int|void access)
{
   return indices(Storage);
}

mixed cast( string type )
{

   switch( type )
   {
      case "mapping":
         mapping cst = ([]);
         foreach( Storage; string Key; Variable Var )
         {
            cst+= ([ Key: (mapping) Storage[Key] ]);
         }
         return cst;
         break;
       default:
          error("Can't cast VariableStorage to %s\n");
   }
}

class Variable
{

array VariableParameters = ({
                   ({ "direction",PARAM_SELECT,(["ReadOnly":DIR_RO,"WriteOnly":DIR_WO,"Read/Write":DIR_RW]),"Variable Direction",0}),
                   ({ "log",PARAM_BOOLEAN,1,"Automatic Log Enable",0}),
                   ({ "logtime",PARAM_INT,60,"Automatic Log Time",0}),
                                 });
   int type = VAR_INT;
   mixed value;
   int direction = DIR_RO;
   int log = 0;
   int logtime = 60;
   string Name = "";
   object configuration;

   protected void create( string Key, mixed Value, object _configuration )
   {
      Name = Key;
      configuration = _configuration;
      //This Sets the Defaults, which can have a configuration-override
      if ( mappingp( Value ) )
      {
         foreach( VariableParameters; int index; array param )
         {
            if( has_index(Value,param[0]) )
               VariableParameters[index][2] = Value[param[0]];
         }
         type= (int) Value->type;
         value= Value->value;
         if ( has_index( Value, "direction") )
         {
            direction= Value->direction;
            //If the direction is set to RO or WO the direction is fixed in software.
            if ( direction == DIR_RO )
               VariableParameters[0]= ({ "direction",PARAM_SELECT,(["ReadOnly":DIR_RO]),"Variable Direction",0});
            if ( direction == DIR_WO )
               VariableParameters[0]= ({ "direction",PARAM_SELECT,(["WriteOnly":DIR_WO]),"Variable Direction",0});
         }
         else
            direction= DIR_RO;

         if( has_index(Value,"log") )
            log = Value->log;
         if( has_index(Value,"logtime") )
            logtime = Value->logtime;
      }
      else
      {
         value=Value;
         switch(basetype(Value))
         {
         case "int":
            type=VAR_INT;  
            break;
         case "float":
            type=VAR_FLOAT;  
            break;
         case "string":
            type=VAR_STRING;  
            break;
         }
      }
      //Check if the configuration has information stored about this variable
      //FIXME Check direction mask
      if ( has_index(configuration,"direction") )
         direction = configuration->direction;
      if ( has_index(configuration,"log") )
         log = configuration->log;
      if ( has_index(configuration,"logtime") )
         logtime = configuration->logtime;
   }

   void `->=( string Key, mixed Value )
   {
      switch(Key)
      {
         case "value":
            StoreValue(Value);
            break;
         case "direction":
            direction = (int) Value;
            break;
         case "type":
            type=(int) Value;
            break;
      }
   }

   void `=(mixed Value)
   {
      if ( mappingp( Value ) )
      {
         if( has_index(Value, "type" ) )
            type= (int) Value->type;
         if( has_index(Value, "type" ) )
            StoreValue(Value);
         if( has_index(Value, "direction" ) )
            direction= (int) Value->direction;
      }
      
   }

   protected void StoreValue( mixed Value )
   {
        switch( type )
        {
           case VAR_INT:
              if( intp( Value) )
                 value = Value;
              else
                 error("Error trying to fit a non-int into variable %s\n",Name);
              break;
           case VAR_FLOAT:
              if( floatp( Value) )
                 value = Value;
              else
                 error("Error trying to fit a non-float into variable %s\n",Name);
              break;
           case VAR_BOOLEAN:
              if( intp( Value) && Value <= 1 && Value >= 0 )
                 value = Value;
              else
                 error("Error trying to fit a non-boolean into variable %s\n",Name);
              break;
           case VAR_STRING:
              if( stringp( Value ))
                 value = Value;
              else
                 error("Error trying to fit a non-string into variable %s\n",Name);
              break;
        }
   }

   mixed cast( string cast_type )
   {

      switch( cast_type )
      {
         case "mapping":
            return ([ "value":value,
                      "type":type,
                      "direction":direction
                    ]);
            break;
         case "int":
            if ( type == VAR_INT || type == VAR_FLOAT || type == VAR_BOOLEAN )
               return (int) value;
         case "float":
            if ( type == VAR_INT || type == VAR_FLOAT )
               return (float) value;
      }
      error("Can't cast Variable to %s\n");
   }

   array GetParameters()
   {
      array ret = ({});
      foreach(VariableParameters, array var)
      {
         switch(var[0])
         {
            case "direction":
               ret+= ({ var + ({ direction })});
               break;
            case "log":
               ret+= ({ var + ({ log })});
               break;
            case "logtime":
               ret+= ({ var + ({ logtime })});
               break;
         }
      }
      return ret;
   }

   void SetParameters( mapping params )
   {
      int mod_options = 0;
      foreach(VariableParameters, array option)
      {
         //Find the parameter, and always set it
         if( has_index( params, option[0] ) )
         {
            configuration[option[0]]=params[option[0]];
            switch(option[0])
            {
               case "direction":
                  direction= (int) params[option[0]];;
                  break;
               case "log":
                  log= (int) params[option[0]];;
                  break;
               case "logtime":
                  logtime= (int) params[option[0]];;
                  break;
            }
         }
      }
   }
}
