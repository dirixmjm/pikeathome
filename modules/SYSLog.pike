#include <module.h>
#include <syslog.h>

inherit Module_LOG;

int module_type = MODULE_LOGEVENT;

string module_name = "SYSLog";
void init()
{
   System.openlog("pikeathome",LOG_PID,LOG_DAEMON);
}
void log_event( int level, string sender, string format, mixed ... args )
{
   System.syslog(level,sprintf(sender+": " + format,@args));
}

void close()
{
   System.closelog();
   configuration = 0;
   domotica = 0;
}
