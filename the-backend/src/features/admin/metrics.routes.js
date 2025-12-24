const express = require('express');
const router = express.Router();
const metricsController = require('./metrics.controller');
const authenticate = require('../../middlewares/auth');

// 监控面板是“实时数据”，不要让浏览器/代理缓存导致 304（Axios 默认会把 304 当成错误）
function disableCaching(req, res, next) {
  res.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
  res.set('Pragma', 'no-cache');
  res.set('Expires', '0');
  res.set('Surrogate-Control', 'no-store');

  // 避免 Conditional GET 触发 304
  delete req.headers['if-none-match'];
  delete req.headers['if-modified-since'];

  next();
}

router.use(disableCaching);

router.get('/overview', authenticate, metricsController.getOverview);
router.get('/timeseries/ratings', authenticate, metricsController.getRatingsTimeseries);
router.get('/timeseries/active-users', authenticate, metricsController.getActiveUsersTimeseries);
router.get('/distribution/ratings', authenticate, metricsController.getRatingsDistribution);
router.get('/top/movies', authenticate, metricsController.getTopMovies);
router.get('/top/users', authenticate, metricsController.getTopUsers);
router.get('/jobs', authenticate, metricsController.getJobs);

module.exports = router;
