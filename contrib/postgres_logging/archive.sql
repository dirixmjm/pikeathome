-- Copyright (c) 2012, Marc Dirix (marc@dirix.nu)

CREATE TYPE logoutput AS ( stamp TIMESTAMP WITH TIME ZONE, value INT );

CREATE OR REPLACE FUNCTION retrieve_archive ( i_server VARCHAR, 
i_module VARCHAR, i_sensor VARCHAR, i_variable VARCHAR, i_aggregate VARCHAR,
i_start TIMESTAMP WITH TIME ZONE,
i_end TIMESTAMP WITH TIME ZONE )
RETURNS setof  logoutput AS $retrieve_archive$
DECLARE
  v_source source%ROWTYPE;
  v_primarydata primarydata%ROWTYPE;
  v_logout logoutput;
  v_archive_id INT;
  v_aggregate_id INT;
BEGIN
  SELECT * INTO v_source FROM source WHERE server=i_server AND 
   module=i_module AND sensor = i_sensor AND variable = i_variable;

  SELECT id INTO v_aggregate_id FROM aggregate WHERE name ilike i_aggregate;

  SELECT b.id INTO v_archive_id FROM rrs AS a JOIN archive AS b 
    ON a.id=b.rrs_id AND b.aggregate_id=v_aggregate_id 
    AND b.source_id = v_source.id AND a.keep >= (current_timestamp - i_start);
    -- Update the archives
  PERFORM archive_update( v_archive_id );
  FOR v_logout IN SELECT stamp,value FROM primarydata 
    WHERE archive_id=v_archive_id AND stamp >= i_start AND
    stamp < i_end ORDER BY stamp ASC LOOP
    RETURN NEXT v_logout;
  END LOOP;
  RETURN; 
END;
  $retrieve_archive$ LANGUAGE PLPGSQL;


CREATE OR REPLACE FUNCTION archive_update( i_archive_id INT )
RETURNS VOID AS $archive_update$
DECLARE
  v_archive archive%ROWTYPE;
  v_rrs rrs%ROWTYPE;
  v_source source%ROWTYPE;
  v_aggregate aggregate%ROWTYPE;
  v_max_primarystamp TIMESTAMP WITH TIME ZONE;
  v_min_primarystamp TIMESTAMP WITH TIME ZONE;
  v_max_archivestamp TIMESTAMP WITH TIME ZONE;
  v_parent_archive_id INT;
  v_loopquery TEXT;
BEGIN

  --Get Information about the archive
  SELECT * INTO v_archive FROM archive WHERE id=i_archive_id;
  IF v_archive IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_rrs FROM rrs WHERE id=v_archive.rrs_id;
  SELECT * INTO v_aggregate FROM aggregate WHERE id=v_archive.aggregate_id;
  SELECT * INTO v_source FROM source WHERE id=v_archive.source_id;

  IF v_rrs.parent IS NOT NULL THEN
    SELECT id INTO v_parent_archive_id FROM archive WHERE rrs_id=v_rrs.parent AND source_id=v_archive.source_id AND aggregate_id = v_archive.aggregate_id;
    IF v_parent_archive_id IS NULL THEN
      RAISE EXCEPTION 'parent of % has is not a valid archive',v_rrs.id;
    END IF;
    PERFORM archive_update ( v_parent_archive_id );
  END IF;


  --Check for the last entry in the primary data
  IF v_rrs.parent IS NULL THEN
    SELECT max(stamp) INTO v_max_primarystamp FROM primarydata WHERE source_id=v_archive.source_id;
  ELSE
    SELECT max(stamp) INTO v_max_primarystamp FROM primarydata WHERE archive_id=v_parent_archive_id;
  END IF;
  IF v_max_primarystamp IS NULL THEN
    RETURN;
  END IF;

  --Check for the last entry in the archive data
  SELECT max(stamp) INTO v_max_archivestamp FROM primarydata WHERE archive_id=i_archive_id;
  IF v_max_archivestamp IS NULL THEN
    SELECT min(stamp) INTO v_min_primarystamp FROM primarydata WHERE source_id=v_archive.source_id;
    v_max_archivestamp = init_bucket_time(v_min_primarystamp,v_rrs.precision)-v_source.precision;
  END IF;
 
  <<bucketloop>>
  LOOP
    --Get next bucket
    v_max_archivestamp = v_max_archivestamp + v_rrs.precision;
    --No more data is available
    EXIT bucketloop WHEN v_max_archivestamp > v_max_primarystamp;
    v_loopquery = ' INSERT INTO primarydata (archive_id,stamp,value) ' || 
                  ' SELECT ' || 
                  quote_literal(i_archive_id) || ' AS archive_id, ' || 
                  quote_literal( v_max_archivestamp) || ' AS stamp, ' ||
                  quote_ident(v_aggregate.aggregatefun) || '(value) AS value' ||
                  ' FROM primarydata WHERE ' ||
                  ' stamp >= ' || quote_literal(v_max_archivestamp) || ' AND '||
                  ' stamp < ' || quote_literal(v_max_archivestamp + v_rrs.precision);
   IF v_rrs.parent IS NULL THEN
     v_loopquery = v_loopquery || ' AND ' ||
                  ' source_id=' || quote_literal(v_archive.source_id);
   ELSE
     v_loopquery = v_loopquery || ' AND ' ||
                  ' archive_id=' || quote_literal(v_parent_archive_id);
   END IF;

   EXECUTE v_loopquery;
  END LOOP;
END;
 $archive_update$ LANGUAGE PLPGSQL;
