#include <syslog.h>
#include <parameters.h>
#include <command.h>

//Module Types
#define MODULE_SENSOR		 (1<<0)
#define MODULE_SCHEDULE	 (1<<1)
#define MODULE_INTERFACE	 (1<<2)
#define MODULE_LOG	 (1<<3)

//Sensor Types
#define SENSOR_INPUT		(1<<0)
#define SENSOR_OUTPUT		 (1<<1)
#define SENSOR_SCHEDULE	 	(1<<2)
/*Sensors with SENSOR_FUNCTION are active, 
 * they can read and write to other sensors
 */
#define SENSOR_FUNCTION	 	(1<<3)


//Log Types
#define LOG_DATA	(1<<0)
#define LOG_EVENT	(1<<1)
