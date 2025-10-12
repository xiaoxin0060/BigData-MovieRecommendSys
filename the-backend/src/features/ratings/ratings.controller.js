const prisma = require('../../config/database');

/**
 * 用户给电影评分
 * 需要认证
 */
async function createRating(req, res, next) {
  try {
    const { movieId, rating } = req.body;
    const userId = req.userId;  // 从认证中间件获取

    // 参数验证
    if (!movieId || !rating) {
      return res.status(400).json({
        success: false,
        message: '电影ID和评分不能为空'
      });
    }

    const ratingValue = parseFloat(rating);
    if (ratingValue < 1.0 || ratingValue > 5.0) {
      return res.status(400).json({
        success: false,
        message: '评分必须在 1.0 到 5.0 之间'
      });
    }

    // 检查电影是否存在
    const movie = await prisma.movie.findUnique({
      where: { id: BigInt(movieId) }
    });

    if (!movie) {
      return res.status(404).json({
        success: false,
        message: '电影不存在'
      });
    }

    // 使用 upsert：如果已评分则更新，否则创建
    const userRating = await prisma.rating.upsert({
      where: {
        userId_movieId: {
          userId: BigInt(userId),
          movieId: BigInt(movieId)
        }
      },
      update: {
        rating: ratingValue,
        timestamp: BigInt(Date.now())
      },
      create: {
        userId: BigInt(userId),
        movieId: BigInt(movieId),
        rating: ratingValue,
        timestamp: BigInt(Date.now())
      }
    });

    // TODO: 更新电影的平均分和评分人数（可以用触发器或定时任务）
    // 这里简化处理，只返回评分结果

    res.json({
      success: true,
      message: '评分成功',
      data: {
        id: userRating.id.toString(),
        movieId: userRating.movieId.toString(),
        rating: parseFloat(userRating.rating)
      }
    });

  } catch (error) {
    next(error);
  }
}

/**
 * 获取当前用户的所有评分
 * 需要认证
 */
async function getMyRatings(req, res, next) {
  try {
    const userId = req.userId;
    const { page = 1, pageSize = 20 } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(pageSize);
    const take = parseInt(pageSize);

    const [ratings, total] = await Promise.all([
      prisma.rating.findMany({
        where: { userId: BigInt(userId) },
        include: {
          movie: {
            select: {
              id: true,
              title: true,
              genres: true,
              year: true,
              posterUrl: true
            }
          }
        },
        orderBy: { created_at: 'desc' },
        skip,
        take
      }),
      prisma.rating.count({ where: { userId: BigInt(userId) } })
    ]);

    const ratingsData = ratings.map(r => ({
      id: r.id.toString(),
      rating: parseFloat(r.rating),
      createdAt: r.created_at,
      movie: {
        ...r.movie,
        id: r.movie.id.toString()
      }
    }));

    res.json({
      success: true,
      data: {
        ratings: ratingsData,
        pagination: {
          page: parseInt(page),
          pageSize: parseInt(pageSize),
          total,
          totalPages: Math.ceil(total / parseInt(pageSize))
        }
      }
    });

  } catch (error) {
    next(error);
  }
}

/**
 * 获取某部电影的所有评分（公开接口）
 */
async function getMovieRatings(req, res, next) {
  try {
    const { movieId } = req.params;
    const { page = 1, pageSize = 20 } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(pageSize);
    const take = parseInt(pageSize);

    const [ratings, total] = await Promise.all([
      prisma.rating.findMany({
        where: { movieId: BigInt(movieId) },
        include: {
          user: {
            select: {
              id: true,
              userName: true
            }
          }
        },
        orderBy: { created_at: 'desc' },
        skip,
        take
      }),
      prisma.rating.count({ where: { movieId: BigInt(movieId) } })
    ]);

    const ratingsData = ratings.map(r => ({
      id: r.id.toString(),
      rating: parseFloat(r.rating),
      createdAt: r.created_at,
      user: {
        id: r.user.id.toString(),
        userName: r.user.userName || '匿名用户'
      }
    }));

    res.json({
      success: true,
      data: {
        ratings: ratingsData,
        pagination: {
          page: parseInt(page),
          pageSize: parseInt(pageSize),
          total,
          totalPages: Math.ceil(total / parseInt(pageSize))
        }
      }
    });

  } catch (error) {
    next(error);
  }
}

module.exports = {
  createRating,
  getMyRatings,
  getMovieRatings
};

