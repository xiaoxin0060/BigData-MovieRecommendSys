<template>
  <div class="dashboard-page">
    <div class="container">
      <h1 class="text-3xl font-bold mb-lg">系统监控仪表盘</h1>

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
            模型版本：{{ overview.recommendations.activeModelVersion || 'v0' }}<br />
            最近生成时间：{{ formatDateTime(overview.recommendations.lastGeneratedAt) || '暂无' }}
          </p>
        </el-card>
      </div>

      <div class="dashboard-main-grid">
        <div class="dashboard-col">
          <el-card shadow="hover">
            <template #header>
              <div class="card-header">
                <span>最近 24 小时评分趋势（按小时）</span>
                <el-button size="small" @click="loadRatingSeries" :loading="loadingSeries">刷新</el-button>
              </div>
            </template>
            <EChart v-if="ratingSeries.length" :option="ratingsChartOption" height="260px" />
            <div v-else class="text-secondary text-sm">暂无趋势数据</div>
          </el-card>

          <el-card shadow="hover">
            <template #header>
              <div class="card-header">
                <span>最近 24 小时活跃用户（按小时）</span>
                <el-button size="small" @click="loadActiveUsersSeries" :loading="loadingActiveUsersSeries">刷新</el-button>
              </div>
            </template>
            <EChart v-if="activeUsersSeries.length" :option="activeUsersChartOption" height="220px" />
            <div v-else class="text-secondary text-sm">暂无活跃数据</div>
          </el-card>
        </div>

        <div class="dashboard-col">
          <el-card shadow="hover">
            <template #header>
              <div class="card-header">
                <span>大数据作业状态</span>
                <el-button size="small" @click="loadJobs" :loading="loadingJobs">刷新</el-button>
              </div>
            </template>

            <EChart v-if="jobs.length" :option="jobsHeartbeatChartOption" height="160px" />

            <el-table :data="jobs" size="small" style="width: 100%">
              <el-table-column label="作业" prop="jobName" width="180" />
              <el-table-column label="状态" width="120">
                <template #default="{ row }">
                  <el-tag :type="statusTagType(row.status)">{{ row.status }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column label="最近心跳" width="200">
                <template #default="{ row }">
                  {{ formatDateTime(row.lastHeartbeatAt) || '-' }}
                </template>
              </el-table-column>
              <el-table-column label="最近批次" width="200">
                <template #default="{ row }">
                  <span v-if="row.lastBatchSize != null">{{ row.lastBatchSize }} 条 / {{ row.lastBatchDurationMs }} ms</span>
                  <span v-else>-</span>
                </template>
              </el-table-column>
              <el-table-column label="模型版本">
                <template #default="{ row }">{{ row.modelVersion || '-' }}</template>
              </el-table-column>
            </el-table>
          </el-card>

          <el-card shadow="hover">
            <template #header>
              <div class="card-header">
                <span>评分分布（最近 24 小时）</span>
                <el-button size="small" @click="loadRatingsDistribution" :loading="loadingRatingsDistribution">刷新</el-button>
              </div>
            </template>
            <EChart v-if="ratingBuckets.length" :option="ratingsDistributionChartOption" height="220px" />
            <div v-else class="text-secondary text-sm">暂无分布数据</div>
          </el-card>

          <el-card shadow="hover">
            <template #header>
              <div class="card-header">
                <span>Top 电影（按评分数）</span>
                <el-button size="small" @click="loadTopMovies" :loading="loadingTopMovies">刷新</el-button>
              </div>
            </template>
            <EChart v-if="topMovies.length" :option="topMoviesChartOption" height="240px" />
            <div v-else class="text-secondary text-sm">暂无 Top 数据</div>
          </el-card>

          <el-card shadow="hover">
            <template #header>
              <div class="card-header">
                <span>Top 用户（最近 24 小时评分数）</span>
                <el-button size="small" @click="loadTopUsers" :loading="loadingTopUsers">刷新</el-button>
              </div>
            </template>
            <EChart v-if="topUsers.length" :option="topUsersChartOption" height="240px" />
            <div v-else class="text-secondary text-sm">暂无 Top 数据</div>
          </el-card>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import {
  getMetricsOverview,
  getJobMetrics,
  getRatingsTimeseries,
  getActiveUsersTimeseries,
  getRatingsDistribution,
  getTopMovies,
  getTopUsers
} from '@/api/admin'
import EChart from '@/components/EChart.vue'

const overview = ref({
  users: { total: 0, newToday: 0, activeToday: 0 },
  movies: { total: 0, withRatings: 0 },
  ratings: { total: 0, last24h: 0, last1h: 0 },
  recommendations: {
    total: 0,
    coverageActiveVersion: null,
    activeModelVersion: 'v0',
    lastGeneratedAt: null
  }
})

const jobs = ref([])
const ratingSeries = ref([])
const activeUsersSeries = ref([])
const ratingBuckets = ref([])
const topMovies = ref([])
const topUsers = ref([])

const loadingOverview = ref(false)
const loadingJobs = ref(false)
const loadingSeries = ref(false)
const loadingActiveUsersSeries = ref(false)
const loadingRatingsDistribution = ref(false)
const loadingTopMovies = ref(false)
const loadingTopUsers = ref(false)

let timer = null

const coveragePercent = computed(() => {
  const total = overview.value.users.total
  const covered = overview.value.recommendations.coverageActiveVersion
  if (!total || covered == null) return null
  return (covered / total) * 100
})

const ratingsChartOption = computed(() => {
  const data = ratingSeries.value || []
  const x = data.map((p) => (p.timestamp || '').toString().replace('T', ' ').slice(0, 16))
  const y = data.map((p) => Number(p.value || 0))

  return {
    backgroundColor: 'transparent',
    tooltip: { trigger: 'axis' },
    grid: { left: 12, right: 12, top: 24, bottom: 18, containLabel: true },
    xAxis: {
      type: 'category',
      data: x,
      boundaryGap: false,
      axisLabel: { color: '#BFBFBF', fontSize: 11 }
    },
    yAxis: {
      type: 'value',
      axisLabel: { color: '#BFBFBF', fontSize: 11 },
      splitLine: { lineStyle: { color: 'rgba(255,255,255,0.08)' } }
    },
    series: [
      {
        name: '评分数',
        type: 'line',
        smooth: true,
        showSymbol: false,
        lineStyle: { width: 2, color: '#5B8FF9' },
        areaStyle: { color: 'rgba(91,143,249,0.18)' },
        data: y
      }
    ]
  }
})

const activeUsersChartOption = computed(() => {
  const data = activeUsersSeries.value || []
  const x = data.map((p) => (p.timestamp || '').toString().replace('T', ' ').slice(0, 16))
  const y = data.map((p) => Number(p.value || 0))

  return {
    backgroundColor: 'transparent',
    tooltip: { trigger: 'axis' },
    grid: { left: 12, right: 12, top: 24, bottom: 18, containLabel: true },
    xAxis: {
      type: 'category',
      data: x,
      boundaryGap: false,
      axisLabel: { color: '#BFBFBF', fontSize: 11 }
    },
    yAxis: {
      type: 'value',
      axisLabel: { color: '#BFBFBF', fontSize: 11 },
      splitLine: { lineStyle: { color: 'rgba(255,255,255,0.08)' } }
    },
    series: [
      {
        name: '活跃用户',
        type: 'line',
        smooth: true,
        showSymbol: false,
        lineStyle: { width: 2, color: '#36CFC9' },
        areaStyle: { color: 'rgba(54,207,201,0.18)' },
        data: y
      }
    ]
  }
})

const ratingsDistributionChartOption = computed(() => {
  const data = ratingBuckets.value || []
  const x = data.map((b) => String(b.rating))
  const y = data.map((b) => Number(b.count || 0))

  return {
    backgroundColor: 'transparent',
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: 12, right: 12, top: 24, bottom: 18, containLabel: true },
    xAxis: {
      type: 'category',
      data: x,
      axisLabel: { color: '#BFBFBF', fontSize: 11 }
    },
    yAxis: {
      type: 'value',
      axisLabel: { color: '#BFBFBF', fontSize: 11 },
      splitLine: { lineStyle: { color: 'rgba(255,255,255,0.08)' } }
    },
    series: [
      {
        name: '评分次数',
        type: 'bar',
        barMaxWidth: 26,
        itemStyle: { color: '#5B8FF9', borderRadius: [6, 6, 0, 0] },
        data: y
      }
    ]
  }
})

function shortLabel(text, maxLen = 12) {
  if (!text) return ''
  const s = String(text)
  if (s.length <= maxLen) return s
  return s.slice(0, maxLen - 1) + '…'
}

const topMoviesChartOption = computed(() => {
  const data = topMovies.value || []
  const names = data.map((m) => shortLabel(m.title, 12)).reverse()
  const fullNames = data.map((m) => m.title || '').reverse()
  const counts = data.map((m) => Number(m.ratingCount || 0)).reverse()

  return {
    backgroundColor: 'transparent',
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: (params) => {
        const p = Array.isArray(params) ? params[0] : params
        const idx = p?.dataIndex ?? 0
        const title = fullNames[idx] || p?.name || ''
        return `${title}<br/>评分数：${Number(p?.value || 0).toLocaleString()}`
      }
    },
    grid: { left: 12, right: 12, top: 12, bottom: 6, containLabel: true },
    xAxis: {
      type: 'value',
      axisLabel: { color: '#BFBFBF', fontSize: 11 },
      splitLine: { lineStyle: { color: 'rgba(255,255,255,0.08)' } }
    },
    yAxis: {
      type: 'category',
      data: names,
      axisLabel: { color: '#BFBFBF', fontSize: 11 }
    },
    series: [
      {
        name: '评分数',
        type: 'bar',
        barMaxWidth: 18,
        itemStyle: { color: '#FAAD14', borderRadius: [0, 6, 6, 0] },
        data: counts
      }
    ]
  }
})

const topUsersChartOption = computed(() => {
  const data = topUsers.value || []
  const labels = data
    .map((u) => u.userName || u.userAccount || u.userId || 'unknown')
    .map((s) => shortLabel(s, 14))
    .reverse()
  const full = data
    .map((u) => u.userName || u.userAccount || u.userId || 'unknown')
    .reverse()
  const counts = data.map((u) => Number(u.ratings || 0)).reverse()

  return {
    backgroundColor: 'transparent',
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: (params) => {
        const p = Array.isArray(params) ? params[0] : params
        const idx = p?.dataIndex ?? 0
        const name = full[idx] || p?.name || ''
        return `${name}<br/>评分数：${Number(p?.value || 0).toLocaleString()}`
      }
    },
    grid: { left: 12, right: 12, top: 12, bottom: 6, containLabel: true },
    xAxis: {
      type: 'value',
      axisLabel: { color: '#BFBFBF', fontSize: 11 },
      splitLine: { lineStyle: { color: 'rgba(255,255,255,0.08)' } }
    },
    yAxis: {
      type: 'category',
      data: labels,
      axisLabel: { color: '#BFBFBF', fontSize: 11 }
    },
    series: [
      {
        name: '评分数',
        type: 'bar',
        barMaxWidth: 18,
        itemStyle: { color: '#52C41A', borderRadius: [0, 6, 6, 0] },
        data: counts
      }
    ]
  }
})

const jobsHeartbeatChartOption = computed(() => {
  const now = Date.now()
  const rows = (jobs.value || []).map((j) => {
    const t = j.lastHeartbeatAt ? new Date(j.lastHeartbeatAt).getTime() : null
    const lagSec = t ? Math.max(0, Math.round((now - t) / 1000)) : null
    return { name: j.jobName, lagSec }
  })

  return {
    backgroundColor: 'transparent',
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: (params) => {
        const p = Array.isArray(params) ? params[0] : params
        const v = p?.value
        const s = v == null ? '-' : `${v}s`
        return `${p?.name}<br/>心跳延迟：${s}`
      }
    },
    grid: { left: 12, right: 12, top: 12, bottom: 6, containLabel: true },
    xAxis: {
      type: 'category',
      data: rows.map((r) => r.name),
      axisLabel: { color: '#BFBFBF', fontSize: 11 }
    },
    yAxis: {
      type: 'value',
      name: '秒',
      nameTextStyle: { color: '#BFBFBF', fontSize: 11 },
      axisLabel: { color: '#BFBFBF', fontSize: 11 },
      splitLine: { lineStyle: { color: 'rgba(255,255,255,0.08)' } }
    },
    series: [
      {
        name: '心跳延迟',
        type: 'bar',
        barMaxWidth: 26,
        itemStyle: {
          color: (p) => {
            const v = p.value
            if (v == null) return 'rgba(255,255,255,0.15)'
            if (v <= 15) return '#52C41A'
            if (v <= 60) return '#FAAD14'
            return '#FF4D4F'
          },
          borderRadius: [6, 6, 0, 0]
        },
        data: rows.map((r) => r.lagSec)
      }
    ]
  }
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
    if (res && res.data) overview.value = res.data
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
    if (res && res.data && Array.isArray(res.data.jobs)) jobs.value = res.data.jobs
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
    if (res && res.data && Array.isArray(res.data.points)) ratingSeries.value = res.data.points
  } catch (e) {
    console.error('加载评分时间序列失败', e)
  } finally {
    loadingSeries.value = false
  }
}

async function loadActiveUsersSeries() {
  loadingActiveUsersSeries.value = true
  try {
    const now = new Date()
    const from = new Date(now.getTime() - 24 * 60 * 60 * 1000)
    const res = await getActiveUsersTimeseries({
      from: from.toISOString(),
      to: now.toISOString(),
      interval: 'hour'
    })
    if (res && res.data && Array.isArray(res.data.points)) activeUsersSeries.value = res.data.points
  } catch (e) {
    console.error('加载活跃用户时间序列失败', e)
  } finally {
    loadingActiveUsersSeries.value = false
  }
}

async function loadRatingsDistribution() {
  loadingRatingsDistribution.value = true
  try {
    const now = new Date()
    const from = new Date(now.getTime() - 24 * 60 * 60 * 1000)
    const res = await getRatingsDistribution({
      from: from.toISOString(),
      to: now.toISOString()
    })
    if (res && res.data && Array.isArray(res.data.buckets)) ratingBuckets.value = res.data.buckets
  } catch (e) {
    console.error('加载评分分布失败', e)
  } finally {
    loadingRatingsDistribution.value = false
  }
}

async function loadTopMovies() {
  loadingTopMovies.value = true
  try {
    const res = await getTopMovies({ limit: 10 })
    if (res && res.data && Array.isArray(res.data.movies)) topMovies.value = res.data.movies
  } catch (e) {
    console.error('加载 Top 电影失败', e)
  } finally {
    loadingTopMovies.value = false
  }
}

async function loadTopUsers() {
  loadingTopUsers.value = true
  try {
    const now = new Date()
    const from = new Date(now.getTime() - 24 * 60 * 60 * 1000)
    const res = await getTopUsers({
      from: from.toISOString(),
      to: now.toISOString(),
      limit: 10
    })
    if (res && res.data && Array.isArray(res.data.users)) topUsers.value = res.data.users
  } catch (e) {
    console.error('加载 Top 用户失败', e)
  } finally {
    loadingTopUsers.value = false
  }
}

onMounted(async () => {
  await Promise.all([
    loadOverview(),
    loadJobs(),
    loadRatingSeries(),
    loadActiveUsersSeries(),
    loadRatingsDistribution(),
    loadTopMovies(),
    loadTopUsers()
  ])
  timer = setInterval(() => {
    loadOverview()
    loadJobs()
  }, 15000)
})

onBeforeUnmount(() => {
  if (timer) clearInterval(timer)
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

.dashboard-col {
  display: flex;
  flex-direction: column;
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
