#include <syslog.h>
#include <parameters.h>
#include <command.h>

//Sensor Types
#define SENSOR_INPUT            (1<<0)
#define SENSOR_OUTPUT            (1<<1)
#define SENSOR_SCHEDULE         (1<<2)
/*Sensors with SENSOR_FUNCTION are active,
 * they can read and write to other sensors
 */
#define SENSOR_FUNCTION         (1<<3)

