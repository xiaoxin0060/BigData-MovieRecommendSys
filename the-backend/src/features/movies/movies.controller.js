const prisma = require('../../config/database');

/**
 * 获取电影列表（分页 + 筛选）
 */
async function getMovies(req, res, next) {
  try {
    const {
      page = 1,
      pageSize = 20,
      genre,        // 类型筛选
      year,         // 年份筛选
      sort = 'avgRating'  // 排序：avgRating | year | title
    } = req.query;

    // 构建查询条件
    const where = {};
    
    if (genre) {
      where.genres = { contains: genre };  // 模糊匹配类型
    }
    
    if (year) {
      where.year = parseInt(year);
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

    const movie = await prisma.movie.findUnique({
      where: { id: BigInt(id) }
    });

    if (!movie) {
      return res.status(404).json({
        success: false,
        message: '电影不存在'
      });
    }

    res.json({
      success: true,
      data: {
        ...movie,
        id: movie.id.toString(),
        avgRating: movie.avgRating ? parseFloat(movie.avgRating) : 0
      }
    });

  } catch (error) {
    next(error);
  }
}

module.exports = {
  getMovies,
  getMovieById
};

