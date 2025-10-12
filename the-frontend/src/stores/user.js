/**
 * 用户状态管理
 * 负责：用户登录状态、Token 管理、用户信息
 */
import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useUserStore = defineStore('user', () => {
  // ===== 状态 =====
  
  // 从 localStorage 初始化（页面刷新不丢失）
  const token = ref(localStorage.getItem('token') || '')
  const userInfo = ref(JSON.parse(localStorage.getItem('userInfo') || 'null'))
  
  // ===== 计算属性 =====
  
  // 判断是否已登录
  const isLoggedIn = ref(!!token.value)
  
  // ===== 方法 =====
  
  /**
   * 设置 Token
   * @param {string} newToken - JWT Token
   */
  function setToken(newToken) {
    token.value = newToken
    isLoggedIn.value = !!newToken
    
    // 同步到 localStorage（持久化）
    if (newToken) {
      localStorage.setItem('token', newToken)
    } else {
      localStorage.removeItem('token')
    }
  }
  
  /**
   * 设置用户信息
   * @param {object} info - 用户信息对象
   */
  function setUserInfo(info) {
    userInfo.value = info
    
    // 同步到 localStorage（持久化）
    if (info) {
      localStorage.setItem('userInfo', JSON.stringify(info))
    } else {
      localStorage.removeItem('userInfo')
    }
  }
  
  /**
   * 登录（保存 Token 和用户信息）
   * @param {string} newToken - JWT Token
   * @param {object} info - 用户信息
   */
  function login(newToken, info) {
    setToken(newToken)
    setUserInfo(info)
  }
  
  /**
   * 登出（清除所有状态）
   */
  function logout() {
    setToken('')
    setUserInfo(null)
    
    // 可以在这里添加其他清理逻辑
    // 例如：清除其他 store 的数据
  }
  
  // ===== 返回（暴露给组件使用） =====
  return {
    // 状态
    token,
    userInfo,
    isLoggedIn,
    
    // 方法
    setToken,
    setUserInfo,
    login,
    logout
  }
})

