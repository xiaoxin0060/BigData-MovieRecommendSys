/**
 * Axios 封装 - HTTP 请求工具
 * 统一处理：请求拦截、响应拦截、错误处理
 */
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'
import router from '@/router'

// ===== 创建 axios 实例 =====
const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api',  // API 基础地址
  timeout: 10000,  // 请求超时时间（10秒）
  headers: {
    'Content-Type': 'application/json'
  }
})

// ===== 请求拦截器 =====
request.interceptors.request.use(
  (config) => {
    // 自动添加 Token
    const userStore = useUserStore()
    if (userStore.token) {
      config.headers.Authorization = `Bearer ${userStore.token}`
    }
    
    return config
  },
  (error) => {
    console.error('请求错误:', error)
    return Promise.reject(error)
  }
)

// ===== 响应拦截器 =====
request.interceptors.response.use(
  (response) => {
    // 直接返回响应数据
    return response.data
  },
  (error) => {
    // 统一错误处理
    let message = '网络错误，请稍后重试'
    
    if (error.response) {
      const { status, data } = error.response
      
      switch (status) {
        case 400:
          message = data.message || '请求参数错误'
          break
        case 401:
          message = data.message || '未授权，请重新登录'
          // 清除登录状态
          const userStore = useUserStore()
          userStore.logout()
          // 跳转到登录页
          router.push('/login')
          break
        case 403:
          message = '没有权限访问'
          break
        case 404:
          message = data.message || '请求的资源不存在'
          break
        case 500:
          message = '服务器内部错误'
          break
        default:
          message = data.message || `请求失败 (${status})`
      }
    } else if (error.request) {
      // 请求已发出，但没有收到响应
      message = '网络连接失败，请检查网络'
    } else {
      // 其他错误
      message = error.message || '请求失败'
    }
    
    // 显示错误提示
    ElMessage.error(message)
    
    return Promise.reject(error)
  }
)

export default request

