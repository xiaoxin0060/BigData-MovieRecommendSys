import { createRouter, createWebHistory } from 'vue-router'
import { useUserStore } from '@/stores/user'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    // ===== 首页 =====
    {
      path: '/',
      name: 'Home',
      component: () => import('@/views/Home.vue'),
      meta: { title: '首页' }
    },
    
    // ===== 用户相关 =====
    {
      path: '/login',
      name: 'Login',
      component: () => import('@/views/Login.vue'),
      meta: { title: '登录' }
    },
    {
      path: '/register',
      name: 'Register',
      component: () => import('@/views/Register.vue'),
      meta: { title: '注册' }
    },
    
    // ===== 电影相关 =====
    {
      path: '/movies',
      name: 'Movies',
      component: () => import('@/views/Movies.vue'),
      meta: { title: '电影列表' }
    },
    {
      path: '/movies/:id',
      name: 'MovieDetail',
      component: () => import('@/views/MovieDetail.vue'),
      meta: { title: '电影详情' }
    },
    
    // ===== 个人中心（需要登录） =====
    {
      path: '/profile',
      name: 'Profile',
      component: () => import('@/views/Profile.vue'),
      meta: { 
        title: '个人中心',
        requiresAuth: true  // 需要登录
      }
    },
    {
      path: '/my-ratings',
      name: 'MyRatings',
      component: () => import('@/views/MyRatings.vue'),
      meta: { 
        title: '我的评分',
        requiresAuth: true
      }
    },
    {
      path: '/recommendations',
      name: 'Recommendations',
      component: () => import('@/views/Recommendations.vue'),
      meta: { 
        title: '为我推荐',
        requiresAuth: true
      }
    },
    
    // ===== 管理员仪表盘（需要登录，先不做权限区分） =====
    {
      path: '/admin/dashboard',
      name: 'AdminDashboard',
      component: () => import('@/views/AdminDashboard.vue'),
      meta: {
        title: '系统监控仪表盘',
        requiresAuth: true
      }
    },

    // ===== 404 页面 =====
    {
      path: '/:pathMatch(.*)*',
      name: 'NotFound',
      component: () => import('@/views/NotFound.vue'),
      meta: { title: '页面不存在' }
    }
  ]
})

// ===== 全局路由守卫 =====
router.beforeEach((to, from, next) => {
  // 设置页面标题
  document.title = to.meta.title ? `${to.meta.title} - 电影推荐系统` : '电影推荐系统'
  
  // 检查是否需要登录
  if (to.meta.requiresAuth) {
    const userStore = useUserStore()
    
    if (!userStore.isLoggedIn) {
      // 未登录，跳转到登录页
      next({
        path: '/login',
        query: { redirect: to.fullPath }  // 登录后重定向回原页面
      })
      return
    }
  }
  
  next()
})

export default router
