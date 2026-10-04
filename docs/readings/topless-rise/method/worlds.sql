WITH r AS (SELECT id, parent_run_id, parent_epoch FROM runs WHERE experiment_id = 20),
settled AS (
  SELECT s.run_id, s.epoch, ROW_NUMBER() OVER (PARTITION BY s.run_id ORDER BY s.epoch) AS i,
         COUNT(*) OVER (PARTITION BY s.run_id) AS n
  FROM samples s JOIN r ON s.run_id = r.id WHERE s.epoch > r.parent_epoch + 1000),
bounds AS (
  SELECT run_id, MIN(epoch) AS first_settled, MAX(epoch) FILTER (WHERE i <= 5 * n / 10) AS fifth_end,
         MAX(n) AS n
  FROM settled GROUP BY run_id),
stored AS (
  SELECT sn.run_id, sn.epoch FROM snapshots sn JOIN r ON sn.run_id = r.id WHERE sn.blob IS NOT NULL)
SELECT r.id, r.parent_run_id, b.n, b.first_settled, b.fifth_end,
  (SELECT MIN(epoch) FROM stored st WHERE st.run_id = r.id AND st.epoch >= b.first_settled),
  (SELECT MAX(epoch) FROM stored st WHERE st.run_id = r.id AND st.epoch <= b.fifth_end),
  (SELECT MAX(epoch) FROM stored st WHERE st.run_id = r.id)
FROM r JOIN bounds b ON b.run_id = r.id ORDER BY r.id;
