static string database;
static Thread.Mutex inuse = Thread.Mutex();


void create( string dburi )
{

     database = dburi;
//FIXME remove sqlite:// et al.
//   if(!Stdio.is_file(database))
//      createdb( );
//   else 

}


void createdb( string dburi )
{
   Sql.Sql db = Sql.Sql( dburi );
   db->query("CREATE TABLE configuration ( name VARCHAR(16), key VARCHAR(16), value VARCHAR(256) ) " );
}


class Configuration
{

string name; 
mapping configuration;

void create(string cname)
{
    name=cname;
}

array decode(array to_decode )
{
   array res = ({});
   foreach(to_decode, string value )
   {
      res+=({ decode_value(value) });
   }
   return res;
}

string|array get_value(string key)
{
   Thread.MutexKey lock = inuse->lock();
   Sql.Sql db =  Sql.Sql( database ) ;
   array queryres = db->query("SELECT value,encoded FROM configuration WHERE name='"
                              + name + "' AND key='"+ key +"';");
   if ( !sizeof ( queryres ) )
      return UNDEFINED;
   array result = queryres->value;
   //If the database values are encoded, the result is always an array.
   if ( (int) queryres[0]->encoded == 1 )
   {
      return decode( result );
   }
   //If there is only one value, the value is return, else an array of values.
   if ( sizeof( result ) == 1 )
      return result[0];
   else
      return result;
}
void write_value(string key, string|array value )
{
   Thread.MutexKey lock = inuse->lock();
   Sql.Sql db =  Sql.Sql( database ) ;
   //It is impossible to decide which value to update 
   //if value = string, but the db an array, or vice versa.
   //so delete and update all
   db->query("DELETE FROM  configuration WHERE key='"+key+"'"+
             "AND name='"+name+"';");
   array values = (arrayp(value))?value:({value});
   foreach( values, string|int|mapping|array val )
   {
     if( ! stringp(val) && ! intp(val) )
        db->query("INSERT INTO configuration (name,key,value,encoded)"
                + " VALUES ('"+ name + "','"+ key +"',:val,1);", 
                ([":val":encode_value(val)]));
     else
        db->query("INSERT INTO configuration (name,key,value)"
                + " VALUES ('"+ name + "','"+ key +"','"+ val + "');");

   }
}

string|array `->(string key)
{
   return get_value(key);
}

string|array `[](string key)
{
   return get_value(key);
}


array(string) _indices()
{
   Thread.MutexKey lock = inuse->lock();
   Sql.Sql db =  Sql.Sql( database ) ;
   array queryres = db->query("SELECT distinct(key) FROM configuration "+
                              " WHERE name='" + name + "';");
   return queryres->key;

}


void `[]=(string key ,string|array value)
{
   write_value(key,value);
}

void `->=(string key ,string|array|int value)
{
   write_value(key,value);
}

}
