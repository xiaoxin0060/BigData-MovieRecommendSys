const express = require('express');
const router = express.Router();
const movieController = require('./movies.controller');

// 获取电影列表
router.get('/', movieController.getMovies);

// 获取电影详情
router.get('/:id', movieController.getMovieById);

module.exports = router;

