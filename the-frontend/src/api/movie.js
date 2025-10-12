/**
 * 电影相关 API
 */
import request from '@/utils/request'

/**
 * 获取电影列表
 * @param {object} params - 查询参数
 * @param {number} params.page - 页码
 * @param {number} params.pageSize - 每页数量
 * @param {string} params.genre - 类型（可选）
 * @param {number} params.year - 年份（可选）
 * @param {string} params.sort - 排序（avgRating/year/title）
 * @returns {Promise}
 */
export function getMovies(params) {
  return request({
    url: '/movies',
    method: 'GET',
    params
  })
}

/**
 * 获取电影详情
 * @param {string} id - 电影ID
 * @returns {Promise}
 */
export function getMovieById(id) {
  return request({
    url: `/movies/${id}`,
    method: 'GET'
  })
}

