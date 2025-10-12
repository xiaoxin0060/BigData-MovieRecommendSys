const { verifyToken } = require('../utils/jwt');

/**
 * JWT 认证中间件
 * 验证请求头中的 token，并将用户信息注入到 req 对象
 */
function authenticate(req, res, next) {
  try {
    // 1. 从请求头获取 token
    // 格式：Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: '未提供认证 Token，请先登录'
      });
    }

    // 2. 提取 token（去掉 "Bearer " 前缀）
    const token = authHeader.startsWith('Bearer ') 
      ? authHeader.slice(7) 
      : authHeader;

    // 3. 验证 token
    const decoded = verifyToken(token);

    // 4. 将用户信息注入到 req 对象，供后续使用
    req.userId = decoded.userId;
    req.userAccount = decoded.userAccount;

    // 5. 继续执行下一个中间件
    next();

  } catch (error) {
    // Token 验证失败
    return res.status(401).json({
      success: false,
      message: error.message || '认证失败，请重新登录'
    });
  }
}

module.exports = authenticate;

