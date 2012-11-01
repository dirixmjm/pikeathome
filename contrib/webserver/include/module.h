#include <syslog.h>
#include <parameters.h>
#include <command.h>

//Module Types
#define MODULE_SENSOR		 (1<<0)
#define MODULE_SCHEDULE	 (1<<1)
#define MODULE_INTERFACE	 (1<<2)
#define MODULE_LOGDATA	 (1<<3)
#define MODULE_LOGEVENT	 (1<<4)

//Log Types
#define LOG_DATA	(1<<0)
#define LOG_EVENT	(1<<1)
