const express = require('express');
const router = express.Router();
const userController = require('./users.controller');
const authenticate = require('../../middlewares/auth');

// 用户注册
router.post('/register', userController.register);

// 用户登录
router.post('/login', userController.login);

// 获取用户统计数据
router.get('/stats', authenticate, userController.getUserStats);

// 获取当前用户信息
router.get('/profile', authenticate, userController.getProfile);

module.exports = router;