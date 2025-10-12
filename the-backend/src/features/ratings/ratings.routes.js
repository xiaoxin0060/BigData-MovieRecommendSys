const express = require('express');
const router = express.Router();
const ratingController = require('./ratings.controller');
const authenticate = require('../../middlewares/auth');

// 用户评分（需要认证）
router.post('/', authenticate, ratingController.createRating);

// 获取我的所有评分（需要认证）
router.get('/my', authenticate, ratingController.getMyRatings);

// 获取某部电影的所有评分（公开）
router.get('/movie/:movieId', ratingController.getMovieRatings);

module.exports = router;

