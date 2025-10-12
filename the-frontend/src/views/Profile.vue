<template>
  <div class="profile-page">
    <div class="container">
      <h1 class="text-3xl font-bold mb-lg">个人中心</h1>
      
      <!-- 
        TODO: 这里添加个人中心内容
        
        建议实现：
        1. 用户头像 + 基本信息卡片
        2. 统计数据（评分数量、推荐数量等）
        3. 个人信息编辑表单
        4. 修改密码功能
        
        布局提示：
        - 使用 card 类创建卡片
        - 使用 el-avatar 头像组件
        - 使用 el-form 表单组件
        - 使用 el-statistic 统计组件
      -->
      
      <div class="placeholder">
        <el-empty description="待开发：个人中心页面" />
        <p class="text-sm text-secondary mt-md">
          当前用户: {{ userStore.userInfo?.userName || '未登录' }}
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { useUserStore } from '@/stores/user'

const userStore = useUserStore()

// TODO: 导入需要的 API 和工具
// import { ref } from 'vue'
// import { getProfile } from '@/api/user'

// TODO: 定义响应式数据
// const userStats = ref({
//   ratingsCount: 0,
//   recommendationsCount: 0
// })

// TODO: 加载用户统计数据
// async function loadUserStats() {
//   // 调用统计 API
// }

// TODO: 编辑个人信息
// async function updateProfile() {
//   // 调用更新 API
// }
</script>

<style scoped>
.profile-page {
  min-height: 100vh;
  padding: var(--spacing-xl) 0;
}

.placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 400px;
}

/* 
  TODO: 添加个人中心样式
  
  示例：
  .profile-header {
    display: flex;
    align-items: center;
    gap: var(--spacing-lg);
    padding: var(--spacing-xl);
    background: var(--color-bg-secondary);
    border-radius: var(--radius-lg);
  }
  
  .profile-stats {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--spacing-lg);
    margin-top: var(--spacing-lg);
  }
*/
</style>

