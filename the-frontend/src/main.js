import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'

/**
 * ===== 样式导入顺序（非常重要！） =====
 * 1. 主题变量 -> 2. Reset -> 3. 工具类 -> 4. Element 覆盖
 */
import './styles/theme-dark.css'         // 1. 深色主题变量（CSS Variables）
import './styles/reset.css'              // 2. 现代化 CSS Reset
import './styles/utilities.css'          // 3. 工具类（Utility Classes）
import './styles/element-theme-dark.css' // 4. Element Plus 深色主题覆盖

import App from './App.vue'
import router from './router'

// 创建 Vue 应用实例
const app = createApp(App)

// 注册 Pinia（状态管理）
app.use(createPinia())

// 注册 Vue Router（路由）
app.use(router)

// 注册 Element Plus（UI 组件库）
app.use(ElementPlus)

// 注册所有 Element Plus 图标为全局组件
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(key, component)
}

// 挂载应用到 DOM
app.mount('#app')
