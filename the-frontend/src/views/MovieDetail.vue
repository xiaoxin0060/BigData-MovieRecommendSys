<template>
  <div class="movie-detail-page">
    <div class="container">
      <div v-if="loading" class="flex-center" style="min-height: 400px">
        <el-icon class="is-loading" :size="40"><Loading /></el-icon>
      </div>

      <div v-else-if="movie" class="movie-content">
        <div class="movie-main">
          <img
            :src="movie.posterUrl || '/1.jpg'"
            :alt="movie.title"
            class="movie-poster rounded-lg"
          />
          
          <div class="movie-info">
            <h1 class="text-4xl font-bold mb-md">{{ movie.title }}</h1>
            <p v-if="movie.originalTitle" class="text-lg text-secondary mb-lg">{{ movie.originalTitle }}</p>
            
            <div class="movie-meta card p-md mb-lg">
              <div class="meta-item">
                <span class="text-sm text-tertiary">类型</span>
                <div class="mt-xs" style="gap: var(--spacing-xs); display: flex; flex-wrap: wrap">
                  <el-tag v-for="genre in movie.genres?.split('|')" :key="genre" size="small">
                    {{ genre }}
                  </el-tag>
                </div>
              </div>
              
              <div class="meta-item">
                <span class="text-sm text-tertiary">年份</span>
                <p class="text-base font-medium mt-xs">{{ movie.year }}</p>
              </div>
              
              <div class="meta-item" v-if="movie.director">
                <span class="text-sm text-tertiary">导演</span>
                <p class="text-base font-medium mt-xs">{{ movie.director }}</p>
              </div>
              
              <div class="meta-item">
                <span class="text-sm text-tertiary">评分</span>
                <div class="flex items-center mt-xs" style="gap: var(--spacing-xs)">
                  <span class="text-2xl font-bold text-accent">
                    {{ movie.avgRating ? Number(movie.avgRating).toFixed(1) : '暂无' }}
                  </span>
                  <span class="text-sm text-secondary" v-if="movie.ratingCount > 0">
                    ({{ movie.ratingCount }} 人评分)
                  </span>
                  <span class="text-sm text-secondary" v-else>
                    (暂无评分)
                  </span>
                </div>
              </div>
            </div>

            <div v-if="movie.description" class="card p-lg mb-lg">
              <h3 class="text-lg font-semibold mb-md">电影简介</h3>
              <p class="text-base text-secondary" style="line-height: 1.8">{{ movie.description }}</p>
            </div>

            <div class="card p-lg">
              <h3 class="text-lg font-semibold mb-md">我的评分</h3>
              <div class="flex items-center" style="gap: var(--spacing-lg)">
                <el-rate 
                  v-model="myRating" 
                  :max="5"
                  allow-half
                  show-score
                  score-template="{value} 分"
                />
                <el-button 
                  type="primary" 
                  :loading="submitting"
                  @click="submitRating"
                >
                  {{ submitting ? '提交中...' : '提交评分' }}
                </el-button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div v-else class="flex-center" style="min-height: 400px">
        <el-empty description="电影不存在" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getMovieById } from '@/api/movie'
import { addRating, getMyRatingForMovie } from '@/api/rating'
import { ElMessage } from 'element-plus'
import { Loading } from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'

const route = useRoute()
const userStore = useUserStore()
const movie = ref(null)
const loading = ref(false)
const myRating = ref(0)
const submitting = ref(false)

async function fetchMovie() {
  loading.value = true
  try {
    const res = await getMovieById(route.params.id)
    movie.value = res.data
    
    // 如果已登录，获取用户对该电影的评分
    if (userStore.isLoggedIn) {
      try {
        const ratingRes = await getMyRatingForMovie(route.params.id)
        if (ratingRes.data.rated) {
          myRating.value = ratingRes.data.rating
        }
      } catch (error) {
        // 未评分或获取失败，保持 0
        console.log('未评分或获取评分失败')
      }
    }
  } catch (error) {
    console.error('获取电影详情失败:', error)
  } finally {
    loading.value = false
  }
}

async function submitRating() {
  if (myRating.value === 0) {
    ElMessage.warning('请先选择评分')
    return
  }
  
  submitting.value = true
  try {
    await addRating({
      movieId: route.params.id,
      rating: myRating.value
    })
    ElMessage.success('评分成功！')
    fetchMovie()
  } catch (error) {
    console.error('评分失败:', error)
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  fetchMovie()
})
</script>

<style scoped>
.movie-detail-page {
  min-height: 100vh;
  padding: var(--spacing-xl) 0;
}

.movie-main {
  display: flex;
  gap: var(--spacing-xxl);
  margin-top: var(--spacing-lg);
}

.movie-poster {
  flex: 0 0 300px;
  height: 450px;
  object-fit: cover;
  background: var(--color-bg-tertiary);
  box-shadow: var(--color-shadow-lg);
}

.movie-info {
  flex: 1;
}

.movie-meta {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: var(--spacing-lg);
}

.meta-item {
  /* 使用工具类控制间距 */
}

@media (max-width: 768px) {
  .movie-main {
    flex-direction: column;
  }
  
  .movie-poster {
    flex: none;
    width: 100%;
  }
}
</style>
