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
