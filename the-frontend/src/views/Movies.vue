<template>
  <div class="movies-page">
    <div class="container">
      <h1 class="text-3xl font-bold mb-lg">电影列表</h1>

      <!-- 筛选栏 -->
      <div class="card p-lg mb-xl">
        <div class="flex flex-wrap items-center" style="gap: var(--spacing-md)">
          <div class="filter-item search-box">
            <el-input
              v-model="queryParams.keyword"
              placeholder="搜索电影名称..."
              clearable
              @keyup.enter="handleSearch"
              @clear="handleSearch"
            >
              <template #prefix>
                <el-icon><Search /></el-icon>
              </template>
            </el-input>
          </div>
          
          <div class="filter-item">
            <el-select 
              v-model="queryParams.sort" 
              placeholder="⭐ 排序"
              @change="handleSearch"
            >
              <el-option label="评分最高" value="avgRating" />
              <el-option label="年份最新" value="year" />
              <el-option label="名称排序" value="title" />
            </el-select>
          </div>
          
          <el-button 
            type="primary" 
            :icon="Search" 
            @click="handleSearch"
            class="search-btn"
          >
            搜索
          </el-button>
        </div>
      </div>

      <div v-if="loading" class="flex-center flex-col" style="min-height: 400px">
        <el-icon class="is-loading" :size="40"><Loading /></el-icon>
        <p class="mt-md text-secondary">加载中...</p>
      </div>

      <div v-else-if="movies.length > 0" class="movies-grid">
        <el-card 
          v-for="movie in movies"
          :key="movie.id"
          class="movie-card cursor-pointer transition hover-lift"
          shadow="hover"
          @click="goDetail(movie.id)"
        >
          <template #header>
            <span class="text-lg font-semibold text-ellipsis">{{ movie.title }}</span>
          </template>
          
          <img
            :src="movie.posterUrl || '/1.jpg'"
            :alt="movie.title"
            class="movie-poster w-full rounded-md"
          />
          
          <div class="mt-md">
            <p class="text-sm text-secondary mb-xs">
              <span class="text-tertiary">类型：</span>{{ movie.genres }}
            </p>
            <p class="text-sm text-secondary mb-xs">
              <span class="text-tertiary">年份：</span>{{ movie.year }}
            </p>
            <p class="text-sm text-primary font-medium">
              <span class="text-tertiary">评分：</span>
              <span class="text-accent">{{ movie.avgRating || 0 }}</span>
            </p>
          </div>
        </el-card>
      </div>

      <div v-else class="flex-center" style="min-height: 400px">
        <el-empty description="暂无电影" />
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
import { getMovies } from '@/api/movie'
import { Loading, Search } from '@element-plus/icons-vue'

const router = useRouter()

const movies = ref([])
const loading = ref(false)
const total = ref(0)

const queryParams = reactive({
  page: 1,
  pageSize: 8,
  keyword: '',
  sort: 'avgRating'
})

async function fetchMovies() {
  loading.value = true
  try {
    const res = await getMovies(queryParams)
    movies.value = res.data.movies
    total.value = res.data.pagination.total
  } catch (error) {
    console.error('获取电影失败:', error)
  } finally {
    loading.value = false
  }
}

function handleSearch() {
  queryParams.page = 1
  fetchMovies()
}

function handlePageChange(page) {
  queryParams.page = page
  fetchMovies()
}

function goDetail(id) {
  router.push(`/movies/${id}`)
}

onMounted(() => {
  fetchMovies()
})
</script>

<style scoped>
.movies-page {
  min-height: 100vh;
  padding: var(--spacing-xl) 0;
  
  /* 组件私有变量 */
  --card-width: 240px;
  --filter-item-width: 200px;
  --search-box-min-width: 300px;
}

/* 筛选栏 */
.filter-item {
  width: var(--filter-item-width);
}

.search-box {
  flex: 1;
  min-width: var(--search-box-min-width);
}

.search-btn {
  padding: 0 var(--spacing-xl);
}

/* 电影网格 */
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

/* 分页居中 */
.el-pagination {
  display: flex;
  justify-content: center;
}
</style>

