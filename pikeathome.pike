#!/usr/bin/pike
// Copyright (c) 2009-2011, Marc Dirix, The Netherlands.
//                         <marc@dirix.nu>
//
// This script is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

#define NNODAEMON
#define SSCHED_DEBUG
#define DDEBUG
#include <syslog.h>

constant log_progname="Pike At Home";
constant progname="PikeAtHome";
constant pid_file="/var/run/pikeathome/pikeathome.pid";

constant default_installpath="/usr/local/pikeathome";
constant default_config = "/usr/local/pikeathome/pikeathome.conf";

constant version="0.0.1";
object domotica;
array options = ({
               ({ "configfile", Getopt.HAS_ARG, ({ "-c","--config" }) }),
               ({ "installpath", Getopt.HAS_ARG, ({ "-i","--install-path" }) }),
               ({ "xmlrpcserver", Getopt.HAS_ARG, ({ "-i","--xmlrpcserver" }) }),
               ({ "database", Getopt.HAS_ARG, ({ "-d","--database" }) }),
               ({ "debug", Getopt.NO_ARG, ({ "-D","--debug" }) }),
               ({ "nodaemon", Getopt.NO_ARG, ({ "-N","--nodaemon" }) }),
               });

mapping run_config= ([]);

int main( int argc, array(string) argv )
{
   foreach( Getopt.find_all_options(argv,options) , array opt )
      run_config+=([ opt[0]:opt[1] ]);
   if( !has_index( run_config, "configfile" ) )
      run_config->configfile = default_config;
   if( ! Stdio.is_file ( run_config->configfile ) )
   {
      werror("Config file not found: %s\n",run_config->configfile);
      exit(64);
   }
   read_config();
   if( ! has_index( run_config, "installpath" ) )
      run_config->installpath = default_installpath;
   if ( has_index( run_config, "debug" ))
      master()->CompatResolver()->add_predefine("DEBUG","1");
   master()->add_include_path(run_config->installpath+"/include" );
   master()->add_module_path(run_config->installpath+"/server" );
   //Deprecated, modules should not be found in the path
   //master()->add_module_path(run_config->installpath+"/modules" );
   // Init the Domotica master.
   domotica = master()->resolv("Domotica")( run_config );
   if( ! has_index( run_config, "nodaemon" ) )
   {
      detach();
      set_signal();
   }
   return -1;
}

void read_config()
{
   array opts = Stdio.read_file(run_config->configfile)/"\n";
   foreach(opts, string opt)
   {
       string key,val;
       if( sscanf(opt,"%s=%s",key,val) == 2 )
       {
          sscanf(val,"%*[ ]%s%*[ ]",val);
          sscanf(key,"%*[ ]%s%*[ ]",key);
          sscanf(val,"\"%s\"",val);

          if( !has_index(run_config,key) )
             run_config[key]=val;
       }
   }
}

void do_exit()
{
   domotica->log(2,LOG_DEBUG,"Pike At Home Shutting Down\n");
   exit(0);
}

void set_signal()
{
   signal(signum("SIGHUP"),reload);
   signal(signum("SIGINT"),0);
   signal(signum("SIGQUIT"),0);
   signal(signum("SIGPIPE"),0);
   signal(signum("SIGTERM"),do_exit);
}

void reload()
{
   domotica->log(2,LOG_DEBUG,"Reloading config\n");
   //kill the current domotica server
   domotica->close();
   domotica = 0;

   //Replace configuration variables.
   //FIXME find a way to sort out commandline options / database
   read_config();

   // Re-Init the Domotica master.
   domotica = master()->resolv("Domotica")( run_config );
}

void detach()
{
   if(fork()!=0)
      exit(0);
   setsid();
   cd("/");
   ;{ object o=Stdio.FILE(pid_file,"wct");
      o->write("%d\n",getpid());
      o->close();
    }
   //setproctitle(progname);
   string devnull="/dev/null";
   Stdio.File(devnull,"w")->dup2(Stdio.stdin);
   Stdio.File(devnull,"w")->dup2(Stdio.stdout);
   Stdio.File(devnull,"w")->dup2(Stdio.stderr);
}

