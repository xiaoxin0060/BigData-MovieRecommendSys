<template>
  <div class="movies-page">
    <div class="container">
      <h1 class="text-3xl font-bold mb-lg">电影列表</h1>
      
      <!-- 
        TODO: 这里添加电影列表内容
        
        建议实现：
        1. 筛选栏（类型、年份、排序）
        2. 电影网格（使用 Grid 布局）
        3. 电影卡片组件（MovieCard）
        4. 分页组件
        
        布局提示：
        - 使用 display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        - 使用工具类：class="mt-lg mb-md"
        - 使用 Element Plus 组件：el-select, el-pagination
      -->
      
      <div class="placeholder">
        <el-empty description="待开发：电影列表页面" />
      </div>
    </div>
  </div>
</template>

<script setup>
// TODO: 导入需要的 API 和工具
// import { ref, onMounted } from 'vue'
// import { getMovies } from '@/api/movie'

// TODO: 定义响应式数据
// const movies = ref([])
// const loading = ref(false)

// TODO: 加载电影列表
// onMounted(async () => {
//   loading.value = true
//   try {
//     const res = await getMovies()
//     movies.value = res.data.movies
//   } finally {
//     loading.value = false
//   }
// })
</script>

<style scoped>
.movies-page {
  min-height: 100vh;
  padding: var(--spacing-xl) 0;
}

.placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 400px;
}

/* 
  TODO: 添加电影网格样式
  
  示例：
  .movies-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: var(--spacing-lg);
    margin-top: var(--spacing-xl);
  }
*/
</style>

