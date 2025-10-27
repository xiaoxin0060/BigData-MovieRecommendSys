<template>
  <div class="home-page">
    <!-- Hero Section -->
    <section class="hero-section">
      <div class="container">
        <div class="hero-content">
          <h1 class="hero-title">
            <span class="gradient-text">发现你的下一部</span>
            <br />
            <span class="gradient-text">最爱电影</span>
          </h1>
          <p class="hero-subtitle">
            基于 Spark 机器学习算法的智能电影推荐系统
          </p>
          <div class="hero-actions">
            <el-button type="primary" size="large" @click="router.push('/movies')">
              <el-icon class="mr-xs"><Film /></el-icon>
              浏览电影
            </el-button>
            <el-button v-if="!userStore.isLoggedIn" size="large" @click="router.push('/register')">
              <el-icon class="mr-xs"><UserFilled /></el-icon>
              立即注册
            </el-button>
            <el-button v-else size="large" @click="router.push('/recommendations')">
              <el-icon class="mr-xs"><MagicStick /></el-icon>
              查看推荐
            </el-button>
          </div>
        </div>
      </div>
    </section>
    
    <!-- Features Section -->
    <section class="features-section">
      <div class="container">
        <h2 class="section-title text-center mb-xxl">✨ 系统特色</h2>
        
        <div class="features-grid">
          <div class="feature-card card hover-lift">
            <div class="feature-icon">
              <el-icon :size="48" color="var(--color-accent-blue)">
                <MagicStick />
              </el-icon>
            </div>
            <h3 class="feature-title">智能推荐</h3>
            <p class="feature-desc text-secondary">
              基于 Apache Spark ALS 协同过滤算法，为你推荐最匹配的电影
            </p>
          </div>
          
          <div class="feature-card card hover-lift">
            <div class="feature-icon">
              <el-icon :size="48" color="var(--movie-gold)">
                <StarFilled />
              </el-icon>
            </div>
            <h3 class="feature-title">评分系统</h3>
            <p class="feature-desc text-secondary">
              为看过的电影打分，帮助算法更好地了解你的喜好
            </p>
          </div>
          
          <div class="feature-card card hover-lift">
            <div class="feature-icon">
              <el-icon :size="48" color="var(--color-accent-green)">
                <DataAnalysis />
              </el-icon>
            </div>
            <h3 class="feature-title">数据分析</h3>
            <p class="feature-desc text-secondary">
              查看个人观影历史，分析你的电影品味偏好
            </p>
          </div>
        </div>
      </div>
    </section>
    
    <!-- Tech Stack Section -->
    <section class="tech-section">
      <div class="container">
        <h2 class="section-title text-center mb-xl">🚀 技术栈</h2>
        <div class="tech-stack">
          <div class="tech-item">
            <div class="tech-badge badge">Vue 3</div>
            <div class="tech-badge badge">Element Plus</div>
            <div class="tech-badge badge">Pinia</div>
          </div>
          <div class="tech-divider">+</div>
          <div class="tech-item">
            <div class="tech-badge badge">Node.js</div>
            <div class="tech-badge badge">Express</div>
            <div class="tech-badge badge">Prisma</div>
          </div>
          <div class="tech-divider">+</div>
          <div class="tech-item">
            <div class="tech-badge badge">Apache Spark</div>
            <div class="tech-badge badge">MySQL</div>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
</script>

<style scoped>
.home-page {
  min-height: 100vh;
}

/* Hero Section */
.hero-section {
  padding: var(--spacing-xxl) 0;
  background: linear-gradient(
    135deg,
    var(--color-bg-primary) 0%,
    var(--color-bg-secondary) 50%,
    var(--color-bg-primary) 100%
  );
  position: relative;
  overflow: hidden;
}

.hero-section::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: radial-gradient(
    circle at 20% 50%,
    rgba(96, 165, 250, 0.1) 0%,
    transparent 50%
  );
  pointer-events: none;
}

.hero-content {
  position: relative;
  z-index: 1;
  text-align: center;
  padding: var(--spacing-xxl) 0;
}

.hero-title {
  font-size: 4rem;
  font-weight: var(--font-weight-bold);
  line-height: var(--line-height-tight);
  margin-bottom: var(--spacing-lg);
}

.gradient-text {
  background: linear-gradient(
    135deg,
    var(--color-accent-blue) 0%,
    var(--color-accent-purple) 50%,
    var(--color-accent-pink) 100%
  );
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.hero-subtitle {
  font-size: var(--font-size-xl);
  color: var(--color-text-secondary);
  margin-bottom: var(--spacing-xxl);
  max-width: 600px;
  margin-left: auto;
  margin-right: auto;
}

.hero-actions {
  display: flex;
  gap: var(--spacing-md);
  justify-content: center;
}

/* Features Section */
.features-section {
  padding: var(--spacing-xxl) 0;
}

.section-title {
  font-size: var(--font-size-3xl);
  font-weight: var(--font-weight-bold);
  color: var(--color-text-primary);
}

.features-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: var(--spacing-xl);
}

.feature-card {
  text-align: center;
  cursor: default;
}

.feature-icon {
  margin-bottom: var(--spacing-lg);
}

.feature-title {
  font-size: var(--font-size-xl);
  font-weight: var(--font-weight-semibold);
  color: var(--color-text-primary);
  margin-bottom: var(--spacing-sm);
}

.feature-desc {
  line-height: var(--line-height-relaxed);
}

/* Tech Stack Section */
.tech-section {
  padding: var(--spacing-xxl) 0;
  background-color: var(--color-bg-secondary);
}

.tech-stack {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--spacing-xl);
  flex-wrap: wrap;
}

.tech-item {
  display: flex;
  gap: var(--spacing-sm);
  flex-wrap: wrap;
  justify-content: center;
}

.tech-badge {
  background-color: var(--color-bg-tertiary);
  font-size: var(--font-size-sm);
}

.tech-divider {
  font-size: var(--font-size-2xl);
  color: var(--color-text-tertiary);
  font-weight: var(--font-weight-bold);
}

/* 响应式 */
@media (max-width: 768px) {
  .hero-title {
    font-size: 2.5rem;
  }
  
  .hero-subtitle {
    font-size: var(--font-size-base);
  }
  
  .hero-actions {
    flex-direction: column;
    max-width: 300px;
    margin: 0 auto;
  }
  
  .features-grid {
    grid-template-columns: 1fr;
  }
  
  .tech-divider {
    display: none;
  }
}
</style>
