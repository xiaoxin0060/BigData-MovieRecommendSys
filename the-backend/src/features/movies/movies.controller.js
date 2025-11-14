const prisma = require('../../config/database');

/**
 * 获取电影列表（分页 + 筛选）
 */
async function getMovies(req, res, next) {
  try {
    const {
      page = 1,
      pageSize = 20,
      keyword,      // 关键词搜索
      sort = 'avgRating'  // 排序：avgRating | year | title
    } = req.query;

    // 构建查询条件
    const where = {};
    
    if (keyword) {
      where.title = { contains: keyword };  // 标题模糊匹配
    }

    // 排序配置
    const orderBy = {};
    if (sort === 'avgRating') {
      orderBy.avgRating = 'desc';  // 评分降序
    } else if (sort === 'year') {
      orderBy.year = 'desc';
    } else {
      orderBy.title = 'asc';
    }

    // 分页查询 
    const skip = (parseInt(page) - 1) * parseInt(pageSize);
    const take = parseInt(pageSize);

    // 并行查询：电影列表 + 总数
    const [movies, total] = await Promise.all([
      prisma.movie.findMany({
        where,
        orderBy,
        skip,
        take,
        select: {
          id: true,
          title: true,
          genres: true,
          year: true,
          posterUrl: true,
          avgRating: true,
          ratingCount: true
        }
      }),
      prisma.movie.count({ where })
    ]);

    // BigInt 转字符串
    const moviesData = movies.map(movie => ({
      ...movie,
      id: movie.id.toString(),
      avgRating: movie.avgRating ? parseFloat(movie.avgRating) : 0
    }));

    res.json({
      success: true,
      data: {
        movies: moviesData,
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
 * 获取电影详情
 */
async function getMovieById(req, res, next) {
  try {
    const { id } = req.params;

    // 检查 id 是否有效
    if (!id || isNaN(id)) {
      return res.status(400).json({
        success: false,
        message: '无效的电影ID'
      });
    }

    const movie = await prisma.movie.findUnique({
      where: { id: BigInt(id) }
    });

    if (!movie) {
      return res.status(404).json({
        success: false,
        message: '电影不存在'
      });
    }

    // 转换所有 BigInt 字段为字符串
    const movieData = {
      id: movie.id.toString(),
      title: movie.title,
      originalTitle: movie.originalTitle,
      genres: movie.genres,
      year: movie.year,
      director: movie.director,
      actors: movie.actors,
      description: movie.description,
      posterUrl: movie.posterUrl,
      mlMovieId: movie.mlMovieId ? movie.mlMovieId.toString() : null,
      imdbId: movie.imdbId,
      tmdbId: movie.tmdbId,
      source: movie.source,
      avgRating: movie.avgRating ? parseFloat(movie.avgRating) : 0,
      ratingCount: movie.ratingCount,
      created_at: movie.created_at,
      updated_at: movie.updated_at
    };

    res.json({
      success: true,
      data: movieData
    });

  } catch (error) {
    console.error('获取电影详情错误:', error);
    next(error);
  }
}

module.exports = {
  getMovies,
  getMovieById
};

