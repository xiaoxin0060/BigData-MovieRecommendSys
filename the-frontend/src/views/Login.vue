<template>
  <div class="login-page">
    <!-- 使用 flex-center 自动居中，不用调 px -->
    <div class="login-container">
      <div class="login-card card">
        <!-- Logo 区域 -->
        <div class="login-header text-center mb-xl">
          <el-icon :size="48" color="var(--color-accent-blue)">
            <Film />
          </el-icon>
          <h1 class="text-3xl font-bold mt-md mb-sm">欢迎回来</h1>
          <p class="text-sm text-secondary">登录电影推荐系统</p>
        </div>
        
        <!-- 登录表单 -->
        <el-form
          ref="loginFormRef"
          :model="loginForm"
          :rules="loginRules"
          size="large"
        >
          <!-- 账号输入框 -->
          <el-form-item prop="userAccount">
            <el-input
              v-model="loginForm.userAccount"
              placeholder="请输入账号"
              :prefix-icon="User"
              clearable
            />
          </el-form-item>
          
          <!-- 密码输入框 -->
          <el-form-item prop="userPassword">
            <el-input
              v-model="loginForm.userPassword"
              type="password"
              placeholder="请输入密码"
              :prefix-icon="Lock"
              show-password
              @keyup.enter="handleLogin"
            />
          </el-form-item>
          
          <!-- 记住我 -->
          <el-form-item>
            <div class="flex-between w-full">
              <el-checkbox v-model="loginForm.remember">记住我</el-checkbox>
              <el-link type="primary" :underline="false">忘记密码？</el-link>
            </div>
          </el-form-item>
          
          <!-- 登录按钮 -->
          <el-form-item>
            <el-button
              type="primary"
              class="w-full"
              :loading="loading"
              @click="handleLogin"
            >
              {{ loading ? '登录中...' : '登录' }}
            </el-button>
          </el-form-item>
        </el-form>
        
        <!-- 注册链接 -->
        <div class="login-footer text-center mt-lg">
          <span class="text-sm text-secondary">还没有账号？</span>
          <el-link type="primary" :underline="false" @click="goRegister">
            立即注册
          </el-link>
        </div>
      </div>
      
      <!-- 装饰背景 -->
      <div class="login-decoration" />
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { login } from '@/api/user'
import { ElMessage } from 'element-plus'
import { User, Lock } from '@element-plus/icons-vue'

const router = useRouter()
const userStore = useUserStore()

// 表单引用
const loginFormRef = ref(null)

// 加载状态
const loading = ref(false)

// 表单数据
const loginForm = reactive({
  userAccount: '',
  userPassword: '',
  remember: false
})

// 表单验证规则
const loginRules = {
  userAccount: [
    { required: true, message: '请输入账号', trigger: 'blur' },
    { min: 3, max: 20, message: '账号长度为 3-20 个字符', trigger: 'blur' }
  ],
  userPassword: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, max: 20, message: '密码长度为 6-20 个字符', trigger: 'blur' }
  ]
}

// 登录处理
async function handleLogin() {
  // 1. 验证表单
  const valid = await loginFormRef.value.validate().catch(() => false)
  if (!valid) return
  
  try {
    // 2. 显示加载状态
    loading.value = true
    
    // 3. 调用登录 API
    const res = await login({
      userAccount: loginForm.userAccount,
      userPassword: loginForm.userPassword
    })
    
    // 4. 保存登录状态
    userStore.login(res.data.token, res.data.user)
    
    // 5. 显示成功提示
    ElMessage.success('登录成功！')
    
    // 6. 跳转到首页（或重定向到原页面）
    const redirect = router.currentRoute.value.query.redirect || '/'
    router.push(redirect)
    
  } catch (error) {
    // 错误已经在 Axios 拦截器中处理，这里不需要额外处理
    console.error('登录失败:', error)
  } finally {
    // 7. 恢复按钮状态
    loading.value = false
  }
}

// 跳转到注册页
function goRegister() {
  router.push('/register')
}
</script>

<style scoped>
/* 
 * 布局说明：
 * 1. 使用 flex-center 实现垂直水平居中（不用调 px）
 * 2. 使用 CSS 变量统一间距和颜色
 * 3. 使用相对单位（rem）实现响应式
 * 4. 不用写绝对定位（position: absolute）
 */

.login-page {
  /* 全屏高度 */
  min-height: 100vh;
  
  /* Flexbox 居中（不用调 top/left） */
  display: flex;
  align-items: center;
  justify-content: center;
  
  /* 背景渐变 */
  background: linear-gradient(
    135deg,
    var(--color-bg-primary) 0%,
    var(--color-bg-secondary) 50%,
    var(--color-bg-primary) 100%
  );
  
  /* 内边距（使用变量） */
  padding: var(--spacing-lg);
  
  /* 相对定位（为装饰背景） */
  position: relative;
  overflow: hidden;
}

.login-container {
  /* 相对定位 */
  position: relative;
  z-index: 1;
  
  /* 最大宽度（不会太宽） */
  width: 100%;
  max-width: 420px;
}

.login-card {
  /* 使用全局 card 类的样式 */
  /* 额外的内边距 */
  padding: var(--spacing-xxl);
  
  /* 增强阴影（突出层次） */
  box-shadow: var(--color-shadow-xl);
  
  /* 背景微透明（毛玻璃效果） */
  background: var(--color-bg-secondary);
  backdrop-filter: blur(10px);
  
  /* 动画过渡 */
  transition: all var(--transition-base);
}

.login-card:hover {
  /* 悬浮时轻微上浮 */
  transform: translateY(-4px);
  box-shadow: var(--color-shadow-xl);
}

.login-header {
  /* 使用工具类控制间距： */
  /* text-center: 文字居中 */
  /* mb-xl: margin-bottom: 32px */
}

.login-footer {
  /* 使用工具类： */
  /* text-center: 文字居中 */
  /* mt-lg: margin-top: 24px */
}

/* 装饰背景（可选） */
.login-decoration {
  position: absolute;
  top: -50%;
  left: -50%;
  width: 200%;
  height: 200%;
  background: radial-gradient(
    circle at 30% 50%,
    rgba(96, 165, 250, 0.08) 0%,
    transparent 50%
  );
  pointer-events: none;
  animation: rotate 30s linear infinite;
}

@keyframes rotate {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

/* 响应式：移动端适配 */
@media (max-width: 480px) {
  .login-card {
    /* 移动端减少内边距 */
    padding: var(--spacing-xl);
  }
  
  .login-header h1 {
    /* 移动端减小标题 */
    font-size: var(--font-size-2xl);
  }
}
</style>

