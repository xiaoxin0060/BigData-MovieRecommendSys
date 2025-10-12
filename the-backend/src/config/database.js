const { PrismaClient } = require('../generated/prisma');

const prisma = new PrismaClient({
  log: ['query', 'error', 'warn'],  // 开发环境打印 SQL 日志
});

module.exports = prisma;