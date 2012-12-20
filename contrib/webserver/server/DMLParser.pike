inherit Parser.HTML;

void create( mapping(string:string|function)|void tags, mapping(string:string|function)|void containers, mixed ... extra )
{  
   if( tags )
      add_tags(tags);
   if( containers )
      add_containers(containers);
   if( extra )
      set_extra( @extra);
   case_insensitive_tag(1);
   lazy_entity_end (1);
   match_tag(0);
   xml_tag_syntax(2);
   ignore_unknown(1);
}

string parse_html ( string data )
{
   return this->finish(data)->read();
}
