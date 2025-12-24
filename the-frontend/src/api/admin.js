// 管理后台监控相关 API
import request from '@/utils/request'

// 仪表盘概览数据
export function getMetricsOverview() {
  return request({
    url: '/admin/metrics/overview',
    method: 'GET'
  })
}

// 评分时间序列（目前主要用于最近24小时每小时评分数）
export function getRatingsTimeseries(params) {
  return request({
    url: '/admin/metrics/timeseries/ratings',
    method: 'GET',
    params
  })
}

// Spark / Streaming 作业状态
export function getJobMetrics() {
  return request({
    url: '/admin/metrics/jobs',
    method: 'GET'
  })
}

// 活跃用户时间序列（按小时）
export function getActiveUsersTimeseries(params) {
  return request({
    url: '/admin/metrics/timeseries/active-users',
    method: 'GET',
    params
  })
}

// 评分分布（默认最近 24 小时）
export function getRatingsDistribution(params) {
  return request({
    url: '/admin/metrics/distribution/ratings',
    method: 'GET',
    params
  })
}

// Top movies（默认按 ratingCount）
export function getTopMovies(params) {
  return request({
    url: '/admin/metrics/top/movies',
    method: 'GET',
    params
  })
}

// Top users（默认最近 24 小时，按评分数）
export function getTopUsers(params) {
  return request({
    url: '/admin/metrics/top/users',
    method: 'GET',
    params
  })
}
