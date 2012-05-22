# Deadlock retry for MySQL 5.0.x

Original gem detects following errors and retry

- "Deadlock found when trying to get lock",
- "Lock wait timeout exceeded",
- "deadlock detected",

Update this gem to easily avoid an unfixed bug of MySQL 5.0.x:

- "Duplicate entry * for key 1 *" - Error 1062 (High concurrency problems http://bugs.mysql.com/bug.php?id=61519)
- "MySQL server has gone away" - Error 2006 (Due to lock problems)

## Contributors: 

- 37signal (https://github.com/rails/deadlock_retry) for the original gem and other contributors (https://github.com/zenkay/deadlock_retry/network) 
- Fabio Confalonieri, Zero Computing S.r.l. (http://www.zero.it) for the mod on mperham/deadlock_retry-1.0.0 version