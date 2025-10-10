const jwt = require('jsonwebtoken');

// JWT 密钥（从环境变量读取）
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// Token 过期时间（7天）
const JWT_EXPIRES_IN = '7d';

/**
 * 生成 JWT Token
 * @param {Object} payload - 要加密的数据（通常是用户信息）
 * @returns {String} token
 */
function generateToken(payload) {
  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: JWT_EXPIRES_IN
  });
}

/**
 * 验证 JWT Token
 * @param {String} token - 要验证的 token
 * @returns {Object} 解码后的数据
 * @throws {Error} token 无效或过期时抛出错误
 */
function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Token 已过期，请重新登录');
    }
    if (error.name === 'JsonWebTokenError') {
      throw new Error('无效的 Token');
    }
    throw error;
  }
}

module.exports = {
  generateToken,
  verifyToken
};

