#include <module.h>

int sensor_type = 0; 

protected object configuration;
array defvar = ({});


string sensor_name = "";
object domotica;
protected mapping sensor_var = ([
                               "module":"",
                               "name":"",
                               "sensor_type":sensor_type
                               ]);

void create( string name, object Dom )
{
   //FIXME Dynamically set module name? Should this be a create argument?
   domotica = Dom;
   configuration = domotica->configuration(name);
   sensor_name = name;
   sensor_var->name = name;
   sensor_var->sensor_type = sensor_type;
   sensor_init();
   if ( has_index(configuration, "log") )
      call_out(run_log,(int) configuration->log);
}

void sensor_init()
{
}

/* Each sensor with type=SENSOR_INPUT should implement a write function.
 * The write function takes a variable-name, and
 * the value which is to written to the variable.
 */
mixed write( string variable, mixed value )
{
}

/* 
 * Info returns the last seen sensor input and output values 
 * in a mapping.
 * If "new" is given, the sensor must be queried for new values.
 */
mapping info( int|void new )
{
   if ( new )
      getnew();
   return  sensor_var;
}

/* Each sensor should implement this function. 
 * getnew() queries the sensor for new values, and 
 * updates sensor_var.
 */

void getnew()
{
}


void run_log()
{
   log();
   if ( has_index(configuration, "log") )
      call_out(run_log,(int) configuration->log);
}

/* Each sensor should implement this function.
 * The log function is called periodically if the sensor
 * should log its values.
 */
void log()
{

}

array getvar()
{
   array ret = ({});
   foreach( defvar, array vars )
   {
      ret += ({ ([
               "name":vars[0],
               "type":vars[1],
               "default":vars[2],
               "description":vars[3],
               "value":configuration[vars[0]]
              ]) });
   }
   return ret;
}

void close()
{
   destruct(this);
}
