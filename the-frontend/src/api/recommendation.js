/**
 * 推荐相关 API
 */
import request from '@/utils/request'

/**
 * 获取我的个性化推荐
 * @param {object} params - 查询参数
 * @param {number} params.page - 页码
 * @param {number} params.pageSize - 每页数量
 * @returns {Promise}
 */
export function getMyRecommendations(params) {
  return request({
    url: '/recommendations/for-me',
    method: 'GET',
    params
  })
}

