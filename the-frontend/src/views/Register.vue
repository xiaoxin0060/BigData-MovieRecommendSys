<template>
  <div class="register-page">
    <div class="register-container">
      <div class="register-card card">
        <!-- Logo 区域 -->
        <div class="register-header text-center mb-xl">
          <el-icon :size="48" color="var(--color-accent-blue)">
            <Film />
          </el-icon>
          <h1 class="text-3xl font-bold mt-md mb-sm">加入我们</h1>
          <p class="text-sm text-secondary">注册电影推荐系统账号</p>
        </div>
        
        <!-- 注册表单 -->
        <el-form
          ref="registerFormRef"
          :model="registerForm"
          :rules="registerRules"
          size="large"
        >
          <!-- 账号输入框 -->
          <el-form-item prop="userAccount">
            <el-input
              v-model="registerForm.userAccount"
              placeholder="请输入账号（3-20个字符）"
              :prefix-icon="User"
              clearable
            />
          </el-form-item>
          
          <!-- 昵称输入框 -->
          <el-form-item prop="userName">
            <el-input
              v-model="registerForm.userName"
              placeholder="请输入昵称（可选）"
              :prefix-icon="UserFilled"
              clearable
            />
          </el-form-item>
          
          <!-- 性别选择 -->
          <el-form-item prop="gender">
            <el-select
              v-model="registerForm.gender"
              placeholder="请选择性别（可选）"
              class="w-full"
              clearable
            >
              <el-option label="男" :value="1" />
              <el-option label="女" :value="0" />
            </el-select>
          </el-form-item>
          
          <!-- 密码输入框 -->
          <el-form-item prop="userPassword">
            <el-input
              v-model="registerForm.userPassword"
              type="password"
              placeholder="请输入密码（6-20个字符）"
              :prefix-icon="Lock"
              show-password
            />
          </el-form-item>
          
          <!-- 确认密码输入框 -->
          <el-form-item prop="confirmPassword">
            <el-input
              v-model="registerForm.confirmPassword"
              type="password"
              placeholder="请再次输入密码"
              :prefix-icon="Lock"
              show-password
              @keyup.enter="handleRegister"
            />
          </el-form-item>
          
          <!-- 用户协议 -->
          <el-form-item prop="agree">
            <el-checkbox v-model="registerForm.agree">
              我已阅读并同意
              <el-link type="primary" :underline="false">《用户协议》</el-link>
              和
              <el-link type="primary" :underline="false">《隐私政策》</el-link>
            </el-checkbox>
          </el-form-item>
          
          <!-- 注册按钮 -->
          <el-form-item>
            <el-button
              type="primary"
              class="w-full"
              :loading="loading"
              @click="handleRegister"
            >
              {{ loading ? '注册中...' : '注册' }}
            </el-button>
          </el-form-item>
        </el-form>
        
        <!-- 登录链接 -->
        <div class="register-footer text-center mt-lg">
          <span class="text-sm text-secondary">已有账号？</span>
          <el-link type="primary" :underline="false" @click="goLogin">
            立即登录
          </el-link>
        </div>
      </div>
      
      <!-- 装饰背景 -->
      <div class="register-decoration" />
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { register } from '@/api/user'
import { ElMessage } from 'element-plus'
import { User, UserFilled, Lock } from '@element-plus/icons-vue'

const router = useRouter()

// 表单引用
const registerFormRef = ref(null)

// 加载状态
const loading = ref(false)

// 表单数据
const registerForm = reactive({
  userAccount: '',
  userName: '',
  gender: null,
  userPassword: '',
  confirmPassword: '',
  agree: false
})

// 自定义验证：确认密码
const validateConfirmPassword = (rule, value, callback) => {
  if (value === '') {
    callback(new Error('请再次输入密码'))
  } else if (value !== registerForm.userPassword) {
    callback(new Error('两次输入的密码不一致'))
  } else {
    callback()
  }
}

// 自定义验证：用户协议
const validateAgree = (rule, value, callback) => {
  if (!value) {
    callback(new Error('请阅读并同意用户协议'))
  } else {
    callback()
  }
}

// 表单验证规则
const registerRules = {
  userAccount: [
    { required: true, message: '请输入账号', trigger: 'blur' },
    { min: 3, max: 20, message: '账号长度为 3-20 个字符', trigger: 'blur' },
    { 
      pattern: /^[a-zA-Z0-9_]+$/, 
      message: '账号只能包含字母、数字和下划线', 
      trigger: 'blur' 
    }
  ],
  userName: [
    { min: 2, max: 20, message: '昵称长度为 2-20 个字符', trigger: 'blur' }
  ],
  userPassword: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, max: 20, message: '密码长度为 6-20 个字符', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, validator: validateConfirmPassword, trigger: 'blur' }
  ],
  agree: [
    { required: true, validator: validateAgree, trigger: 'change' }
  ]
}

// 注册处理
async function handleRegister() {
  // 1. 验证表单
  const valid = await registerFormRef.value.validate().catch(() => false)
  if (!valid) return
  
  try {
    // 2. 显示加载状态
    loading.value = true
    
    // 3. 调用注册 API
    await register({
      userAccount: registerForm.userAccount,
      userPassword: registerForm.userPassword,
      userName: registerForm.userName || undefined,
      gender: registerForm.gender ?? undefined
    })
    
    // 4. 显示成功提示
    ElMessage.success('注册成功！请登录')
    
    // 5. 跳转到登录页
    setTimeout(() => {
      router.push('/login')
    }, 1000)
    
  } catch (error) {
    // 错误已经在 Axios 拦截器中处理
    console.error('注册失败:', error)
  } finally {
    // 6. 恢复按钮状态
    loading.value = false
  }
}

// 跳转到登录页
function goLogin() {
  router.push('/login')
}
</script>

<style scoped>
/* 
 * 注册页面样式（和登录页类似）
 * 主要区别：表单字段更多
 */

.register-page {
  /* 全屏高度 */
  min-height: 100vh;
  
  /* Flexbox 居中 */
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
  
  padding: var(--spacing-lg);
  position: relative;
  overflow: hidden;
}

.register-container {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 480px;  /* 比登录页稍宽（字段更多） */
}

.register-card {
  padding: var(--spacing-xxl);
  box-shadow: var(--color-shadow-xl);
  background: var(--color-bg-secondary);
  backdrop-filter: blur(10px);
  transition: all var(--transition-base);
}

.register-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--color-shadow-xl);
}

/* 装饰背景（和登录页一样） */
.register-decoration {
  position: absolute;
  top: -50%;
  right: -50%;  /* 从右边旋转 */
  width: 200%;
  height: 200%;
  background: radial-gradient(
    circle at 70% 50%,
    rgba(167, 139, 250, 0.08) 0%,  /* 紫色 */
    transparent 50%
  );
  pointer-events: none;
  animation: rotate 30s linear infinite reverse;  /* 反向旋转 */
}

@keyframes rotate {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

/* 响应式 */
@media (max-width: 480px) {
  .register-card {
    padding: var(--spacing-xl);
  }
  
  .register-header h1 {
    font-size: var(--font-size-2xl);
  }
}
</style>

