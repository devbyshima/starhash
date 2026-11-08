-- Daily active users for the last 30 days, newest first, with the installs
-- first seen that day.
SELECT
  a.day,
  COUNT(*) AS active,
  (SELECT COUNT(*) FROM installs i WHERE i.first_seen = a.day) AS new
FROM active_days a
WHERE a.day > date('now', '+2 hours', '-30 days')
GROUP BY a.day
ORDER BY a.day DESC;
