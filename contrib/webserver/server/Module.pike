protected object dml;
protected object configuration;
inherit Base_func;

array ModuleParameters = ({});

void create( object dml_ , object Config)
{
   dml = dml_;
   configuration = Config;
}


class DMLParser
{
   inherit Parser.HTML;

   void create( mapping(string:string|function) tags, mapping(string:string|function) containers, mixed ... extra )
   {  
      add_tags(tags);
      add_containers(containers);
      set_extra( @extra);
      case_insensitive_tag(1);
      lazy_entity_end (1);
      match_tag(0);
      xml_tag_syntax(2);
      ignore_unknown(1);
   }
}

string parse_html ( string data, mapping(string:function|string) tags, 
                    mapping(string:function|string) containers,
                    mixed ... extra )
{
   return DMLParser( tags, containers, @extra )->finish(data)->read();
}

void logerror( mixed ... args )
{
   dml->logerror(@args);
}
