-- hard-coded values
--   19 is targeted testing community from run of jest Lemmy activity simulation
--   'zy_' is a community name prefix from run of jest Lemmy activity simulation
--   Linux sed command could be used to replace these values.
--

SET TIME ZONE 'UTC';

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

CREATE OR REPLACE FUNCTION benchmark_fill_post2(how_many BigInt)
RETURNS VOID AS
$$
BEGIN

            INSERT INTO post_temp0
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
            FROM generate_series(1, how_many) AS source(i)
            ;

END
$$
LANGUAGE plpgsql;


-- lemmy_helper benchmark_fill_post3

CREATE OR REPLACE FUNCTION benchmark_fill_post3(how_many BigInt)
RETURNS VOID AS
$$
BEGIN
            INSERT INTO post_temp0
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
            FROM generate_series(1, how_many) AS source(i)
            ;

END
$$
LANGUAGE plpgsql;


--- fill comments without any complex select logic
--- it took twice as long?! same post / comment issue? 449455.753 ms

CREATE OR REPLACE FUNCTION benchmark_fill_comment_simple0(how_many BigInt)
RETURNS VOID AS
$$
BEGIN

            INSERT INTO comment_temp0
            ( id, path, ap_id, content, post_id, creator_id, local, published )
            SELECT
                nextval(pg_get_serial_sequence('comment', 'id')),
                text2ltree('0.' || currval( pg_get_serial_sequence('comment', 'id')) ),
                'http://lemmy-alpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
                E'ZipGen Stress-Test message comment_simple0 same post 100 same person 7\n\n comment AAAA0000 c' || i
                    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') ),
                100,
                7,
                true,
                timezone('utc', NOW()) - ( random() * ( NOW() + '93 days' - NOW() ) )
            FROM generate_series(1, how_many) AS source(i)
            ;

END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION benchmark_fill_comment_simple1(how_many BigInt)
RETURNS VOID AS
$$
BEGIN

            INSERT INTO comment_temp0
            ( id, path, ap_id, content, post_id, creator_id, local, published )
            SELECT
                nextval(pg_get_serial_sequence('comment', 'id')),
                text2ltree('0.' || currval( pg_get_serial_sequence('comment', 'id')) ),
                'http://lemmy-alpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
                E'ZipGen Stress-Test message comment_simple1 same post 101 random person\n\n comment AAAA0000 c' || i
                    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') ),
                101,
                (SELECT id FROM person
                    WHERE source=source
                    AND local=true
                    ORDER BY random() LIMIT 1
                    ),
                true,
                timezone('utc', NOW()) - ( random() * ( NOW() + '93 days' - NOW() ) )
            FROM generate_series(1, how_many) AS source(i)
            ;

END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION benchmark_fill_comment_simple2(how_many BigInt)
RETURNS VOID AS
$$
BEGIN

            INSERT INTO comment_temp0
            ( id, path, ap_id, content, post_id, creator_id, local, published )
            SELECT
                nextval(pg_get_serial_sequence('comment', 'id')),
                text2ltree('0.' || currval( pg_get_serial_sequence('comment', 'id')) ),
                'http://lemmy-alpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
                E'ZipGen Stress-Test message comment_simple2 random post_temp_id0 post all person 8\n\n comment AAAA0000 c' || i
                    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') ),
                (SELECT id FROM post_temp_id0
                    WHERE source=source
                    ORDER BY random() LIMIT 1
                    ),
                8,
                true,
                timezone('utc', NOW()) - ( random() * ( NOW() + '93 days' - NOW() ) )
            FROM generate_series(1, how_many) AS source(i)
            ;

END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION benchmark_fill_comment_simple3(how_many BigInt)
RETURNS VOID AS
$$
BEGIN

            INSERT INTO comment_temp0
            ( id, path, ap_id, content, post_id, creator_id, local, published )
            SELECT
                nextval(pg_get_serial_sequence('comment', 'id')),
                text2ltree('0.' || currval( pg_get_serial_sequence('comment', 'id')) ),
                'http://lemmy-alpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
                E'ZipGen Stress-Test message comment_simple3 (all same person, 9)\n\n comment AAAA0000 post' || post_temp_id0.id
                    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') ),
                post_temp_id0.id,
                9,
                true,
                timezone('utc', NOW()) - ( random() * ( NOW() + '93 days' - NOW() ) )
            FROM post_temp_id0
            -- no ORDER BY, already pre-random
            LIMIT how_many
            ;

END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION benchmark_fill_comment_simple4(how_many BigInt)
RETURNS VOID AS
$$
BEGIN

            INSERT INTO comment_temp0
            ( id, path, ap_id, content, post_id, creator_id, local, published )
            SELECT
                nextval(pg_get_serial_sequence('comment', 'id')),
                text2ltree('0.' || currval( pg_get_serial_sequence('comment', 'id')) ),
                'http://lemmy-alpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
                E'ZipGen Stress-Test message comment_simple4 (random person)\n\n comment AAAA0000 post' || post_temp_id0.id
                    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') ),
                post_temp_id0.id,
                (SELECT id FROM person
                    WHERE post_temp_id0.id=post_temp_id0.id
                    AND local=true
                    ORDER BY random() LIMIT 1
                    ),
                true,
                timezone('utc', NOW()) - ( random() * ( NOW() + '93 days' - NOW() ) )
            FROM post_temp_id0
            -- no ORDER BY, already pre-random
            LIMIT how_many
            ;

END
$$
LANGUAGE plpgsql;


-- lemmy_helper benchmark_fill_comment1

CREATE OR REPLACE FUNCTION benchmark_fill_comment1(how_many BigInt)
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
            FROM generate_series(1, how_many) AS source(i)
            ;

END
$$
LANGUAGE plpgsql;


-- lemmy_helper comment2

CREATE OR REPLACE FUNCTION benchmark_fill_comment2(how_many BigInt)
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
            FROM generate_series(1, how_many) AS source(i)
            ;

END
$$
LANGUAGE plpgsql;


-- lemmy_helper benchmark_fill_comment_reply0
-- running multiple passes will give replies to replies

CREATE OR REPLACE FUNCTION benchmark_fill_comment_reply0(how_many BigInt)
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
            LIMIT how_many
            ;

END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION benchmark_fill_comment_reply_using_temp0(how_many BigInt)
RETURNS VOID AS
$$
BEGIN

            INSERT INTO comment_temp0
            ( id, path, ap_id, content, post_id, creator_id, local, published )
            SELECT
                nextval(pg_get_serial_sequence('comment', 'id')),
                text2ltree( path::text || '.' || currval(pg_get_serial_sequence('comment', 'id')) ),
                'http://lemmy-slpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
                E'ZipGen Stress-Test message comment_reply_using_temp0\n\n comment AAAA0000 c' || '?' || E'\n\n all from the same random user.'
                    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') )
                    || ' path ' || path::text
                    || E'\n\n> ' || REPLACE(content, E'\n', ' CRLF '),
                comment_temp0.post_id,
                (SELECT id FROM person
                    WHERE comment_temp0.id=comment_temp0.id
                    AND local=true
                    ORDER BY random() LIMIT 1
                    ),
                true,
                NOW()
            FROM comment_temp0
            -- prior testing targeted some specific post id
            WHERE post_id NOT IN (100, 101)
            LIMIT how_many
            ;

END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION benchmark_fill_comment_reply_using_temp0_hugecommunity0(how_many BigInt)
RETURNS VOID AS
$$
BEGIN

-- this isn't really huge community 19, but just two posts.

            INSERT INTO comment_temp0
            ( id, path, ap_id, content, post_id, creator_id, local, published )
            SELECT
                nextval(pg_get_serial_sequence('comment', 'id')),
                text2ltree( path::text || '.' || currval(pg_get_serial_sequence('comment', 'id')) ),
                'http://lemmy-slpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
                E'ZipGen Stress-Test message comment_reply_using_temp0_hugecommunity0 (wrong, just 2 posts)\n\n comment AAAA0000 c' || '?' || E'\n\n all from the same random user.'
                    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') )
                    || ' path ' || path::text
                    || E'\n\n> ' || REPLACE(content, E'\n', ' CRLF '),
                comment_temp0.post_id,
                (SELECT id FROM person
                    WHERE comment_temp0.id=comment_temp0.id
                    AND local=true
                    ORDER BY random() LIMIT 1
                    ),
                true,
                NOW()
            FROM comment_temp0
            -- prior testing targeted some specific post id
            WHERE post_id IN (100, 101)
            LIMIT how_many
            ;

END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION benchmark_fill_comment_reply_using_temp0_hugecommunity1(how_many BigInt)
RETURNS VOID AS
$$
BEGIN

-- this isn't really huge community 19, but just two posts.

            INSERT INTO comment_temp0
            ( id, path, ap_id, content, post_id, creator_id, local, published )
            SELECT
                nextval(pg_get_serial_sequence('comment', 'id')),
                text2ltree( path::text || '.' || currval(pg_get_serial_sequence('comment', 'id')) ),
                'http://lemmy-slpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
                E'ZipGen Stress-Test message comment_reply_using_temp0_hugecommunity1\n\n comment AAAA0000 c' || '?' || E'\n\n all from the same random user.'
                    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') )
                    || ' path ' || path::text
                    || E'\n\n> ' || REPLACE(content, E'\n', ' CRLF '),
                comment_temp0.post_id,
                (SELECT id FROM person
                    WHERE comment_temp0.id=comment_temp0.id
                    AND local=true
                    ORDER BY random() LIMIT 1
                    ),
                true,
                NOW()
            FROM comment_temp0
            -- prior testing targeted some specific post id
            WHERE post_id IN (SELECT post_temp0 WHERE community_id = 19)
            LIMIT how_many
            ;

END
$$
LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION benchmark_fill_comment_reply_using_temp0_extendbranch(how_many BigInt, targetbranch BigInt)
RETURNS VOID AS
$$
BEGIN

            INSERT INTO comment_temp0
            ( id, path, ap_id, content, post_id, creator_id, local, published )
            SELECT
                nextval(pg_get_serial_sequence('comment', 'id')),
                text2ltree( path::text || '.' || currval(pg_get_serial_sequence('comment', 'id')) ),
                'http://lemmy-slpha:8541/comment/' || currval( pg_get_serial_sequence('comment', 'id') ),
                E'ZipGen Stress-Test message comment_reply_using_temp0_extendbranch path nlevel '
                    || targetbranch || E'\n\n comment AAAA0000 c' || '?' || E'\n\n all from the same random user.'
                    || ' PostgreSQL comment id ' || currval( pg_get_serial_sequence('comment', 'id') )
                    || ' path ' || path::text
                    || E'\n\n> ' || REPLACE(content, E'\n', ' CRLF '),
                comment_temp0.post_id,
                (SELECT id FROM person
                    WHERE comment_temp0.id=comment_temp0.id
                    AND local=true
                    ORDER BY random() LIMIT 1
                    ),
                true,
                NOW()
            FROM comment_temp0
            -- prior testing targeted some specific post id
            WHERE post_id NOT IN (100, 101)
            AND nlevel(path) > targetbranch
            LIMIT how_many
            ;

END
$$
LANGUAGE plpgsql;




-- *************************************************************************************
-- ** Revised Lemmy TRIGGER logic
-- *************************************************************************************

/*
PostgreSQL read of row carries far less overhead than an UPDATE to a row.
*/
CREATE OR REPLACE FUNCTION public.post_aggregates_comment_count() RETURNS trigger
    LANGUAGE plpgsql
    AS
$$
    DECLARE
        prev_post_aggregate RECORD; -- previous post aggregate record
        executed_update boolean DEFAULT FALSE;

BEGIN

    IF TG_OP = 'INSERT' THEN
        -- assumption made that every new comment has an already existing post_aggregates row to reference
        -- LIMIT 1 used to satisfy PostgreSQL function, but there should never be duplicates for same post_id
        -- Side benefit: this puts the taget UPDATE row into cache
        SELECT * INTO prev_post_aggregate FROM post_aggregates WHERE post_id = NEW.post_id LIMIT 1;    

        -- A 2 day necro-bump limit
        IF prev_post_aggregate.published > ('now'::timestamp - '2 days'::interval) THEN
            -- Fix issue with being able to necro-bump your own post
            IF NEW.creator_id != prev_post_aggregate.creator_id THEN
                UPDATE
                    post_aggregates pa
                SET
                    -- this statement should be for comment INSERT circumstance 1
                    newest_comment_time = NEW.published,
                    comments = comments + 1,
                    newest_comment_time_necro = NEW.published
                WHERE
                    pa.post_id = NEW.post_id;

                executed_update := TRUE;
            END IF;
        END IF;
        
        IF NOT executed_update THEN
            UPDATE
                post_aggregates pa
            SET
                -- this statement should be for comment INSERT circumstance 2
                newest_comment_time = NEW.published,
                comments = comments + 1
            WHERE
                pa.post_id = NEW.post_id;
        END IF;

    -- ELSE not an INSERT
    ELSIF EXISTS (
        -- If not INSERT, Check for post existence - it may not exist anymore
        SELECT
            1
        FROM
            post p
        WHERE
            p.id = OLD.post_id
        )
        THEN
            -- Lemmy has an issue with counting comment replies
            --   this might be a place to increment/decrement count
            --   on comment_aggregate for children comments on restore/delete.
            IF (was_restored_or_created (TG_OP, OLD, NEW)) THEN
                UPDATE
                    post_aggregates pa
                SET
                    comments = comments + 1
                WHERE
                    pa.post_id = NEW.post_id;
            ELSIF (was_removed_or_deleted (TG_OP, OLD, NEW)) THEN
                UPDATE
                    post_aggregates pa
                SET
                    comments = comments - 1
                WHERE
                    pa.post_id = OLD.post_id;
            END IF;
    END IF;

    RETURN NULL;
END
$$;

-- *************************************************************************************
-- ** Execute
-- *************************************************************************************
-- this takes: real 4m44.482s
/*
 13440.881 | 13440.881 | 13440.881 | 13440.881 | 13440.881 | 13440.881 | 13440.881 |       1
 benchmark_fill_post3 kicking off
 18826.093 | 18826.093 | 18826.093 | 18826.093 | 18826.093 | 18826.093 | 18826.093 |       1
 benchmark_fill_comment1 kicking off
 218809.803 | 218809.803 | 218809.803 | 218809.803 | 218809.803 | 218809.803 | 218809.803 |       1
 benchmark_fill_comment2 kicking off
 30791.385 | 30791.385 | 30791.385 | 30791.385 | 30791.385 | 30791.385 | 30791.385 |       1
 benchmark_fill_comment_reply0 kicking off
 2521.066 | 2521.066 | 2521.066 | 2521.066 | 2521.066 | 2521.066 | 2521.066 |       1
*/

/*
revised order of post creation, yields:
 benchmark_fill_post3 kicking off
 19381.957 | 19381.957 | 19381.957 | 19381.957 | 19381.957 | 19381.957 | 19381.957 |       1
 benchmark_fill_post2 kicking off
 19996.972 | 19996.972 | 19996.972 | 19996.972 | 19996.972 | 19996.972 | 19996.972 |       1
 benchmark_fill_comment1 kicking off
 253836.805 | 253836.805 | 253836.805 | 253836.805 | 253836.805 | 253836.805 | 253836.805 |       1
 benchmark_fill_comment2 kicking off
 35345.686 | 35345.686 | 35345.686 | 35345.686 | 35345.686 | 35345.686 | 35345.686 |       1
 benchmark_fill_comment_reply0 kicking off
 2933.079 | 2933.079 | 2933.079 | 2933.079 | 2933.079 | 2933.079 | 2933.079 |       1
*/
/*
back to original order
*/

/*
remove constraints for bulk insert
doesn't work very well
  -- probably better to create a temporary table then do bulk copy in.
aggregates will still have constraints, but still...

reading:
https://www.enterprisedb.com/blog/7-best-practice-tips-postgresql-bulk-data-loading
*/
-- ALTER TABLE ONLY public.comment DROP CONSTRAINT comment_pkey;
-- fails with: cannot drop constraint comment_pkey on table comment because other objects depend on it
-- ALTER TABLE ONLY public.post DROP CONSTRAINT post_pkey;
/*
ALTER TABLE public.comment_like SET UNLOGGED;
ALTER TABLE public.post_like SET UNLOGGED;
ALTER TABLE public.comment SET UNLOGGED;
ALTER TABLE public.post SET UNLOGGED;
*/

/*
ok, let's seee how the SELECCT performs without the INSERT overhead.
*/
CREATE TEMP TABLE post_temp0 (LIKE post INCLUDING DEFAULTS);
CREATE TEMP TABLE comment_temp0 (LIKE comment INCLUDING DEFAULTS);

CREATE SEQUENCE post_temp0_seq;
SELECT setval('post_temp0_seq', (SELECT max(id) FROM post), true);
ALTER TABLE post_temp0 ALTER id SET DEFAULT nextval('post_temp0_seq');
--ALTER SEQUENCE post_temp0_seq OWNED BY lemmy;

CREATE SEQUENCE comment_temp0_seq;
SELECT setval('comment_temp0_seq', (SELECT max(id) FROM comment), true);
ALTER TABLE comment_temp0 ALTER id SET DEFAULT nextval('comment_temp0_seq');
--ALTER SEQUENCE comment_temp0_seq OWNED BY lemmy;

-- 23m55.409s with temporary post table?


-- communities come first in Lemmy
-- already generated by the simulation jest test script

-- posts then go into Community
SELECT 'benchmark_fill_post2 kicking off' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_post2(30000);', 1, 0);
SELECT 'benchmark_fill_post3 kicking off' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_post3(30000);', 1, 0);

-- copy in the temp post table to main post table
--SELECT 'copy post temp table into main post table, kicking off' AS status_message;
--SELECT * FROM bench('INSERT INTO post SELECT * FROM post_temp0', 1, 0);



-- CREATE TEMP TABLE post_temp_id0 (LIKE post INCLUDING DEFAULTS);
DROP TABLE IF EXISTS post_temp_id0;
SELECT 'post targets post_temp_id0 kicking off' AS status_message;
SELECT * FROM bench('
CREATE TEMP TABLE IF NOT EXISTS post_temp_id0 AS (
   SELECT id FROM post_temp0
   ORDER BY random() LIMIT 25000
);', 1, 0);
-- spit out 10 to see what it looks like.
SELECT * FROM post_temp_id0 LIMIT 10;

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT pg_stat_statements_reset();


-- Comments come next in Lemmy, they go onto a post
SELECT 'simple comment0' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_simple0(1000);', 1, 0);
SELECT 'simple comment1' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_simple1(1333);', 1, 0);
--SELECT 'simple comment2' AS status_message;
--SELECT * FROM bench('SELECT benchmark_fill_comment_simple2(25000);', 1, 0);
SELECT 'simple comment3' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_simple3(922);', 1, 0);
SELECT 'simple comment4' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_simple4(777);', 1, 0);
/*
without child count on comment_aggregates, lemmy-ui may not show replies!
*/
SELECT 'benchmark_fill_comment_reply_using_temp0 kicking off' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply_using_temp0(2711);', 1, 0);

SELECT 'benchmark_fill_comment_reply_using_temp0_hugecommunity0 kicking off, 12 runs' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply_using_temp0_hugecommunity0(2711);', 12, 0);
SELECT 'benchmark_fill_comment_reply_using_temp0_hugecommunity1 kicking off, 12 runs' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply_using_temp0_hugecommunity1(2711);', 12, 0);

SELECT 'benchmark_fill_comment_reply_using_temp0 ROUND 2 kicking off 20 runs' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply_using_temp0(3200);', 20, 0);
SELECT 'benchmark_fill_comment_reply_using_temp0_extendbranch ROUND 1 kicking off 5 runs level 3' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply_using_temp0_extendbranch(3200, 3);', 5, 0);
SELECT 'benchmark_fill_comment_reply_using_temp0_extendbranch ROUND 2 kicking off 5 runs level 4' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply_using_temp0_extendbranch(3200, 4);', 5, 0);
SELECT 'benchmark_fill_comment_reply_using_temp0_extendbranch ROUND 3 kicking off 5 runs level 5' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply_using_temp0_extendbranch(3200, 5);', 5, 0);
SELECT 'benchmark_fill_comment_reply_using_temp0_extendbranch ROUND 4 kicking off 3 runs level 6' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply_using_temp0_extendbranch(3200, 6);', 3, 0);
SELECT 'benchmark_fill_comment_reply_using_temp0_extendbranch ROUND 5 kicking off 3 runs level 7' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply_using_temp0_extendbranch(3200, 7);', 3, 0);

SELECT COUNT(*) FROM comment_temp0 AS comment_temp0_cuunt;

SELECT MAX(nlevel(path)) AS comment_temp0_path_max_level FROM comment_temp0;


/*
copy in the temp post table to main post table
  the per-row trigger action going on for aggregates must make this slower and why temp table so much faster
   could reproduce the trigger as a per-statement action for these operations, remove/restore existing trigger before/after
*/
SELECT 'copy post temp table into main post table, kicking off' AS status_message;
SELECT * FROM bench('INSERT INTO post SELECT * FROM post_temp0', 1, 0);
SELECT 'copy comment temp table into main post table, kicking off' AS status_message;
SELECT * FROM bench('INSERT INTO comment SELECT * FROM comment_temp0', 1, 0);

-- review results interactively with lemmy-ui

/*
SELECT 'benchmark_fill_comment1 kicking off' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment1(25000);', 1, 0);
SELECT 'benchmark_fill_comment2 kicking off' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment2(5000);', 1, 0);
SELECT 'benchmark_fill_comment_reply0 kicking off' AS status_message;
SELECT * FROM bench('SELECT benchmark_fill_comment_reply0(5000);', 1, 0);
*/

/*
-- ALTER TABLE ONLY public.comment ADD CONSTRAINT comment_pkey PRIMARY KEY (id);
-- ALTER TABLE ONLY public.post ADD CONSTRAINT post_pkey PRIMARY KEY (id);

ALTER TABLE public.comment SET LOGGED;
ALTER TABLE public.post SET LOGGED;
*/


/*
Can we come up with a way to update child count of comment_aggregates in mass?
cound only those with nlevel(15), then 14, then 13
and as we get to the lower levels, use prior counts from comment_aggregates instead of direct counts?
Run this as own .sql file while developing?
*/
SELECT count(*) AS comments_with_child_count_rows
    FROM comment_aggregates
    WHERE child_count > 0;


SELECT 'PostgreSQL seems to be confuused if next section is all commented out?';

/*
Lemmhy 0.18.4 existing logic:
removed dollar-dollar to prevent PostgreSQL confusion

CREATE FUNCTION public.post_aggregates_comment_count() RETURNS trigger
    LANGUAGE plpgsql
    AS 
BEGIN
    -- Check for post existence - it may not exist anymore
    IF TG_OP = 'INSERT' OR EXISTS (
        SELECT
            1
        FROM
            post p
        WHERE
            p.id = OLD.post_id) THEN
        IF (was_restored_or_created (TG_OP, OLD, NEW)) THEN
            UPDATE
                post_aggregates pa
            SET
                comments = comments + 1
            WHERE
                pa.post_id = NEW.post_id;
        ELSIF (was_removed_or_deleted (TG_OP, OLD, NEW)) THEN
            UPDATE
                post_aggregates pa
            SET
                comments = comments - 1
            WHERE
                pa.post_id = OLD.post_id;
        END IF;
    END IF;
    IF TG_OP = 'INSERT' THEN
        UPDATE
            post_aggregates pa
        SET
            newest_comment_time = NEW.published
        WHERE
            pa.post_id = NEW.post_id;
        -- A 2 day necro-bump limit
        UPDATE
            post_aggregates pa
        SET
            newest_comment_time_necro = NEW.published
        FROM
            post p
        WHERE
            pa.post_id = p.id
            AND pa.post_id = NEW.post_id
            -- Fix issue with being able to necro-bump your own post
            AND NEW.creator_id != p.creator_id
            AND pa.published > ('now'::timestamp - '2 days'::interval);
    END IF;
    RETURN NULL;
END

*/
