DROP TABLE source_type CASCADE;

CREATE TABLE source_type (
   id serial NOT NULL PRIMARY KEY,
   name text
) WITHOUT OIDS;


DROP TABLE SOURCE CASCADE;
CREATE TABLE source (
   id serial NOT NULL PRIMARY KEY,
   server VARCHAR(32) NOT NULL,
   module VARCHAR(32) NOT NULL,
   sensor VARCHAR(32) NOT NULL,
   variable VARCHAR(32) NOT NULL,
   stype   INT NOT NULL REFERENCES source_type(id),
   precision interval NOT NULL,
   max_age interval NOT NULL DEFAULT '1 day'::interval
) WITHOUT OIDS;

DROP TABLE log;

CREATE TABLE log (
   source_id INT NOT NULL REFERENCES source(id),
   value INT NOT NULL DEFAULT 0,
   stamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
   UNIQUE (source_id,stamp)
) WITHOUT OIDS;

CREATE INDEX log_source_stamp_idx ON log (source_id,stamp);



DROP TABLE aggregate CASCADE;
CREATE TABLE aggregate (
   id serial NOT NULL PRIMARY KEY,
   aggregatefun text,
   name text 
) WITHOUT OIDS;

DROP TABLE rrs CASCADE;
CREATE TABLE rrs (
   id serial NOT NULL PRIMARY KEY,
   parent INT REFERENCES rrs(id) ON UPDATE CASCADE ON DELETE CASCADE,
   keep interval NOT NULL,
   precision interval NOT NULL
) WITHOUT OIDS;

DROP TABLE archive CASCADE;

CREATE TABLE archive (
   id serial NOT NULL PRIMARY KEY,
   source_id INT NOT NULL REFERENCES source(id) ON UPDATE CASCADE ON DELETE CASCADE,
   rrs_id INT NOT NULL REFERENCES rrs (id) ON UPDATE CASCADE ON DELETE CASCADE,
   aggregate_id INT NOT NULL REFERENCES aggregate(id) ON UPDATE CASCADE ON DELETE CASCADE
) WITHOUT OIDS;

DROP TABLE primarydata;
CREATE TABLE primarydata (
   archive_id INT REFERENCES archive(id) ON UPDATE CASCADE ON DELETE CASCADE,
   source_id INT  REFERENCES source(id) ON UPDATE CASCADE ON DELETE CASCADE,
   value INT DEFAULT 0,
   stamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
   UNIQUE (source_id,stamp),
   UNIQUE (archive_id,stamp),
   CHECK ( source_id IS NOT NULL OR archive_id IS NOT NULL)
) WITHOUT OIDS;

DROP TABLE event;

CREATE TABLE event (
   stamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
   event TEXT
)WITHOUT OIDS;

--Constraint Unique source_id,rrs_id,stamp!

COPY source_type (name) FROM stdin;
Gauge
Absolute
Counter
\.


COPY aggregate (aggregatefun,name) FROM stdin;
sum	 SUM
avg	 AVERAGE
max	 MAXIMUM
min	 MINIMUM
sum	 CUMULATIVE
\.

