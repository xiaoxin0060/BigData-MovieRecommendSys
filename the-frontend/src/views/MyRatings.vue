<template>
  <div class="my-ratings-page">
    <div class="container">
      <h1 class="text-3xl font-bold mb-lg">我的评分</h1>

      <div v-if="loading" class="flex-center" style="min-height: 400px">
        <el-icon class="is-loading" :size="40"><Loading /></el-icon>
      </div>

      <div v-else-if="ratings.length > 0">
        <div class="ratings-grid">
          <el-card 
            v-for="item in ratings"
            :key="item.id"
            class="rating-card cursor-pointer transition hover-lift"
            shadow="hover"
            @click="goDetail(item.movie.id)"
          >
            <div class="flex" style="gap: var(--spacing-md)">
              <img
                :src="item.movie.posterUrl || '/1.jpg'"
                :alt="item.movie.title"
                class="rating-poster rounded-md"
              />
              
              <div class="flex-1">
                <h3 class="text-lg font-semibold mb-xs line-clamp-2">{{ item.movie.title }}</h3>
                <p class="text-sm text-secondary mb-sm">{{ item.movie.genres }}</p>
                <p class="text-xs text-tertiary mb-md">{{ item.movie.year }}</p>
                
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs text-tertiary mb-xs">我的评分</p>
                    <el-rate 
                      v-model="item.rating" 
                      :max="5"
                      disabled
                      show-score
                      score-template="{value} 分"
                    />
                  </div>
                  <span class="text-xs text-tertiary">
                    {{ formatDate(item.createdAt) }}
                  </span>
                </div>
              </div>
            </div>
          </el-card>
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

      <div v-else class="flex-center" style="min-height: 400px">
        <el-empty description="还没有评分">
          <template #description>
            <p class="text-sm text-secondary">快去给看过的电影打分吧！</p>
          </template>
        </el-empty>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { getMyRatings } from '@/api/rating'
import { Loading } from '@element-plus/icons-vue'

const router = useRouter()
const ratings = ref([])
const loading = ref(false)
const total = ref(0)

const queryParams = reactive({
  page: 1,
  pageSize: 10
})

async function fetchRatings() {
  loading.value = true
  try {
    const res = await getMyRatings(queryParams)
    ratings.value = res.data.ratings
    total.value = res.data.pagination.total
  } catch (error) {
    console.error('获取评分失败:', error)
  } finally {
    loading.value = false
  }
}

function handlePageChange(page) {
  queryParams.page = page
  fetchRatings()
}

function goDetail(id) {
  router.push(`/movies/${id}`)
}

function formatDate(date) {
  if (!date) return ''
  return new Date(date).toLocaleDateString('zh-CN')
}

onMounted(() => {
  fetchRatings()
})
</script>

<style scoped>
.my-ratings-page {
  min-height: 100vh;
  padding: var(--spacing-xl) 0;
}

.ratings-grid {
  display: grid;
  gap: var(--spacing-lg);
}

.rating-card {
  width: 100%;
}

.rating-poster {
  width: 100px;
  height: 140px;
  object-fit: cover;
  background: var(--color-bg-tertiary);
  flex-shrink: 0;
}

.el-pagination {
  display: flex;
  justify-content: center;
}
</style>
