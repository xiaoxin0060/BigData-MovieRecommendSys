/**
 * 统一错误处理中间件（纯 API 模式）
 */
function errorHandler(err, req, res, next) {
  console.error('❌ 服务器错误:', err);

  // Prisma 唯一约束错误
  if (err.code === 'P2002') {
    return res.status(400).json({
      success: false,
      message: '数据已存在，违反唯一约束'
    });
  }

  // Prisma 记录不存在错误
  if (err.code === 'P2025') {
    return res.status(404).json({
      success: false,
      message: '记录不存在'
    });
  }

  // 默认错误
  res.status(err.status || 500).json({
    success: false,
    message: err.message || '服务器内部错误',
    // 开发环境返回堆栈信息，方便调试
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
}

module.exports = errorHandler;