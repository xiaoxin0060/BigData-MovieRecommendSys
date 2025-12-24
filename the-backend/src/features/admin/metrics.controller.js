const prisma = require('../../config/database');

function toNumber(value, fallback = 0) {
  if (value === null || value === undefined) return fallback;
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function clampInt(value, min, max, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(n)));
}

function parseTimeRangeSec(req, { defaultLookbackMs }) {
  const now = new Date();
  let from = req.query.from ? new Date(req.query.from) : new Date(now.getTime() - defaultLookbackMs);
  let to = req.query.to ? new Date(req.query.to) : now;

  if (isNaN(from.getTime())) from = new Date(now.getTime() - defaultLookbackMs);
  if (isNaN(to.getTime())) to = now;

  const fromSec = Math.floor(from.getTime() / 1000);
  const toSec = Math.floor(to.getTime() / 1000);
  return { from, to, fromSec, toSec };
}

async function getOverview(req, res, next) {
  try {
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // 使用 rating.timestamp(秒) 走索引；created_at 在大表上会导致慢查询
    const nowSec = Math.floor(now.getTime() / 1000);
    const startOfTodaySec = Math.floor(startOfToday.getTime() / 1000);
    const last24hSec = nowSec - 24 * 60 * 60;
    const last1hSec = nowSec - 60 * 60;

    const q = prisma.$queryRawUnsafe.bind(prisma);

    // 大表统计尽量用 information_schema 的 table_rows（近似值，换取实时性）
    const tableRowsPromise = q(`
      SELECT table_name, table_rows
      FROM information_schema.tables
      WHERE table_schema = DATABASE()
        AND table_name IN ('user', 'movie', 'rating', 'recommendation')
    `).catch(() => []);

    const [
      tableRows,
      usersTotalAccurate,
      usersNewToday,
      activeTodayRow,
      moviesTotalAccurate,
      moviesWithRatings,
      ratingsLast24hRow,
      ratingsLast1hRow,
      meta,
      batchAlsHeartbeat
    ] = await Promise.all([
      tableRowsPromise,
      prisma.user.count().catch(() => null),
      prisma.user.count({
        where: {
          created_at: {
            gte: startOfToday
          }
        }
      }).catch(() => 0),
      q('SELECT COUNT(DISTINCT userId) AS cnt FROM rating WHERE `timestamp` IS NOT NULL AND `timestamp` >= ?', startOfTodaySec)
        .then((rows) => rows?.[0] || null)
        .catch(() => null),
      prisma.movie.count().catch(() => null),
      prisma.movie.count({
        where: {
          ratingCount: {
            gt: 0
          }
        }
      }).catch(() => 0),
      q('SELECT COUNT(*) AS cnt FROM rating WHERE `timestamp` IS NOT NULL AND `timestamp` >= ?', last24hSec)
        .then((rows) => rows?.[0] || null)
        .catch(() => null),
      q('SELECT COUNT(*) AS cnt FROM rating WHERE `timestamp` IS NOT NULL AND `timestamp` >= ?', last1hSec)
        .then((rows) => rows?.[0] || null)
        .catch(() => null),
      prisma.rec_model_meta.findUnique({ where: { id: 1 } }).catch(() => null),
      q(`
        SELECT job_name, last_run_start_at, last_run_end_at, metrics_json
        FROM monitor_job_heartbeat
        WHERE job_name = 'batch_als'
        LIMIT 1
      `).then((rows) => rows?.[0] || null).catch(() => null)
    ]);

    const rowsMap = new Map(
      (tableRows || []).map((r) => [String(r.TABLE_NAME || r.table_name), r.TABLE_ROWS ?? r.table_rows])
    );

    const usersTotal = usersTotalAccurate ?? toNumber(rowsMap.get('user'), 0);
    const moviesTotal = moviesTotalAccurate ?? toNumber(rowsMap.get('movie'), 0);
    const ratingsTotal = toNumber(rowsMap.get('rating'), 0);
    const recsTotal = toNumber(rowsMap.get('recommendation'), 0);

    const activeToday = toNumber(activeTodayRow?.cnt, 0);
    const activeVersion = meta?.active_version || 'v0';

    // coverageActiveVersion 在 recommendation 大表上做 DISTINCT 会很慢：优先从 batch_als 的 metrics_json 取近似值
    let coverageActiveVersion = null;
    if (batchAlsHeartbeat?.metrics_json) {
      try {
        const mj = typeof batchAlsHeartbeat.metrics_json === 'string'
          ? JSON.parse(batchAlsHeartbeat.metrics_json)
          : batchAlsHeartbeat.metrics_json;
        if (mj && mj.uniqueUsers != null) coverageActiveVersion = toNumber(mj.uniqueUsers, null);
      } catch (e) {
        coverageActiveVersion = null;
      }
    }

    const lastGeneratedAt =
      batchAlsHeartbeat?.last_run_end_at ||
      batchAlsHeartbeat?.last_run_start_at ||
      meta?.updated_at ||
      null;

    res.json({
      success: true,
      data: {
        users: {
          total: usersTotal,
          newToday: usersNewToday,
          activeToday
        },
        movies: {
          total: moviesTotal,
          withRatings: moviesWithRatings
        },
        ratings: {
          total: ratingsTotal,
          last24h: toNumber(ratingsLast24hRow?.cnt, 0),
          last1h: toNumber(ratingsLast1hRow?.cnt, 0)
        },
        recommendations: {
          total: recsTotal,
          coverageActiveVersion,
          activeModelVersion: activeVersion,
          lastGeneratedAt
        }
      }
    });
  } catch (error) {
    next(error);
  }
}

async function getRatingsTimeseries(req, res, next) {
  try {
    const interval = (req.query.interval || 'hour').toString();
    if (interval !== 'hour') {
      return res.status(400).json({
        success: false,
        message: '暂仅支持 interval=hour'
      });
    }

    const { from, to, fromSec, toSec } = parseTimeRangeSec(req, { defaultLookbackMs: 24 * 60 * 60 * 1000 });

    // 用 timestamp(秒) + 索引做时间序列；created_at + DATE_FORMAT 会导致全表扫描
    const sql = `
      SELECT DATE_FORMAT(FROM_UNIXTIME(\`timestamp\`), '%Y-%m-%d %H:00:00') AS ts, COUNT(*) AS cnt
      FROM rating
      WHERE \`timestamp\` IS NOT NULL
        AND \`timestamp\` BETWEEN ? AND ?
      GROUP BY ts
      ORDER BY ts
    `;

    let rows = [];
    try {
      rows = await prisma.$queryRawUnsafe(sql, fromSec, toSec);
    } catch (e) {
      rows = [];
    }

    const points = rows.map((row) => ({
      timestamp: row.ts,
      value: Number(row.cnt)
    }));

    res.json({
      success: true,
      data: {
        interval,
        from,
        to,
        points
      }
    });
  } catch (error) {
    next(error);
  }
}

async function getActiveUsersTimeseries(req, res, next) {
  try {
    const interval = (req.query.interval || 'hour').toString();
    if (interval !== 'hour') {
      return res.status(400).json({
        success: false,
        message: '暂时仅支持 interval=hour'
      });
    }

    const { from, to, fromSec, toSec } = parseTimeRangeSec(req, { defaultLookbackMs: 24 * 60 * 60 * 1000 });

    const sql = `
      SELECT DATE_FORMAT(FROM_UNIXTIME(\`timestamp\`), '%Y-%m-%d %H:00:00') AS ts, COUNT(DISTINCT userId) AS cnt
      FROM rating
      WHERE \`timestamp\` IS NOT NULL
        AND \`timestamp\` BETWEEN ? AND ?
      GROUP BY ts
      ORDER BY ts
    `;

    let rows = [];
    try {
      rows = await prisma.$queryRawUnsafe(sql, fromSec, toSec);
    } catch (e) {
      rows = [];
    }

    const points = rows.map((row) => ({
      timestamp: row.ts,
      value: Number(row.cnt)
    }));

    res.json({
      success: true,
      data: {
        interval,
        from,
        to,
        points
      }
    });
  } catch (error) {
    next(error);
  }
}

async function getRatingsDistribution(req, res, next) {
  try {
    const { from, to, fromSec, toSec } = parseTimeRangeSec(req, { defaultLookbackMs: 24 * 60 * 60 * 1000 });

    const sql = `
      SELECT rating AS rating, COUNT(*) AS cnt
      FROM rating
      WHERE \`timestamp\` IS NOT NULL
        AND \`timestamp\` BETWEEN ? AND ?
      GROUP BY rating
      ORDER BY rating
    `;

    let rows = [];
    try {
      rows = await prisma.$queryRawUnsafe(sql, fromSec, toSec);
    } catch (e) {
      rows = [];
    }

    const buckets = rows.map((row) => ({
      rating: Number(row.rating),
      count: Number(row.cnt)
    }));

    res.json({
      success: true,
      data: {
        from,
        to,
        buckets
      }
    });
  } catch (error) {
    next(error);
  }
}

async function getTopMovies(req, res, next) {
  try {
    const limit = clampInt(req.query.limit, 1, 50, 10);
    const sql = `
      SELECT id, title, year, genres, avgRating, ratingCount
      FROM movie
      ORDER BY ratingCount DESC, avgRating DESC
      LIMIT ${limit}
    `;

    let rows = [];
    try {
      rows = await prisma.$queryRawUnsafe(sql);
    } catch (e) {
      rows = [];
    }

    const movies = rows.map((row) => ({
      id: row.id != null ? String(row.id) : null,
      title: row.title || '',
      year: row.year != null ? Number(row.year) : null,
      genres: row.genres || null,
      avgRating: row.avgRating != null ? Number(row.avgRating) : 0,
      ratingCount: row.ratingCount != null ? Number(row.ratingCount) : 0
    }));

    res.json({
      success: true,
      data: {
        movies
      }
    });
  } catch (error) {
    next(error);
  }
}

async function getTopUsers(req, res, next) {
  try {
    const limit = clampInt(req.query.limit, 1, 50, 10);
    const { from, to, fromSec, toSec } = parseTimeRangeSec(req, { defaultLookbackMs: 24 * 60 * 60 * 1000 });

    const sql = `
      SELECT r.userId AS userId, u.userName AS userName, u.userAccount AS userAccount, COUNT(*) AS cnt
      FROM rating r
      JOIN user u ON u.id = r.userId
      WHERE r.\`timestamp\` IS NOT NULL
        AND r.\`timestamp\` BETWEEN ? AND ?
      GROUP BY r.userId
      ORDER BY cnt DESC
      LIMIT ${limit}
    `;

    let rows = [];
    try {
      rows = await prisma.$queryRawUnsafe(sql, fromSec, toSec);
    } catch (e) {
      rows = [];
    }

    const users = rows.map((row) => ({
      userId: row.userId != null ? String(row.userId) : null,
      userName: row.userName || null,
      userAccount: row.userAccount || null,
      ratings: row.cnt != null ? Number(row.cnt) : 0
    }));

    res.json({
      success: true,
      data: {
        from,
        to,
        users
      }
    });
  } catch (error) {
    next(error);
  }
}

async function getJobs(req, res, next) {
  try {
    const sql = `
      SELECT job_name, status, last_heartbeat_at, last_run_start_at, last_run_end_at,
             last_batch_size, last_batch_duration_ms, model_version, metrics_json
      FROM monitor_job_heartbeat
    `;

    const rows = await prisma.$queryRawUnsafe(sql);

    const jobs = rows.map((row) => {
      let metrics = null;
      if (row.metrics_json !== null && row.metrics_json !== undefined) {
        if (typeof row.metrics_json === 'string') {
          try {
            metrics = JSON.parse(row.metrics_json);
          } catch (e) {
            metrics = null;
          }
        } else {
          metrics = row.metrics_json;
        }
      }

      return {
        jobName: row.job_name,
        status: row.status,
        lastHeartbeatAt: row.last_heartbeat_at,
        lastRunStartAt: row.last_run_start_at,
        lastRunEndAt: row.last_run_end_at,
        lastBatchSize: row.last_batch_size != null ? Number(row.last_batch_size) : null,
        lastBatchDurationMs: row.last_batch_duration_ms != null ? Number(row.last_batch_duration_ms) : null,
        modelVersion: row.model_version || null,
        metrics
      };
    });

    res.json({
      success: true,
      data: {
        jobs
      }
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getOverview,
  getRatingsTimeseries,
  getActiveUsersTimeseries,
  getRatingsDistribution,
  getTopMovies,
  getTopUsers,
  getJobs
};
