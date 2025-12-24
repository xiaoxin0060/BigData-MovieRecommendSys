var express = require('express');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var cors = require('cors');

var app = express();

// ===== 中间件配置 =====
app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());

// ===== CORS 配置（允许 Vue 前端跨域访问）=====
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:5173',  // Vue 3 + Vite 默认端口
  credentials: true  // 允许携带 Cookie
}));

// ===== API 路由 =====
const userApiRoutes = require('./features/users/users.routes');
const movieApiRoutes = require('./features/movies/movies.routes');
const ratingApiRoutes = require('./features/ratings/ratings.routes');
const recommendationApiRoutes = require('./features/recommendations/recommendations.routes');
const adminMetricsRoutes = require('./features/admin/metrics.routes');

app.use('/api/users', userApiRoutes);
app.use('/api/movies', movieApiRoutes);
app.use('/api/ratings', ratingApiRoutes);
app.use('/api/recommendations', recommendationApiRoutes);
app.use('/api/admin/metrics', adminMetricsRoutes);

// ===== 健康检查接口 =====
app.get('/api/health', function(req, res) {
  res.json({
    success: true,
    message: 'API 服务运行正常',
    timestamp: new Date().toISOString()
  });
});

// ===== 404 处理 =====
app.use(function(req, res, next) {
  res.status(404).json({
    success: false,
    message: `接口不存在: ${req.method} ${req.path}`
  });
});

// ===== 统一错误处理 =====
const errorHandler = require('./middlewares/errorHandler');
app.use(errorHandler);

module.exports = app;
