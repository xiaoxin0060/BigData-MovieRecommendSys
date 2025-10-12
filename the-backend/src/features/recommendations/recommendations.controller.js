const prisma = require('../../config/database');

/**
 * 获取当前用户的个性化推荐（核心功能）
 * 需要认证
 * 数据由 Spark 离线计算生成
 */
async function getMyRecommendations(req, res, next) {
  try {
    const userId = req.userId;
    const { limit = 20, algorithm = 'ALS' } = req.query;

    // 从推荐表获取 Spark 计算的推荐结果
    const recommendations = await prisma.recommendation.findMany({
      where: {
        userId: BigInt(userId),
        algorithm: algorithm
      },
      include: {
        movie: {
          select: {
            id: true,
            title: true,
            genres: true,
            year: true,
            posterUrl: true,
            avgRating: true,
            description: true
          }
        }
      },
      orderBy: [
        { rank: 'asc' },       // 先按排名
        { score: 'desc' }      // 再按分数
      ],
      take: parseInt(limit)
    });

    // 如果没有推荐结果，返回热门电影作为备选
    if (recommendations.length === 0) {
      const hotMovies = await prisma.movie.findMany({
        orderBy: { avgRating: 'desc' },
        take: parseInt(limit),
        select: {
          id: true,
          title: true,
          genres: true,
          year: true,
          posterUrl: true,
          avgRating: true,
          description: true
        }
      });

      return res.json({
        success: true,
        message: '暂无个性化推荐，为您推荐热门电影',
        data: {
          recommendations: hotMovies.map(movie => ({
            movie: {
              ...movie,
              id: movie.id.toString(),
              avgRating: movie.avgRating ? parseFloat(movie.avgRating) : 0
            },
            score: null,
            rank: null,
            reason: '热门推荐'
          })),
          isPersonalized: false
        }
      });
    }

    // 返回个性化推荐
    const result = recommendations.map(rec => ({
      movie: {
        ...rec.movie,
        id: rec.movie.id.toString(),
        avgRating: rec.movie.avgRating ? parseFloat(rec.movie.avgRating) : 0
      },
      score: rec.score ? parseFloat(rec.score) : 0,
      rank: rec.rank,
      reason: `基于您的观影偏好推荐（算法：${rec.algorithm}）`,
      updatedAt: rec.created_at
    }));

    res.json({
      success: true,
      data: {
        recommendations: result,
        isPersonalized: true,
        algorithm: algorithm
      }
    });

  } catch (error) {
    next(error);
  }
}

/**
 * 获取相似电影推荐（基于电影）
 * 公开接口
 */
async function getSimilarMovies(req, res, next) {
  try {
    const { movieId } = req.params;
    const { limit = 10 } = req.query;

    // 获取当前电影信息
    const currentMovie = await prisma.movie.findUnique({
      where: { id: BigInt(movieId) }
    });

    if (!currentMovie) {
      return res.status(404).json({
        success: false,
        message: '电影不存在'
      });
    }

    // 简化实现：找相同类型的高分电影
    // 实际项目中可以用 Spark 计算电影相似度
    const genres = currentMovie.genres || '';
    const genreList = genres.split('|').filter(g => g);

    // 如果有类型，按类型推荐
    let similarMovies = [];
    if (genreList.length > 0) {
      similarMovies = await prisma.movie.findMany({
        where: {
          id: { not: BigInt(movieId) },  // 排除当前电影
          genres: { contains: genreList[0] }  // 匹配第一个类型
        },
        orderBy: { avgRating: 'desc' },
        take: parseInt(limit),
        select: {
          id: true,
          title: true,
          genres: true,
          year: true,
          posterUrl: true,
          avgRating: true,
          description: true
        }
      });
    }

    // 如果没找到，返回高分电影
    if (similarMovies.length === 0) {
      similarMovies = await prisma.movie.findMany({
        where: { id: { not: BigInt(movieId) } },
        orderBy: { avgRating: 'desc' },
        take: parseInt(limit),
        select: {
          id: true,
          title: true,
          genres: true,
          year: true,
          posterUrl: true,
          avgRating: true,
          description: true
        }
      });
    }

    const result = similarMovies.map(movie => ({
      ...movie,
      id: movie.id.toString(),
      avgRating: movie.avgRating ? parseFloat(movie.avgRating) : 0
    }));

    res.json({
      success: true,
      data: {
        baseMovie: {
          id: currentMovie.id.toString(),
          title: currentMovie.title
        },
        similarMovies: result
      }
    });

  } catch (error) {
    next(error);
  }
}

module.exports = {
  getMyRecommendations,
  getSimilarMovies
};

