#include <module.h>
#include <command.h>

inherit Base_func;

protected object configuration;
function switchboard;
protected object Port;
string name;

void create( string servername, function _switchboard, object configuration_ )
{
   switchboard=_switchboard;
   name = servername + ".ICom";
   configuration = configuration_;
   logdebug("Init InterCom Interface\n");
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
      icom->deletepeer(peername);
      destruct(this);
   }
}

void deletepeer(string peername)
{
   m_delete(sockets,peername);
}

void rpc_command( string sender, string receiver, int command, mapping parameters )
{
   array receiver_split = split_server_module_sensor_value(receiver);
   if( has_index( sockets, receiver_split[0] ))
   {
      if( sockets[receiver_split[0]] && sockets[receiver_split[0]]->is_open() )
         sockets[receiver_split[0]]->write( sender, receiver, command,
                                                                   parameters);
      else
      {
         logerror("ICom: Peer connection lost%s\n",receiver_split[0]);
         deletepeer(receiver_split[0]);
      }
   }
   else
      logerror("ICom: Unknown receiver %s\n",receiver);
}

/*
* Helper / Short functions for Modules
*/

void logdebug(mixed ... args)
{
   call_out(switchboard, 0, name, "broadcast", COM_LOGEVENT, ([ "level":LOG_DEBUG, "error":sprintf(@args) ]) );
}

void logerror(mixed ... args)
{
   call_out(switchboard, 0, name, "broadcast", COM_LOGEVENT, ([ "level":LOG_ERR, "error":sprintf(@args) ]) );

}



