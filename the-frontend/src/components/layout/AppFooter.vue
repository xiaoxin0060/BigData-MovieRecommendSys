<template>
  <footer class="app-footer">
    <div class="container">
      <div class="footer-content">
        <div class="footer-info">
          <p class="footer-text">© 2025 电影推荐系统 - 基于 Vue 3 + Express + Spark</p>
          <p class="footer-tech text-sm text-tertiary mt-xs">
            Made with ❤️ using Vue 3 · Element Plus · Node.js
          </p>
        </div>
        
        <div class="footer-links">
          <a href="https://github.com" target="_blank" rel="noopener" class="footer-link">
            <el-icon><Link /></el-icon>
            <span>GitHub</span>
          </a>
          <a href="https://vuejs.org" target="_blank" rel="noopener" class="footer-link">
            <el-icon><Document /></el-icon>
            <span>Vue 文档</span>
          </a>
        </div>
      </div>
    </div>
  </footer>
</template>

<script setup>
// Footer 组件逻辑
</script>

<style scoped>
.app-footer {
  background-color: var(--color-bg-secondary);
  border-top: 1px solid var(--color-border);
  padding: var(--spacing-xl) 0;
  margin-top: auto;
}

.footer-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--spacing-lg);
}

.footer-info {
  flex: 1;
}

.footer-text {
  color: var(--color-text-primary);
  font-size: var(--font-size-sm);
  font-weight: var(--font-weight-medium);
}

.footer-tech {
  margin-top: var(--spacing-xs);
}

.footer-links {
  display: flex;
  gap: var(--spacing-lg);
}

.footer-link {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
  text-decoration: none;
  transition: color var(--transition-fast);
}

.footer-link:hover {
  color: var(--color-accent-blue);
}

/* 响应式 */
@media (max-width: 768px) {
  .footer-content {
    flex-direction: column;
    text-align: center;
  }
  
  .footer-links {
    justify-content: center;
  }
}
</style>

