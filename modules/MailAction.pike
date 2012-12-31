#include <module.h>
inherit Module;
#include <sensor.h>
#include <variable.h>

int module_type = MODULE_SENSOR;
string module_name = "WebAction";

constant ModuleParameters = ({

                   ({ "smtpserver", PARAM_STRING,"localhost","SMTP Server",POPT_NONE }),
                   ({ "sender", PARAM_STRING,"","Sender Address",POPT_NONE })
                  });

constant SensorBaseParameters = ({
                   ({ "recipient", PARAM_STRING,"","Recipient Address",0 }),
                   ({ "subject", PARAM_STRING,"","Subject",0 }),
                   ({ "message", PARAM_STRING,"","Message Content",0 }),
                   });


void send_message( string recipient, string subject, string message)
{
         Protocols.SMTP.Client(configuration->smtpserver)->simple_mail( configuration->sender, subject, recipient, message);
}

class sensor
{
   inherit Sensor;
   int sensor_type = SENSOR_OUTPUT;
    
   void sensor_init(  )
   {
      ValueCache->state= ([ "value":0, "direction":DIR_RW, "type":VAR_BOOLEAN ]);
   }

   mapping write( mapping what )
   {

      mapping ret = ([]);
      if( has_index(what,"state") && what["state"] )
      {
         ValueCache->state = 1;
         module->send_message( configuration->recipient, configuration->subject, configuration->message);
         ValueCache->state = 0;
         ret+=([ "state":what->state]);
      }
      return ret;
   }

   void close()
   {
   }

}


