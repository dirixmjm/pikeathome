protected static string database;
protected static Sql.Sql db;
protected static Thread.Mutex inuse = Thread.Mutex();

protected class _Configuration
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

_Configuration  NewConfiguration(string cname)
{
   //Module name and up
   if( has_prefix(cname,name) )
      return _Configuration(cname);
   else
     return UNDEFINED;
}


string|array|object `->(string key)
{
   if( key == "Configuration" )
      return NewConfiguration;
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

string _m_delete(string cname)
{
   //Module name and up
   if ( has_prefix(cname,name) )
   {
      query("DELETE FROM  configuration WHERE "+ 
                "name=:name ;",([ ":name":cname]));
      return cname;
   }
   werror("Delete of name %s not allowed\n",cname);
}

}

_Configuration `()( string dburi, int currentdbversion, string name )
{
     database = dburi;
     db =  Sql.Sql( database );
     if( !sizeof(db->list_tables("configuration")) )
     {
        write("Creating Empty Configuration Table\n");
        createtables( currentdbversion,name );
     }
     int dbversion = 0;
     array queryres = query("SELECT value,encoded FROM configuration WHERE " +
                              "name=:name AND key=:key;",
                             ([ ":name":name,":key":"version" ]));
     if ( sizeof ( queryres ) )
       dbversion = (int) queryres[0]->value;
     if( dbversion < currentdbversion)
     {
        write("Starting Database Update From %d To %d\n",dbversion,currentdbversion);
        //DoUpdate(dbversion);
     }
     return _Configuration(name);
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

void createtables( int currentdbversion,string name )
{
   query("CREATE TABLE configuration ( name VARCHAR(16), key VARCHAR(16), value,encoded smallint not null default 0) ",([]) );
   query("INSERT INTO configuration (name,key,value,encoded)"
                + " VALUES (:name,:key,:val,1);", 
                ([":name":name,":key":"version",":val":currentdbversion]));
}

void DoUpdate(int version, string name)
{
   object serverconf = _Configuration(name);
   switch(version)
   {
      //Also 0 if no schema is found.
      case 0:
      case 1:
      foreach( serverconf->module || ({}), string modulename )
      {
         object modconf = serverconf->Configuration(modulename);
         if( modconf->filename == "Comperator.pike" )
         {
            foreach(modconf->sensor || ({}), string sensorname )
            {
               object sensconf=modconf->Configuration(sensorname);
               sensconf->output = ({sensconf->output });
            }
         }
      }
      serverconf->version=2;
   }
}

