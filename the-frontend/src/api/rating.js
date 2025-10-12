/**
 * 评分相关 API
 */
import request from '@/utils/request'

/**
 * 给电影评分
 * @param {object} data - 评分信息
 * @param {string} data.movieId - 电影ID
 * @param {number} data.rating - 评分（1-5）
 * @returns {Promise}
 */
export function addRating(data) {
  return request({
    url: '/ratings',
    method: 'POST',
    data
  })
}

/**
 * 获取我的所有评分
 * @param {object} params - 查询参数
 * @param {number} params.page - 页码
 * @param {number} params.pageSize - 每页数量
 * @returns {Promise}
 */
export function getMyRatings(params) {
  return request({
    url: '/ratings/my',
    method: 'GET',
    params
  })
}

