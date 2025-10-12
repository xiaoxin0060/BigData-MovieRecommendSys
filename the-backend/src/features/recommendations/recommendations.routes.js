const express = require('express');
const router = express.Router();
const recommendationController = require('./recommendations.controller');
const authenticate = require('../../middlewares/auth');

// 获取个性化推荐（需要认证）
router.get('/for-me', authenticate, recommendationController.getMyRecommendations);

// 获取相似电影推荐（公开）
router.get('/similar/:movieId', recommendationController.getSimilarMovies);

module.exports = router;

