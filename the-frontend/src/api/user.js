/**
 * 用户相关 API
 */
import request from '@/utils/request'

/**
 * 用户注册
 * @param {object} data - 注册信息
 * @param {string} data.userAccount - 账号
 * @param {string} data.userPassword - 密码
 * @param {string} data.userName - 昵称（可选）
 * @param {number} data.gender - 性别（可选，0-女 1-男）
 * @returns {Promise}
 */
export function register(data) {
  return request({
    url: '/users/register',
    method: 'POST',
    data
  })
}

/**
 * 用户登录
 * @param {object} data - 登录信息
 * @param {string} data.userAccount - 账号
 * @param {string} data.userPassword - 密码
 * @returns {Promise}
 */
export function login(data) {
  return request({
    url: '/users/login',
    method: 'POST',
    data
  })
}

/**
 * 获取当前登录用户信息
 * @returns {Promise}
 */
export function getProfile() {
  return request({
    url: '/users/profile',
    method: 'GET'
  })
}

/**
 * 获取用户统计数据
 * @returns {Promise}
 */
export function getUserStats() {
  return request({
    url: '/users/stats',
    method: 'GET'
  })
}

