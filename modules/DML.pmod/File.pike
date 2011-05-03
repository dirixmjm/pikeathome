inherit Stdio.FakeFile;

int return_code = 200;
mapping return_data = ([]);
constant is_dml_file = 1;
string file_type = "text/html";

void create( string data, mapping request )
{
   ::create( data, "R");
   if( has_index( request, "state" ) )
   {
      return_code = request->state->return_code;
      m_delete(request->state, "return_code");
      return_data = request->state;
   }
}
