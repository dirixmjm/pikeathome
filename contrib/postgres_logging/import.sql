-- Copyright (c) 2012, Marc Dirix (marc@dirix.nu)

CREATE OR REPLACE FUNCTION log_init()
RETURNS VOID AS $$
DECLARE
 v_loop RECORD;
 v_ress RECORD;
BEGIN
 FOR v_loop IN SELECT a.source_id,a.rrs_id,a.aggregate_id,b.parent,
   c.module AS module ,c.sensor AS sensor ,d.name AS name FROM
   source_rrs_aggregate AS a JOIN rrs AS b ON a.rrs_id=b.id JOIN source
   AS c on a.source_id = c.id JOIN aggregate AS d ON a.aggregate_id = d.id
   WHERE b.parent IS NULL  ORDER BY a.source_id,a.aggregate_id,coalesce(b.parent,-1),a.rrs_id
   LOOP
   RAISE NOTICE 'RUNNING % % % %',v_loop.module,v_loop.sensor,v_loop.name,v_loop.rrs_id;
   IF v_loop.parent IS NULL THEN
     EXECUTE log_init(v_loop.source_id,v_loop.rrs_id,v_loop.aggregate_id );
   ELSE
     EXECUTE rrs_init(v_loop.source_id,v_loop.rrs_id,v_loop.aggregate_id );
   END IF;
   END LOOP;
END;
  $$ LANGUAGE PLPGSQL;


CREATE OR REPLACE FUNCTION log_init(i_source_id INTEGER, i_rrs_id INTEGER, i_aggregate_id INTEGER)
RETURNS VOID AS $log_update$ 
DECLARE
  v_source RECORD;
  v_rrs RECORD;
  v_aggregate RECORD;
  v_bucket_start_time TIMESTAMP WITH TIME ZONE;
  v_end_time TIMESTAMP WITH TIME ZONE;
  v_max_end_time TIMESTAMP WITH TIME ZONE;
  v_min_values_time TIMESTAMP WITH TIME ZONE;
 
  v_sql text;
BEGIN

  --Get Source Parameters
  SELECT * INTO v_source  FROM source WHERE id=i_source_id;
  SELECT * INTO v_rrs FROM rrs WHERE id=i_rrs_id;
  SELECT * INTO v_aggregate FROM aggregate WHERE id=i_aggregate_id;

 SELECT min(stamp) INTO v_min_values_time FROM oldlog WHERE
 server=v_source.server AND module=v_source.module AND 
 sensor=v_source.sensor AND variable=v_source.variable;

 --There are no buckets yet, so start with the oldest possible bucket
 v_bucket_start_time := init_bucket_time(v_min_values_time,v_rrs.precision);
 RAISE NOTICE 'Start LOG at %',v_bucket_start_time;

 SELECT max(stamp) INTO v_end_time FROM oldlog WHERE
 server=v_source.server AND module=v_source.module AND 
 sensor=v_source.sensor AND variable=v_source.variable;

 RAISE NOTICE 'END LOG at %',v_end_time;

      <<bucketloop>>
    LOOP
      EXIT bucketloop WHEN v_bucket_start_time+v_rrs.precision > v_end_time;
         --How about RRD heartbeat?
        v_sql := 'INSERT INTO log (source_id,rrs_id,aggregate_id, ' ||
                 'stamp,value ) ' ||
                 'SELECT ' || quote_literal(i_source_id) || ' AS source_id,' || 
                 quote_literal(i_rrs_id) || ' AS rrs_id,' || 
                 quote_literal(i_aggregate_id) || ' AS aggregate_id,' ||
                 quote_literal(v_bucket_start_time) || ' AS stamp,' || 
                 quote_ident(v_aggregate.aggregatefun) || '( value) AS value' ||
                 ' FROM oldlog WHERE ' ||
                 'server = ' || quote_literal(v_source.server) || 'AND '||
                 ' module=' || quote_literal(v_source.module) || 'AND ' ||
                 ' sensor=' || quote_literal(v_source.sensor) || 'AND ' ||
                 ' variable=' || quote_literal(v_source.variable) ||' AND ' ||
                 'stamp >=' || quote_literal(v_bucket_start_time) || ' AND ' ||
                 'stamp <' || quote_literal( v_bucket_start_time +v_rrs.precision);
      RAISE DEBUG '%', v_sql;
      EXECUTE v_sql;
      v_bucket_start_time := v_bucket_start_time+v_rrs.precision;
    END LOOP;     
END;
  $log_update$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION rrs_init(i_source_id INTEGER,i_rrs_id INTEGER, i_aggregate_id INTEGER)
RETURNS VOID AS $log_update$ 
DECLARE
  v_source RECORD;
  v_rrs RECORD;
  v_aggregate RECORD;
  v_bucket_start_time TIMESTAMP WITH TIME ZONE;
  v_end_time TIMESTAMP WITH TIME ZONE;
  v_max_end_time TIMESTAMP WITH TIME ZONE;
  v_sql text;
BEGIN
  SELECT * INTO v_source  FROM source WHERE id=i_source_id;
  SELECT * INTO v_rrs FROM rrs WHERE id=i_rrs_id;
  SELECT * INTO v_aggregate FROM aggregate WHERE id=i_aggregate_id;

  IF v_rrs.parent IS NULL THEN
     RAISE EXCEPTION 'Can\'t start rrs_init for rrs with parent is null';
  END IF;    
  --There are no buckets yet, so start with the oldest possible bucket

  SELECT min(stamp) INTO v_bucket_start_time FROM log WHERE rrs_id=v_rrs.parent
   AND aggregate_id=i_aggregate_id AND source_id=i_source_id;

  RAISE NOTICE 'RRS Start at %', v_bucket_start_time;

    --If this is a parent, we have to pull from rawlog
  SELECT max(stamp) INTO v_end_time FROM log WHERE source_id=i_source_id
   AND rrs_id=v_rrs.parent AND aggregate_id=i_aggregate_id;
  RAISE NOTICE 'RRS End at %', v_bucket_start_time;

      <<bucketloop>>
    LOOP
      EXIT bucketloop WHEN v_bucket_start_time > v_end_time;
        v_sql := 'INSERT INTO log (source_id,rrs_id,aggregate_id, ' ||
                 'stamp,value )' ||
                 'SELECT ' || quote_literal(i_source_id) || ' AS source_id,' ||
                 quote_literal(i_rrs_id) || ' AS rrs_id,' ||
                 quote_literal(i_aggregate_id) || ' AS aggregate_id, ' || 
                 quote_literal(v_bucket_start_time) || ' AS stamp,' || 
                 quote_ident(v_aggregate.aggregatefun) || '( value) AS value' ||
                 ' FROM log WHERE ' ||
                 'source_id =' || quote_literal(i_source_id) || ' AND '||
                 'rrs_id =' || quote_literal(v_rrs.parent) || ' AND ' ||
                 'stamp >=' || quote_literal(v_bucket_start_time) || ' AND ' ||
                 'stamp <' || quote_literal( v_bucket_start_time +v_rrs.precision);
      RAISE DEBUG '%', v_sql;
      EXECUTE v_sql;
      v_bucket_start_time := v_bucket_start_time+v_rrs.precision;
    END LOOP;     
END;
  $log_update$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION init_bucket_time(TIMESTAMP WITH TIME ZONE, INTERVAL)
RETURNS TIMESTAMP WITH TIME ZONE AS $$
   SELECT to_timestamp( floor( extract ( EPOCH FROM $1) / extract ( EPOCH FROM $2) ) * extract(EPOCH FROM $2 ) );
  $$ LANGUAGE SQL;
