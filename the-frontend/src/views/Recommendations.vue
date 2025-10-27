<template>
  <div class="recommendations-page">
    <div class="container">
      <h1 class="text-3xl font-bold mb-lg">为我推荐</h1>
      
      <div class="card p-lg mb-xl">
        <div class="flex items-center justify-between">
          <div class="flex items-center" style="gap: var(--spacing-sm)">
            <el-icon :size="20" color="var(--color-accent-blue)"><MagicStick /></el-icon>
            <span class="text-base text-secondary">基于 Spark ALS 算法的个性化推荐</span>
          </div>
          <el-tag type="info" size="small">算法: ALS</el-tag>
        </div>
      </div>

      <div v-if="loading" class="flex-center flex-col" style="min-height: 400px">
        <el-icon class="is-loading" :size="40"><Loading /></el-icon>
        <p class="mt-md text-secondary">加载中...</p>
      </div>

      <div v-else-if="recommendations.length > 0" class="movies-grid">
        <el-card 
          v-for="rec in recommendations"
          :key="rec.movie.id"
          class="movie-card cursor-pointer transition hover-lift"
          shadow="hover"
          @click="goDetail(rec.movie.id)"
        >
          <template #header>
            <span class="text-lg font-semibold text-ellipsis">{{ rec.movie.title }}</span>
          </template>
          
          <img
            :src="rec.movie.posterUrl || '/1.jpg'"
            :alt="rec.movie.title"
            class="movie-poster w-full rounded-md"
          />
          
          <div class="mt-md">
            <p class="text-sm text-secondary mb-xs">
              <span class="text-tertiary">类型：</span>{{ rec.movie.genres }}
            </p>
            <p class="text-sm text-secondary mb-xs">
              <span class="text-tertiary">年份：</span>{{ rec.movie.year }}
            </p>
            <p class="text-sm text-primary font-medium">
              <span class="text-tertiary">评分：</span>
              <span class="text-accent">{{ rec.movie.avgRating || 0 }}</span>
            </p>
          </div>
        </el-card>
      </div>

      <div v-else class="flex-center" style="min-height: 400px">
        <el-empty description="暂无推荐数据">
          <template #description>
            <p class="text-sm text-secondary">多给电影评分，系统会为你生成个性化推荐</p>
          </template>
        </el-empty>
      </div>

      <el-pagination
        v-if="total > 0"
        :current-page="queryParams.page"
        :page-size="queryParams.pageSize"
        :total="total" 
        background 
        layout="prev, pager, next, total" 
        @current-change="handlePageChange"
        class="mt-xl"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { getMyRecommendations } from '@/api/recommendation'
import { Loading, MagicStick } from '@element-plus/icons-vue'

const router = useRouter()
const recommendations = ref([])
const loading = ref(false)
const total = ref(0)

const queryParams = reactive({
  page: 1,
  pageSize: 8
})

async function fetchRecommendations() {
  loading.value = true
  try {
    const res = await getMyRecommendations(queryParams)
    recommendations.value = res.data.recommendations
    total.value = res.data.pagination.total
  } catch (error) {
    console.error('获取推荐失败:', error)
  } finally {
    loading.value = false
  }
}

function handlePageChange(page) {
  queryParams.page = page
  fetchRecommendations()
}

function goDetail(id) {
  router.push(`/movies/${id}`)
}

onMounted(() => {
  fetchRecommendations()
})
</script>

<style scoped>
.recommendations-page {
  min-height: 100vh;
  padding: var(--spacing-xl) 0;
  --card-width: 240px;
}

.movies-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, var(--card-width));
  gap: var(--spacing-lg);
  margin-top: var(--spacing-xl);
  justify-content: center;
}

.movie-card {
  width: var(--card-width);
}

.movie-poster {
  object-fit: cover;
  background: var(--color-bg-tertiary);
}

.el-pagination {
  display: flex;
  justify-content: center;
}
</style>
