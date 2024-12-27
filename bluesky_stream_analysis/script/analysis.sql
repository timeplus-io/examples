
-- historical key word search 
SELECT
  *
FROM
  table(bluebird)
WHERE
  (record:commit.collection = 'app.bsky.feed.post') AND (record:commit.record.text ILIKE '%BTC%');

-- realtime search backfill 1 hour
SELECT
  record:commit.record.text AS post_text
FROM
  bluebird
WHERE
  (record:commit.collection = 'app.bsky.feed.post') AND (record:commit.record.text ILIKE '%BTC%') AND (_tp_time > (now() - 1h));

-- top5 replied post historical
SELECT
 count(*) AS count, record:commit.record.reply.root.cid AS root_cid
FROM
 table(bluebird)
WHERE
 (record:commit.collection = 'app.bsky.feed.post') AND (root_cid != '')
GROUP BY
 root_cid
ORDER BY
 count DESC
LIMIT 5

-- top5 replied post 5min tumble window
WITH top_5_reply_5m AS
 (
   SELECT
     window_start, top_k(record:commit.record.reply.root.cid AS root_cid, 5, true) AS top_5_root_cid
   FROM
     tumble(bluebird, 5m)
   WHERE
     (record:commit.collection = 'app.bsky.feed.post') AND (root_cid != '') AND (_tp_time > (now() - 10m))
   GROUP BY
     window_start
 )
SELECT
 window_start AS time, array_join(top_5_root_cid) AS top5, top5.1 AS cid, top5.2 AS count
FROM
 top_5_reply_5m

-- top5 reply with post content
WITH top_5_reply_5m AS
 (
   SELECT
     window_start, top_k_exact(record:commit.record.reply.root.cid AS root_cid, 5, true) AS top_5_root_cid
   FROM
     tumble(bluebird, 5m)
   WHERE
     (record:commit.collection = 'app.bsky.feed.post') AND (root_cid != '') AND (_tp_time > (now() - 10m))
   GROUP BY
     window_start
 ), top_cid AS
 (
   SELECT
     window_start AS time, array_join(top_5_root_cid) AS top5, top5.1 AS cid, top5.2 AS count
   FROM
     top_5_reply_5m
 )
SELECT
 r.time, r.cid, r.count, t.text AS text
FROM
 top_cid AS r
INNER JOIN (
   SELECT
     record:commit.cid AS cid, record:commit.record.text AS text
   FROM
     table(bluebird)
 ) AS t ON r.cid = t.cid

 -- top5 like historical
 SELECT
 count() AS count, record:commit.record.subject.cid AS subject_cid
FROM
 table(bluebird)
WHERE
 record:commit.collection = 'app.bsky.feed.like'
GROUP BY
 subject_cid
ORDER BY
 count DESC
Limit 5

-- top5 following historical
SELECT
  count() AS count, record:commit.record.subject AS following
FROM
  table(bluebird)
WHERE
  (record:commit.collection = 'app.bsky.graph.follow') AND (following != '')
GROUP BY
  following
ORDER BY
  count DESC
LIMIT 5


