<template>
  <div class="dashboard-page">
    <div class="container">
      <h1 class="text-3xl font-bold mb-lg">系统监控仪表盘</h1>

      <!-- 顶部指标卡片 -->
      <div class="kpi-grid mb-xl">
        <el-card class="kpi-card" shadow="hover">
          <p class="kpi-label">用户总数</p>
          <p class="kpi-value">{{ overview.users.total }}</p>
          <p class="kpi-sub">今日新增：{{ overview.users.newToday }}，今日活跃：{{ overview.users.activeToday }}</p>
        </el-card>

        <el-card class="kpi-card" shadow="hover">
          <p class="kpi-label">电影总数</p>
          <p class="kpi-value">{{ overview.movies.total }}</p>
          <p class="kpi-sub">有评分的电影：{{ overview.movies.withRatings }}</p>
        </el-card>

        <el-card class="kpi-card" shadow="hover">
          <p class="kpi-label">评分总数</p>
          <p class="kpi-value">{{ overview.ratings.total }}</p>
          <p class="kpi-sub">24 小时：{{ overview.ratings.last24h }}，1 小时：{{ overview.ratings.last1h }}</p>
        </el-card>

        <el-card class="kpi-card" shadow="hover">
          <p class="kpi-label">推荐覆盖率（当前模型）</p>
          <p class="kpi-value">
            <span v-if="coveragePercent != null">{{ coveragePercent.toFixed(1) }}%</span>
            <span v-else>--</span>
          </p>
          <p class="kpi-sub">
            模型版本：{{ overview.recommendations.activeModelVersion || 'v0' }}
            <br />
            最近生成时间：{{ formatDateTime(overview.recommendations.lastGeneratedAt) || '暂无' }}
          </p>
        </el-card>
      </div>

      <div class="dashboard-main-grid">
        <!-- 左侧：评分趋势（简单表格占位，后续可接入图表库） -->
        <el-card class="mb-lg" shadow="hover">
          <template #header>
            <div class="card-header">
              <span>最近 24 小时评分趋势（按小时）</span>
              <el-button size="small" @click="loadRatingSeries" :loading="loadingSeries">刷新</el-button>
            </div>
          </template>
          <el-table
            v-if="ratingSeries.length"
            :data="ratingSeries"
            size="small"
            style="width: 100%"
          >
            <el-table-column prop="timestamp" label="时间" width="180" />
            <el-table-column prop="value" label="评分数量" />
          </el-table>
          <div v-else class="text-secondary text-sm">暂无趋势数据</div>
        </el-card>

        <!-- 右侧：作业状态 -->
        <el-card class="mb-lg" shadow="hover">
          <template #header>
            <div class="card-header">
              <span>大数据作业状态</span>
              <el-button size="small" @click="loadJobs" :loading="loadingJobs">刷新</el-button>
            </div>
          </template>
          <el-table :data="jobs" size="small" style="width: 100%">
            <el-table-column label="作业" prop="jobName" width="180" />
            <el-table-column label="状态" width="120">
              <template #default="{ row }">
                <el-tag :type="statusTagType(row.status)">
                  {{ row.status }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="最近心跳" width="200">
              <template #default="{ row }">
                {{ formatDateTime(row.lastHeartbeatAt) || '-' }}
              </template>
            </el-table-column>
            <el-table-column label="最近批次" width="200">
              <template #default="{ row }">
                <span v-if="row.lastBatchSize != null">
                  {{ row.lastBatchSize }} 条 / {{ row.lastBatchDurationMs }} ms
                </span>
                <span v-else>-</span>
              </template>
            </el-table-column>
            <el-table-column label="模型版本">
              <template #default="{ row }">
                {{ row.modelVersion || '-' }}
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { getMetricsOverview, getJobMetrics, getRatingsTimeseries } from '@/api/admin'

const overview = ref({
  users: { total: 0, newToday: 0, activeToday: 0 },
  movies: { total: 0, withRatings: 0 },
  ratings: { total: 0, last24h: 0, last1h: 0 },
  recommendations: {
    total: 0,
    coverageActiveVersion: 0,
    activeModelVersion: 'v0',
    lastGeneratedAt: null
  }
})

const jobs = ref([])
const ratingSeries = ref([])

const loadingOverview = ref(false)
const loadingJobs = ref(false)
const loadingSeries = ref(false)

let timer = null

const coveragePercent = computed(() => {
  const total = overview.value.users.total
  const covered = overview.value.recommendations.coverageActiveVersion
  if (!total || covered == null) return null
  return (covered / total) * 100
})

function formatDateTime(value) {
  if (!value) return ''
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleString()
}

function statusTagType(status) {
  if (status === 'RUNNING' || status === 'SUCCEEDED') return 'success'
  if (status === 'FAILED') return 'danger'
  return 'info'
}

async function loadOverview() {
  loadingOverview.value = true
  try {
    const res = await getMetricsOverview()
    if (res && res.data) {
      overview.value = res.data
    }
  } catch (e) {
    console.error('加载概览数据失败', e)
  } finally {
    loadingOverview.value = false
  }
}

async function loadJobs() {
  loadingJobs.value = true
  try {
    const res = await getJobMetrics()
    if (res && res.data && Array.isArray(res.data.jobs)) {
      jobs.value = res.data.jobs
    }
  } catch (e) {
    console.error('加载作业状态失败', e)
  } finally {
    loadingJobs.value = false
  }
}

async function loadRatingSeries() {
  loadingSeries.value = true
  try {
    const now = new Date()
    const from = new Date(now.getTime() - 24 * 60 * 60 * 1000)
    const res = await getRatingsTimeseries({
      from: from.toISOString(),
      to: now.toISOString(),
      interval: 'hour'
    })
    if (res && res.data && Array.isArray(res.data.points)) {
      ratingSeries.value = res.data.points
    }
  } catch (e) {
    console.error('加载评分时间序列失败', e)
  } finally {
    loadingSeries.value = false
  }
}

onMounted(async () => {
  await Promise.all([
    loadOverview(),
    loadJobs(),
    loadRatingSeries()
  ])

  timer = setInterval(() => {
    loadOverview()
    loadJobs()
  }, 15000)
})

onBeforeUnmount(() => {
  if (timer) {
    clearInterval(timer)
  }
})
</script>

<style scoped>
.dashboard-page {
  min-height: 100vh;
  padding: var(--spacing-xl) 0;
}

.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: var(--spacing-lg);
}

.kpi-card {
  text-align: left;
}

.kpi-label {
  font-size: var(--font-size-sm);
  color: var(--color-text-secondary);
  margin-bottom: var(--spacing-xs);
}

.kpi-value {
  font-size: var(--font-size-3xl);
  font-weight: var(--font-weight-bold);
  margin-bottom: var(--spacing-xs);
}

.kpi-sub {
  font-size: var(--font-size-xs);
  color: var(--color-text-tertiary);
  line-height: var(--line-height-relaxed);
}

.dashboard-main-grid {
  display: grid;
  grid-template-columns: 2fr 1.5fr;
  gap: var(--spacing-lg);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

@media (max-width: 960px) {
  .dashboard-main-grid {
    grid-template-columns: 1fr;
  }
}
</style>
