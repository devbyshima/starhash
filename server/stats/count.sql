-- The people using StarHash: every install ever counted, and those used
-- today, in the last 7 days and in the last 30, by Kigali's date.
SELECT
  (SELECT COUNT(*) FROM installs) AS users,
  (SELECT COUNT(*) FROM active_days WHERE day = date('now', '+2 hours')) AS active_today,
  (SELECT COUNT(DISTINCT id) FROM active_days WHERE day > date('now', '+2 hours', '-7 days')) AS active_7_days,
  (SELECT COUNT(DISTINCT id) FROM active_days WHERE day > date('now', '+2 hours', '-30 days')) AS active_30_days;
