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

string _m_delete(string name)
{
   Thread.MutexKey lock = inuse->lock();
   Sql.Sql db =  Sql.Sql( database ) ;
   db->query("DELETE FROM  configuration WHERE "+ 
             "name=:name ;",([ ":name":name]));
   return name;
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

string|array get_value(string key)
{
   Thread.MutexKey lock = inuse->lock();
   Sql.Sql db =  Sql.Sql( database ) ;
   array queryres = db->query("SELECT value,encoded FROM configuration WHERE " +
                              "name=:name AND key=:key;",
                             ([ ":name":name,":key":key ]));
   if ( !sizeof ( queryres ) )
      return UNDEFINED;
   array result = queryres->value;
   //Decode value if non-string-int.
   if ( (int) queryres[0]->encoded == 1 )
   {
      return decode_value( result[0] );
   }
   //If there is only one value, the value is return, else an array of values.
   if ( sizeof( result ) == 1 )
      return result[0];
   else
      return result;
}

void write_value(string key, mixed value )
{
   Thread.MutexKey lock = inuse->lock();
   Sql.Sql db =  Sql.Sql( database ) ;
   //First delete the key, and reinsert the new one.
   db->query("DELETE FROM  configuration WHERE key=:key AND name=:name;",
             ([ ":name":name,":key":key]));
   if( ! stringp(value) && ! intp(value) )
      db->query("INSERT INTO configuration (name,key,value,encoded)"
                + " VALUES (:name,:key,:val,1);", 
                ([":name":name,":key":key,":val":encode_value(value)]));
   else
      db->query("INSERT INTO configuration (name,key,value)"
                + " VALUES (:name,:key,:value);",
                ([ ":name":name,":key":key,":value":value ]));
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
                              " WHERE name=:name", ([ ":name":name ]) );
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

void `+(mapping values)
{
   foreach(values; string index; mixed value)
   {
       write_value( index, get_value(index) + value );
   }
}

void `-(mapping values )
{
   foreach(values; string index; mixed value)
   {
       write_value( index, get_value(index) - value );
   }
}
}
