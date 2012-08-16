/* Split a sensor or module pointer into an array.
 * The array contains ({ module, sensor, attribute });
*/
array split_server_module_sensor_value(string what)
{
   array ret = ({});
   string parse = what;
   int i=search(what,".");
   while(i>0)
   {
      if( what[++i] != '.' )
      {
         ret += ({ what[..i-2] });
         what = what[i..];
         i=0;
      }
      i++;
      i=search(what,".",i);
   }
   if(sizeof(what))
      ret+= ({ what });
   return ret;
}
/* Split a sensor or module pointer into an array.
 * The array contains ({ server,server.module, server.module.sensor, etc });
*/
array cumulative_split_server_module_sensor_value(string what)
{
   array ret = ({});
   string store = "";
   int i=search(what,".");
   if( (i < 0) && sizeof(what) )
      return ({ what });

   while(i>0)
   {
      if( what[++i] != '.' )
      {
         ret += ({ store + what[..i-2] });
         store = store + what[..i-2]+"." ;
         what = what[i..];
         i=0;
      }
      i++;
      i=search(what,".",i);
   }
   return ret;
}

