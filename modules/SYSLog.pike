#include <module.h>
#include <syslog.h>

inherit Module_LOG;

int module_type = MODULE_LOG;

string module_name = "SYSLog";
void init()
{
   System.openlog("pikeathome",LOG_PID,LOG_DAEMON);
}
void log_event( int level, string format, mixed ... args )
{
   System.syslog(level,sprintf(format,@args));
}

void close()
{
   System.closelog();
   configuration = 0;
   domotica = 0;
}
