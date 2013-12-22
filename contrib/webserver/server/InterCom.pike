#include <module.h>
#include <command.h>

inherit Base_func;

protected object configuration;
protected object dml;
protected object Port;
string name;

void create( object dml_, object configuration_ )
{
   dml = dml_;
   configuration = configuration_;
#ifdef DEBUG
   logdebug("Init InterCom Interface\n");
#endif
   Standards.URI U = Standards.URI(configuration->listenaddress);
   Port = Stdio.Port( U->port?U->port:4090, AcceptCom, U->host?U->host:"127.0.0.1");
   Port->set_id(Port);

}

mapping sockets = ([]);

void AcceptCom( object port_)
{
   Stdio.File tmpio = port_->accept();
   Communicator(tmpio, this);
   destruct(tmpio);
}


class Communicator
{
   inherit Stdio.File : socket;
   object icom;

   string peername;

   void create( object socket_, object icom_ )
   {
      icom= icom_;
      socket::assign(socket_);
      socket::set_nonblocking(read_callback,write_callback,destruct_com);
   }

   string read_buffer="";

   void read_callback( mixed id, string data)
   {
      read_buffer+=data;
      int ptr = search( read_buffer , "\r\n\r\n");
      while( ptr > 0 )
      {
         read( read_buffer[..ptr-1] );
         read_buffer = read_buffer[ptr+4..];
         ptr = search( read_buffer , "\r\n\r\n");
      }
   }

   void read ( string data )
   {
      mapping call = decode_value(data);
      if( !has_index( call, "sender" ) )
      {
         logerror("ICom received data without sender\n");
         destruct_com();
         return;
      }
    
      if( !has_index( call, "receiver" ) )
      {
         logerror("ICom received data without valid receiver\n");
         destruct_com();
         return;
      }

      array sender_split = split_server_module_sensor_value(call->sender);
      if ( !has_index ( icom->sockets, sender_split[0] ) )
      {
         icom->sockets += ([ sender_split[0]: this ]);
         peername=sender_split[0];
      }

      icom->switchboard( call->sender,call->receiver,call->command,call->parameters);
   }


   string write_buffer="";

   void write ( string sender, string receiver, int command, mapping parameters )
   {
      mapping data = ([ "sender":sender,"receiver":receiver,"command":command,
                        "parameters":parameters ]);
      string towrite = encode_value(data)+"\r\n\r\n";
      write_buffer+=towrite;
      socket::set_write_callback(write_callback);
   }

   mapping write_blocking ( string sender, string receiver, int command, mapping parameters )
   {
      socket::set_blocking();
      mapping data = ([ "sender":sender,"receiver":receiver,"command":command,
                        "parameters":parameters ]);
      string towrite = encode_value(data)+"\r\n\r\n";
      int written = socket::write(towrite);
      while ( written < sizeof(towrite) )
      {
         towrite = towrite[written..];
         written = socket::write(towrite);
      }
      for(;;)
      {
         read_buffer+=socket::read();
         int ptr = search( read_buffer , "\r\n\r\n");
         while( ptr == 0 )
         {
            read_buffer+=socket::read();
            ptr = search( read_buffer , "\r\n\r\n");
         }
         string data_buffer = read_buffer[..ptr-1];
         mapping call = decode_value( data_buffer );
         read_buffer = read_buffer[ptr+4..];
         if ( has_index(call,receiver) && call->receiver == sender)
         {
           socket::set_nonblocking(read_callback,write_callback,destruct_com);
           return call;
         }
         else
            read(data_buffer); 
      }
   }

   void write_callback(mixed id)
   {
      int written=0;
      if( sizeof( write_buffer) )
      {
         written = socket::write(write_buffer);
         write_buffer = write_buffer[written..];
      }
   }

   void destruct_com()
   {
      destruct(this);
      icom->deletepeer(peername);
   }

}

void deletepeer(string peername)
{
   m_delete(sockets,peername);
}

void|mapping rpc_command( string receiver, int command, mapping parameters, int|void blocking )
{
   array receiver_split = split_server_module_sensor_value(receiver);

   if ( !has_index(sockets,receiver_split[0]))
   {
      if( has_index( configuration->peers, receiver_split[0] ) )
      {
      
         Standards.URI U = Standards.URI(configuration->peers[receiver_split[0]]);
         Stdio.File newcon = Stdio.File();
         newcon->connect(U->host,U->port);
   
         object Com = Communicator(newcon,this);
         Com->peername=receiver_split[0];
         sockets += ([ receiver_split[0]: Com ]);
      }
      else
      {
         logerror("ICom: Unknown receiver %s\n",receiver);
         return UNDEFINED;
      }
   }
   if ( blocking )
   {
     return sockets[receiver_split[0]]->write_blocking( 
         dml->servername, receiver, command, parameters);
   }  
   call_out ( sockets[receiver_split[0]]->write, 0, 
         dml->servername, receiver, command, parameters);
}


/*
* Helper Function for sensors to call the switchboard
*/
void switchboard ( mixed ... args )
{
   call_out( dml->switchboard,0, @args );
}

