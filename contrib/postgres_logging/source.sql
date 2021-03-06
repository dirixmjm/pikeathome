-- Copyright (c) 2012, Marc Dirix (marc@dirix.nu)

CREATE OR REPLACE FUNCTION log_data(i_key VARCHAR,i_value INT, i_tstamp TIMESTAMP WITH TIME ZONE)
RETURNS VOID AS $log_data$
DECLARE
    v_source source%ROWTYPE;
BEGIN
  SELECT * INTO v_source FROM source WHERE key=i_key;
  IF v_source IS NULL THEN
  -- Guess variable type and create it
    INSERT INTO source (key,stype,precision, max_age) VALUES
      (i_key,1,'00:01:00'::INTERVAL,'01:00:00'::INTERVAL);
    SELECT * INTO v_source FROM source WHERE key=i_key;
  END IF;
    INSERT INTO log (source_id,stamp,value) VALUES 
      (v_source.id,i_tstamp,i_value);
END;
  $log_data$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION log_before_insert()
RETURNS TRIGGER AS $log_insert$ 
DECLARE
  v_last_log TIMESTAMP WITH TIME ZONE;
  v_last_primarydata TIMESTAMP WITH TIME ZONE;
BEGIN
    --Data must arrive chronological
   SELECT coalesce(max(stamp),to_timestamp(0)) into v_last_log 
      FROM log WHERE source_id=NEW.source_id;
   IF NEW.stamp < v_last_log THEN
      RAISE EXCEPTION 'Data older than youngest value';
   END IF;

   --Check if the data isn't in the future (1 minute max clockskew)
   IF NEW.stamp > current_timestamp + '5 minute'::interval THEN
      RAISE EXCEPTION 'Data in the future';
   END IF;

  RETURN NEW;
END;
  $log_insert$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION log_after_insert()
RETURNS TRIGGER AS $log_insert$ 
DECLARE
  v_last_primarydata TIMESTAMP WITH TIME ZONE;
  v_first_logdata TIMESTAMP WITH TIME ZONE;
  v_source RECORD;
  v_value INT;
  v_value_old INT;
BEGIN
  --Get Source Parameters
  SELECT * INTO v_source  FROM source WHERE id=NEW.source_id;
  
  SELECT max(stamp) into v_last_primarydata FROM primarydata WHERE
    source_id=NEW.source_id;

  IF v_last_primarydata IS NULL THEN
     --Get the oldest log, and start a buffer from there on
     SELECT min(stamp) INTO v_first_logdata FROM log WHERE source_id=NEW.source_id;
     v_last_primarydata = init_primarydata_stamp(v_first_logdata,v_source.precision) - v_source.precision;
  END IF;


  IF NEW.stamp < v_last_primarydata THEN
      RAISE EXCEPTION 'Data is older then last primary datapoint';
  END IF;

  <<bucketloop>>
  LOOP 
  --IF data fits in the "current" bucket, we wait for it to complete
  --if not, we can safely create the primary datapoint
    v_last_primarydata := v_last_primarydata + v_source.precision;
    EXIT bucketloop WHEN v_last_primarydata > NEW.stamp;

    IF v_source.stype=1 THEN
      SELECT avg(value)::INT INTO v_value FROM log WHERE source_id=NEW.source_id AND 
        stamp >= v_last_primarydata AND 
        stamp < v_last_primarydata+v_source.precision;
    ELSEIF v_source.stype=2 THEN
      SELECT sum(value) INTO v_value FROM log WHERE source_id=NEW.source_id AND 
        stamp >= v_last_primarydata AND 
        stamp < v_last_primarydata+v_source.precision;
    ELSEIF v_source.stype=3 THEN
      SELECT max(value) INTO v_value_old FROM log 
           WHERE source_id=NEW.source_id AND stamp <= v_last_primarydata;
      SELECT COALESCE(max(value),v_value_old) INTO v_value FROM log 
        WHERE source_id=NEW.source_id AND 
        stamp >= v_last_primarydata AND 
        stamp < v_last_primarydata+v_source.precision;
      IF v_value_old IS NULL THEN
        v_value = 0;
      ELSE
        v_value:= v_value - v_value_old; 
      END IF;
    ELSE
      RAISE EXCEPTION 'Unknown source_type %',v_source.stype;
    END IF;
    --Check if the bucket has no data values
    IF v_value IS NULL AND 
        v_last_primarydata >= (NEW.stamp - v_source.max_age ) THEN
     v_value = NEW.value::INT;
    END IF;
    --Now Fill the data for this timestamp

    INSERT INTO primarydata (source_id,stamp,value ) VALUES
        ( NEW.source_id,v_last_primarydata,v_value);
  END LOOP;
  RETURN NULL;
END;
  $log_insert$ LANGUAGE PLPGSQL;



CREATE OR REPLACE FUNCTION init_primarydata_stamp(TIMESTAMP WITH TIME ZONE, INTERVAL)
RETURNS TIMESTAMP WITH TIME ZONE AS $$
   SELECT to_timestamp( floor( extract ( EPOCH FROM $1) / extract ( EPOCH FROM $2) ) * extract(EPOCH FROM $2 ) );
  $$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION init_bucket_time(INTERVAL, INTERVAL)
RETURNS TIMESTAMP WITH TIME ZONE AS $$
   SELECT to_timestamp( floor( extract ( EPOCH FROM (current_timestamp - $1)) / extract ( EPOCH FROM $2) ) * extract(EPOCH FROM $2 ) ); 
  $$ LANGUAGE SQL;

CREATE TRIGGER log_before_trg BEFORE INSERT ON log
    FOR EACH ROW EXECUTE PROCEDURE log_before_insert(); 

CREATE TRIGGER log_after_trg AFTER INSERT ON log
    FOR EACH ROW EXECUTE PROCEDURE log_after_insert(); 

--CREATE TRIGGER log_update_trg AFTER INSERT ON log
--    FOR EACH ROW EXECUTE PROCEDURE log_update(); 
