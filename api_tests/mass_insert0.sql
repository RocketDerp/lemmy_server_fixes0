-- hard-coded values
--   19 is targeted testing community from run of jest Lemmy activity simulation
--   'zy_' is a community name prefix from run of jest Lemmy activity simulation
--   Linux sed command could be used to replace these values.
--

-- real	55m2.853s
-- user	0m0.021s
-- sys	0m0.018s

-- this run
-- real	7m31.110s
--
-- INSERT 0 30000
-- INSERT 0 40000
-- INSERT 0 25000
-- INSERT 0 25000
-- DO
-- real	7m56.587s

-- benchmark references
--    https://www.tangramvision.com/blog/how-to-benchmark-postgresql-queries-well


-- scripts/clock_timestamp_function.sql
CREATE OR REPLACE FUNCTION bench(query TEXT, iterations INTEGER = 100, warmup_iterations INTEGER = 5)
RETURNS TABLE(avg FLOAT, min FLOAT, q1 FLOAT, median FLOAT, q3 FLOAT, p95 FLOAT, max FLOAT, repeats INTEGER) AS $$
DECLARE
  _start TIMESTAMPTZ;
  _end TIMESTAMPTZ;
  _delta DOUBLE PRECISION;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _bench_results (
      elapsed DOUBLE PRECISION
  );

  -- Warm the cache
  FOR i IN 1..warmup_iterations LOOP
    RAISE 'hello warmup %', i;
    EXECUTE query;
  END LOOP;

  -- Run test and collect elapsed time into _bench_results table
  FOR i IN 1..iterations LOOP
    _start = clock_timestamp();
    EXECUTE query;
    _end = clock_timestamp();
    _delta = 1000 * ( extract(epoch from _end) - extract(epoch from _start) );
    INSERT INTO _bench_results VALUES (_delta);
  END LOOP;

  RETURN QUERY SELECT
    avg(elapsed),
    min(elapsed),
    percentile_cont(0.25) WITHIN GROUP (ORDER BY elapsed),
    percentile_cont(0.5) WITHIN GROUP (ORDER BY elapsed),
    percentile_cont(0.75) WITHIN GROUP (ORDER BY elapsed),
    percentile_cont(0.95) WITHIN GROUP (ORDER BY elapsed),
    max(elapsed),
    iterations
    FROM _bench_results;
  DROP TABLE IF EXISTS _bench_results;

END
$$
LANGUAGE plpgsql;


SELECT * FROM bench('SELECT 1', 50, 0);



-- lemmy_helper benchmark_fill_post2

CREATE OR REPLACE FUNCTION benchmark_fill_post2()
RETURNS VOID AS
$$
BEGIN

			INSERT INTO post
			( name, body, community_id, creator_id, local, published )
			SELECT 'ZipGen Stress-Test Community post AAAA0000 p' || i,
				'post body ' || i,
				(SELECT id FROM community
						WHERE source=source
						AND local=true
						AND name LIKE 'zy_%'
						ORDER BY random() LIMIT 1
						),
				(SELECT id FROM person
					WHERE source=source
					AND local=true
					ORDER BY random() LIMIT 1
					),
				true,
				timezone('utc', NOW()) - ( random() * ( NOW() + '95 days' - NOW() ) )
			FROM generate_series(1, 30000) AS source(i)
			;

END
$$
LANGUAGE plpgsql;

SELECT * FROM bench('SELECT benchmark_fill_post2();', 1, 0);


-- lemmy_helper benchmark_fill_post3

CREATE OR REPLACE FUNCTION benchmark_fill_post3()
RETURNS VOID AS
$$
BEGIN
			INSERT INTO post
			( name, body, community_id, creator_id, local, published )
			SELECT 'ZipGen Stress-Test Huge Community post AAAA0000 p' || i,
				'post body ' || i,
				19, -- targeted testing community from simulation
				(SELECT id FROM person
					WHERE source=source
					AND local=true
					ORDER BY random() LIMIT 1
					),
				true,
				timezone('utc', NOW()) - ( random() * ( NOW() + '128 days' - NOW() ) )
			FROM generate_series(1, 40000) AS source(i)
			;

END
$$
LANGUAGE plpgsql;

SELECT * FROM bench('SELECT benchmark_fill_post3();', 1, 0);


-- lemmy_helper benchmark_fill_comment1

CREATE OR REPLACE FUNCTION benchmark_fill_comment1()
RETURNS VOID AS
$$
BEGIN

			INSERT INTO comment
			( id, path, ap_id, content, post_id, creator_id, local, published )
			-- ( path, content, post_id, creator_id, local, published )
			SELECT
				nextval(pg_get_serial_sequence('comment', 'id')),
				text2ltree('0.' || currval( pg_get_serial_sequence('comment', 'id')) ),
				'http://lemmy-alpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
				E'ZipGen Stress-Test message in spread of communities\n\n comment AAAA0000 c' || i
				    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') ),
				(SELECT id FROM post
					WHERE source=source
					AND community_id IN (
						-- DO NOT put source=source, static query result is fine
						SELECT id FROM community
						WHERE local=true
						AND id <> 19  -- exclude the big one to speed up inserts
						AND name LIKE 'zy_%'
						)
					AND local=true
					ORDER BY random() LIMIT 1
					),
				(SELECT id FROM person
					WHERE source=source
					AND local=true
					ORDER BY random() LIMIT 1
					),
				true,
				timezone('utc', NOW()) - ( random() * ( NOW() + '93 days' - NOW() ) )
			FROM generate_series(1, 25000) AS source(i)
			;

END
$$
LANGUAGE plpgsql;

SELECT * FROM bench('SELECT benchmark_fill_comment1();', 1, 0);


-- lemmy_helper comment2

CREATE OR REPLACE FUNCTION benchmark_fill_comment2()
RETURNS VOID AS
$$
BEGIN

			INSERT INTO comment
			( id, path, ap_id, content, post_id, creator_id, local, published )
			SELECT
				nextval(pg_get_serial_sequence('comment', 'id')),
				text2ltree('0.' || currval(pg_get_serial_sequence('comment', 'id')) ),
				'http://lemmy-alpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
				E'ZipGen Stress-Test message in Huge Community\n\n comment AAAA0000 c' || i || E'\n\n all from the same random user.'
					|| ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') ),
				(SELECT id FROM post
					WHERE source=source
					AND community_id = 19
					AND local=true
					ORDER BY random() LIMIT 1
					),
			    -- random person, but same person for all quantity
				-- NOT: source=source
				(SELECT id FROM person
					WHERE local=true
					ORDER BY random() LIMIT 1
					),
				true,
				timezone('utc', NOW()) - ( random() * ( NOW() + '93 days' - NOW() ) )
			FROM generate_series(1, 25000) AS source(i)
			;

END
$$
LANGUAGE plpgsql;

SELECT * FROM bench('SELECT benchmark_fill_comment2();', 1, 0);


-- lemmy_helper benchmark_fill_comment_reply0
-- running multiple passes will give replies to replies

CREATE OR REPLACE FUNCTION benchmark_fill_comment_reply0()
RETURNS VOID AS
$$
BEGIN


			INSERT INTO comment
			( id, path, ap_id, content, post_id, creator_id, local, published )
			SELECT
				nextval(pg_get_serial_sequence('comment', 'id')),
				text2ltree( path::text || '.' || currval(pg_get_serial_sequence('comment', 'id')) ),
				'http://lemmy-slpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
				E'ZipGen Stress-Test message in Huge Community\n\n comment AAAA0000 c' || '?' || E'\n\n all from the same random user.'
					|| ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') )
					|| ' path ' || path::text
					|| E'\n\n> ' || REPLACE(content, E'\n', ' CRLF '),
				post_id,
				-- random person, but same person for all quantity
				-- NOT: source=source
				7,
				true,
				NOW()
			FROM comment
			WHERE post_id IN
				(SELECT id FROM post
					WHERE community_id = 19
					AND local=true
					-- AND path level < 14?
					)
			AND local=true
			LIMIT 5000
			;

END
$$
LANGUAGE plpgsql;

SELECT * FROM bench('SELECT benchmark_fill_comment_reply0();', 1, 0);
