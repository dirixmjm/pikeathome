#include <variable.h>
#include <command.h>

/* 
This class functions as a stand-in for the former mapping variable storage in sensors. Although most times it should act as a mapping it is meant as an easy way to expand variable type information and at some point offer control over them.
*/


mapping Storage = ([]);
object Sensor;

void create ( void|mapping InitVariable )
{
   if( InitVariable && mappingp(InitVariable) )
   {
      foreach ( InitVariable; string Name; mixed Data ) 
      {
         Storage+= ([ Name : Variable(Name,Data) ]);
      }
   }
}



mixed `->(string Key)
{
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
      Storage[Key] = Variable(Key,Value);
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
   int type = VAR_INT;
   mixed value;
   int direction = DIR_RO;
   string Name = "";

   protected void create( string Key, mixed Value )
   {
      Name = Key;
      if ( mappingp( Value ) )
      {
         type= (int) Value->type;
         value= Value->value;
         direction= Value->direction || DIR_RO;
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
   
}
