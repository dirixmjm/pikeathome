static string database;
static Thread.Mutex inuse = Thread.Mutex();
protected static Sql.Sql db;

void create( string dburi )
{

     database = dburi;
//FIXME remove sqlite:// et al.
//   if(!Stdio.is_file(database))
//      createdb( );
//   else 

}

array query( string _query, mapping _bindings )
{
   Thread.MutexKey lock = inuse->lock();
   if( !db )
      db =  Sql.Sql( database ) ;
   return db->query(  _query, _bindings );
}

string _m_delete(string name)
{
   query("DELETE FROM  configuration WHERE "+ 
             "name=:name ;",([ ":name":name]));
   return name;
}

void createdb( string dburi )
{
   query("CREATE TABLE configuration ( name VARCHAR(16), key VARCHAR(16), value,encoded smallint not null default 0) ", ([]) );
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
   array queryres = query("SELECT value,encoded FROM configuration WHERE " +
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
   //First delete the key, and reinsert the new one.
   query("DELETE FROM  configuration WHERE key=:key AND name=:name;",
             ([ ":name":name,":key":key]));
   if( ! stringp(value) && ! intp(value) )
      query("INSERT INTO configuration (name,key,value,encoded)"
                + " VALUES (:name,:key,:val,1);", 
                ([":name":name,":key":key,":val":encode_value(value)]));
   else
      query("INSERT INTO configuration (name,key,value)"
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
   array queryres = query("SELECT distinct(key) FROM configuration "+
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
