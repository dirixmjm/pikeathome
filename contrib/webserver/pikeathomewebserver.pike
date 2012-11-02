#!/usr/bin/pike
// Copyright (c) 2009-2010, Marc Dirix, The Netherlands.
//                         <marc@electronics-design.nl>
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

constant log_progname="Pike At Home Webserver";
constant progname="PikeAtHomeWebServer";
constant pid_file="/var/run/pikeathomewebserver/pikeathomewebserver.pid";

constant default_installpath="/usr/local/pikeathome";
constant default_webpath="/usr/local/pikeathome/www/";
constant default_webport=8080;
constant default_config = "/usr/local/pikeathome/pikeathome.conf";
constant default_name = "WebServer";

constant version="0.0.1";

array options = ({
               ({ "configfile", Getopt.HAS_ARG, ({ "-c","--config" }) }),
               ({ "installpath", Getopt.HAS_ARG, ({ "-i","--install-path" }) }),
               ({ "webpath", Getopt.HAS_ARG, ({ "-w","--webpath" }) }),
               ({ "webport", Getopt.HAS_ARG, ({ "-p","--webport" }) }),
               ({ "database", Getopt.HAS_ARG, ({ "-d","--database" }) }),
               ({ "debug", Getopt.NO_ARG, ({ "-D","--debug" }) }),
               ({ "nodaemon", Getopt.NO_ARG, ({ "-N","--nodaemon" }) }),
               });

mapping run_config= ([]);
object HTTPServer;
object dmlparser;

int main( int argc, array(string) argv )
{

   //Get all options from the commandline.

   foreach( Getopt.find_all_options(argv,options) , array opt )
      run_config+=([ opt[0]:opt[1] ]);
   if( !has_index( run_config, "configfile" ) )
      run_config->configfile = default_config;
   if( ! Stdio.is_file ( run_config->configfile ) )
   {
      werror("Config file not found: %s\n",run_config->configfile);
      exit(64);
   }

   // Read configuration file, but don't overwrite.
   read_config();
   //FIXME are these if's here the best sollution?
   if( ! has_index( run_config, "name" ) )
      run_config->name = default_name;
   if( ! has_index( run_config, "installpath" ) )
      run_config->installpath = default_installpath;
   if( ! has_index( run_config, "webpath" ) )
      run_config->webpath = default_webpath;
   if( ! has_index( run_config, "webport" ) )
      run_config->webport = default_webport;
   if ( has_index( run_config, "debug" ))
      master()->CompatResolver()->add_predefine("DEBUG","1");
   master()->add_include_path(run_config->installpath+"/include" );
   master()->add_module_path(run_config->installpath+"/server" );
   HTTPServer = master()->resolv("WebServer")(run_config);

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
   System.syslog(LOG_DEBUG,"Pike At Home Webserver Shutting Down\n");
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
   //Replace configuration variables.
   //FIXME find a way to sort out commandline options / database
   read_config();

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

