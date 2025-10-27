<template>
  <div class="profile-page">
    <div class="container">
      <h1 class="text-3xl font-bold mb-lg">个人中心</h1>

      <div class="profile-grid">
        <div class="card p-xl">
          <div class="flex-center flex-col">
            <el-avatar :size="100" class="mb-lg">
              <el-icon :size="50"><User /></el-icon>
            </el-avatar>
            
            <h2 class="text-2xl font-bold mb-xs">{{ userStore.userInfo?.userName || '用户' }}</h2>
            <p class="text-sm text-secondary mb-lg">{{ userStore.userInfo?.userAccount }}</p>
            
            <div class="flex" style="gap: var(--spacing-md)">
              <el-tag v-if="userStore.userInfo?.gender === 1" type="info">男</el-tag>
              <el-tag v-else-if="userStore.userInfo?.gender === 0" type="info">女</el-tag>
              <el-tag type="success">活跃用户</el-tag>
            </div>
          </div>
        </div>

        <div class="card p-lg">
          <h3 class="text-xl font-semibold mb-lg">数据统计</h3>
          
          <div class="stats-grid">
            <div class="stat-item">
              <el-icon :size="32" color="var(--color-accent-blue)" class="mb-sm">
                <StarFilled />
              </el-icon>
              <p class="text-3xl font-bold text-primary mb-xs">{{ stats.ratingsCount }}</p>
              <p class="text-sm text-secondary">我的评分</p>
            </div>
            
            <div class="stat-item">
              <el-icon :size="32" color="var(--movie-primary)" class="mb-sm">
                <Film />
              </el-icon>
              <p class="text-3xl font-bold text-primary mb-xs">{{ stats.recommendationsCount }}</p>
              <p class="text-sm text-secondary">推荐电影</p>
            </div>
            
            <div class="stat-item">
              <el-icon :size="32" color="var(--movie-gold)" class="mb-sm">
                <TrophyBase />
              </el-icon>
              <p class="text-3xl font-bold text-primary mb-xs">{{ stats.avgRating }}</p>
              <p class="text-sm text-secondary">平均评分</p>
            </div>
          </div>
        </div>

        <div class="card p-lg">
          <h3 class="text-xl font-semibold mb-lg">快速入口</h3>
          
          <div class="quick-links">
            <el-button 
              class="w-full" 
              size="large"
              @click="router.push('/my-ratings')"
            >
              <el-icon class="mr-sm"><Star /></el-icon>
              我的评分
            </el-button>
            
            <el-button 
              class="w-full" 
              size="large"
              @click="router.push('/recommendations')"
            >
              <el-icon class="mr-sm"><MagicStick /></el-icon>
              个性化推荐
            </el-button>
            
            <el-button 
              class="w-full" 
              size="large"
              @click="router.push('/movies')"
            >
              <el-icon class="mr-sm"><Film /></el-icon>
              浏览电影
            </el-button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { getUserStats } from '@/api/user'
import { User, StarFilled, Film, TrophyBase, Star, MagicStick } from '@element-plus/icons-vue'

const router = useRouter()
const userStore = useUserStore()

const stats = ref({
  ratingsCount: 0,
  recommendationsCount: 0,
  avgRating: '0.0'
})

async function loadStats() {
  try {
    const res = await getUserStats()
    stats.value = res.data
  } catch (error) {
    console.error('获取统计数据失败:', error)
  }
}

onMounted(() => {
  loadStats()
})
</script>

<style scoped>
.profile-page {
  min-height: 100vh;
  padding: var(--spacing-xl) 0;
}

.profile-grid {
  display: grid;
  grid-template-columns: 300px 1fr;
  gap: var(--spacing-lg);
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--spacing-lg);
}

.stat-item {
  text-align: center;
  padding: var(--spacing-lg);
  background: var(--color-bg-tertiary);
  border-radius: var(--radius-md);
  transition: all var(--transition-base);
}

.stat-item:hover {
  background: var(--color-row-hover);
  transform: translateY(-2px);
}

.quick-links {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
}

@media (max-width: 768px) {
  .profile-grid {
    grid-template-columns: 1fr;
  }
  
  .stats-grid {
    grid-template-columns: 1fr;
  }
}
</style>
