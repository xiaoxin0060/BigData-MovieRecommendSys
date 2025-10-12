<template>
  <header class="app-header">
    <div class="container">
      <div class="header-content">
        <!-- Logo -->
        <router-link to="/" class="header-logo">
          <el-icon :size="28"><Film /></el-icon>
          <span class="logo-text">电影推荐</span>
        </router-link>
        
        <!-- 导航菜单 -->
        <nav class="header-nav">
          <router-link to="/" class="nav-link">首页</router-link>
          <router-link to="/movies" class="nav-link">电影</router-link>
          
          <template v-if="userStore.isLoggedIn">
            <router-link to="/recommendations" class="nav-link">推荐</router-link>
            <router-link to="/my-ratings" class="nav-link">我的评分</router-link>
          </template>
        </nav>
        
        <!-- 用户菜单 -->
        <div class="header-actions">
          <template v-if="userStore.isLoggedIn">
            <!-- 已登录 -->
            <el-dropdown @command="handleCommand">
              <div class="user-dropdown">
                <el-icon><User /></el-icon>
                <span class="user-name">{{ userStore.userInfo?.userName || '用户' }}</span>
                <el-icon class="ml-xs"><ArrowDown /></el-icon>
              </div>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="profile">
                    <el-icon><UserFilled /></el-icon>
                    <span class="ml-sm">个人中心</span>
                  </el-dropdown-item>
                  <el-dropdown-item divided command="logout">
                    <el-icon><SwitchButton /></el-icon>
                    <span class="ml-sm">退出登录</span>
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
          
          <template v-else>
            <!-- 未登录 -->
            <router-link to="/login">
              <el-button type="default" size="small">登录</el-button>
            </router-link>
            <router-link to="/register">
              <el-button type="primary" size="small" class="ml-sm">注册</el-button>
            </router-link>
          </template>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup>
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { ElMessage } from 'element-plus'

const router = useRouter()
const userStore = useUserStore()

// 处理下拉菜单命令
function handleCommand(command) {
  if (command === 'profile') {
    router.push('/profile')
  } else if (command === 'logout') {
    userStore.logout()
    ElMessage.success('已退出登录')
    router.push('/')
  }
}
</script>

<style scoped>
.app-header {
  position: sticky;
  top: 0;
  z-index: var(--z-index-sticky);
  background-color: var(--color-bg-secondary);
  border-bottom: 1px solid var(--color-border);
  backdrop-filter: blur(10px);
}

.header-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 64px;
  gap: var(--spacing-lg);
}

/* Logo */
.header-logo {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  color: var(--color-text-primary);
  font-size: var(--font-size-xl);
  font-weight: var(--font-weight-bold);
  text-decoration: none;
  transition: color var(--transition-fast);
}

.header-logo:hover {
  color: var(--color-accent-blue);
}

.logo-text {
  background: linear-gradient(135deg, var(--color-accent-blue) 0%, var(--color-accent-purple) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

/* 导航 */
.header-nav {
  display: flex;
  align-items: center;
  gap: var(--spacing-lg);
  flex: 1;
  margin-left: var(--spacing-xl);
}

.nav-link {
  color: var(--color-text-secondary);
  font-size: var(--font-size-base);
  font-weight: var(--font-weight-medium);
  text-decoration: none;
  transition: color var(--transition-fast);
  position: relative;
  padding: var(--spacing-xs) 0;
}

.nav-link:hover {
  color: var(--color-text-primary);
}

.nav-link.router-link-active {
  color: var(--color-accent-blue);
}

.nav-link.router-link-active::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 2px;
  background-color: var(--color-accent-blue);
  border-radius: var(--radius-full);
}

/* 用户菜单 */
.header-actions {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.user-dropdown {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius-md);
  cursor: pointer;
  color: var(--color-text-primary);
  transition: all var(--transition-fast);
}

.user-dropdown:hover {
  background-color: var(--color-bg-tertiary);
}

.user-name {
  font-size: var(--font-size-sm);
  font-weight: var(--font-weight-medium);
}

/* 响应式 */
@media (max-width: 768px) {
  .header-nav {
    display: none;
  }
  
  .user-name {
    display: none;
  }
}
</style>

