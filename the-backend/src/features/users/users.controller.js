const prisma = require('../../config/database');
const bcrypt = require('bcrypt');
const { generateToken } = require('../../utils/jwt');

/**
 * 用户注册
 */
async function register(req, res, next) {
  try {
    const { userAccount, userPassword, userName, gender } = req.body;

    // 1. 参数验证
    if (!userAccount || !userPassword) {
      return res.status(400).json({
        success: false,
        message: '账号和密码不能为空'
      });
    }

    // 2. 检查账号是否已存在
    const existingUser = await prisma.user.findUnique({
      where: { userAccount }
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: '该账号已被注册'
      });
    }

    // 3. 密码加密
    const hashedPassword = await bcrypt.hash(userPassword, 10);

    // 4. 创建用户
    const user = await prisma.user.create({
      data: {
        userAccount,
        userPassword: hashedPassword,
        userName: userName || null,
        gender: gender || null
      }
    });

    // 5. 返回成功（不返回密码）
    res.status(201).json({
      success: true,
      message: '注册成功',
      data: {
        id: user.id.toString(),  // BigInt 转字符串
        userAccount: user.userAccount,
        userName: user.userName,
        gender: user.gender
      }
    });

  } catch (error) {
    next(error);  // 传递给错误处理中间件
  }
}

/**
 * 用户登录
 */
async function login(req, res, next) {
  try {
    const { userAccount, userPassword } = req.body;

    // 1. 参数验证
    if (!userAccount || !userPassword) {
      return res.status(400).json({
        success: false,
        message: '账号和密码不能为空'
      });
    }

    // 2. 查找用户
    const user = await prisma.user.findUnique({
      where: { userAccount }
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: '账号或密码错误1'     
      });
    }

    // 3. 验证密码（支持密文和明文）
    let isPasswordValid = false;
    
    // 先尝试密文匹配（bcrypt）
    try {
      isPasswordValid = await bcrypt.compare(userPassword, user.userPassword);
    } catch (error) {
      // bcrypt 比对失败，可能是明文密码
      isPasswordValid = false;
    }
    
    // 如果密文匹配失败，尝试明文匹配（用于测试数据）
    if (!isPasswordValid) {
      isPasswordValid = (userPassword === user.userPassword);
    }

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: '账号或密码错误2'
      });
    }

    // 4. 生成 JWT Token
    const token = generateToken({
      userId: user.id.toString(),
      userAccount: user.userAccount
    });

    // 5. 登录成功，返回 token 和用户信息
    res.json({
      success: true,
      message: '登录成功',
      data: {
        token,  // JWT Token
        user: {
          id: user.id.toString(),
          userAccount: user.userAccount,
          userName: user.userName,
          gender: user.gender
        }
      }
    });

  } catch (error) {
    next(error);
  }
}

/**
 * 获取当前登录用户信息
 * 需要认证：通过 JWT 认证中间件
 */
async function getProfile(req, res, next) {
  try {
    // req.userId 由认证中间件注入
    const userId = req.userId;

    // 查询用户信息
    const user = await prisma.user.findUnique({
      where: { id: BigInt(userId) },
      select: {
        id: true,
        userAccount: true,
        userName: true,
        gender: true
        // 注意：不返回密码
      }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: '用户不存在'
      });
    }

    res.json({
      success: true,
      data: {
        id: user.id.toString(),
        userAccount: user.userAccount,
        userName: user.userName,
        gender: user.gender
      }
    });

  } catch (error) {
    next(error);
  }
}

/**
 * 获取用户统计数据
 */
async function getUserStats(req, res, next) {
  try {
    const userId = req.userId;

    // 并行查询统计数据
    const [ratingsCount, recommendationsCount, avgRatingData] = await Promise.all([
      // 评分数量
      prisma.rating.count({
        where: { userId: BigInt(userId) }
      }),
      // 推荐数量
      prisma.recommendation.count({
        where: { userId: BigInt(userId) }
      }),
      // 平均评分
      prisma.rating.aggregate({
        where: { userId: BigInt(userId) },
        _avg: { rating: true }
      })
    ]);

    res.json({
      success: true,
      data: {
        ratingsCount,
        recommendationsCount,
        avgRating: avgRatingData._avg.rating ? Number(avgRatingData._avg.rating).toFixed(1) : '0.0'
      }
    });

  } catch (error) {
    next(error);
  }
}

module.exports = {
  register,
  login,
  getProfile,
  getUserStats
};