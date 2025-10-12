<template>
  <div class="movie-detail-page">
    <div class="container">
      <h1 class="text-3xl font-bold mb-lg">电影详情</h1>
      
      <!-- 
        TODO: 这里添加电影详情内容
        
        建议实现：
        1. 电影海报 + 基本信息（标题、年份、类型、评分）
        2. 电影简介
        3. 评分功能（el-rate 组件）
        4. 评论列表
        5. 相关推荐
        
        布局提示：
        - 使用 Flexbox 布局：class="flex gap-lg"
        - 左侧海报 + 右侧信息
        - 使用 el-rate 评分组件
        - 使用 el-button 提交评分
      -->
      
      <div class="placeholder">
        <el-empty description="待开发：电影详情页面" />
        <p class="text-sm text-secondary mt-md">
          路由参数 ID: {{ $route.params.id }}
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
// TODO: 导入需要的 API 和工具
// import { ref, onMounted } from 'vue'
// import { useRoute } from 'vue-router'
// import { getMovieById } from '@/api/movie'
// import { addRating } from '@/api/rating'

// const route = useRoute()

// TODO: 定义响应式数据
// const movie = ref(null)
// const loading = ref(false)
// const myRating = ref(0)

// TODO: 加载电影详情
// onMounted(async () => {
//   loading.value = true
//   try {
//     const res = await getMovieById(route.params.id)
//     movie.value = res.data
//   } finally {
//     loading.value = false
//   }
// })

// TODO: 提交评分
// async function submitRating() {
//   await addRating({
//     movieId: route.params.id,
//     rating: myRating.value
//   })
// }
</script>

<style scoped>
.movie-detail-page {
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
  TODO: 添加电影详情样式
  
  示例：
  .movie-content {
    display: flex;
    gap: var(--spacing-xl);
    margin-top: var(--spacing-xl);
  }
  
  .movie-poster {
    flex: 0 0 300px;
  }
  
  .movie-info {
    flex: 1;
  }
*/
</style>

