<template>
  <div id="app" class="app-wrapper">
    <!-- 全局导航栏（登录/注册页不显示） -->
    <AppHeader v-if="!isAuthPage" />
    
    <!-- 路由出口：不同页面的内容显示在这里 -->
    <main class="app-main">
      <router-view v-slot="{ Component }">
        <transition name="fade" mode="out-in">
          <component :is="Component" />
        </transition>
      </router-view>
    </main>
    
    <!-- 全局底部（登录/注册页不显示） -->
    <AppFooter v-if="!isAuthPage" />
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/components/layout/AppHeader.vue'
import AppFooter from '@/components/layout/AppFooter.vue'

const route = useRoute()

// 判断是否是登录/注册页（不显示导航栏和底部）
const isAuthPage = computed(() => {
  return ['Login', 'Register'].includes(route.name)
})
</script>

<style>
/* App 根组件样式 */
.app-wrapper {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background-color: var(--color-bg-primary);
}

.app-main {
  flex: 1;
  width: 100%;
}

/* 页面切换动画 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity var(--transition-base);
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
