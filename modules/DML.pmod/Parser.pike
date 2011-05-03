inherit Parser.HTML;

void create( )
{
   lazy_entity_end (1);
   match_tag(0);
   xml_tag_syntax(2);
}
