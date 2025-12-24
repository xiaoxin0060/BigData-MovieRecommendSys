<template>
  <div ref="container" class="echart" :style="{ height, width: '100%' }" />
</template>

<script setup>
import * as echarts from 'echarts'
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

const props = defineProps({
  option: { type: Object, required: true },
  height: { type: String, default: '260px' }
})

const container = ref(null)
let chart = null
let ro = null

function render() {
  if (!chart) return
  chart.setOption(props.option, { notMerge: true, lazyUpdate: true })
}

onMounted(() => {
  if (!container.value) return
  chart = echarts.init(container.value, null, { renderer: 'canvas' })
  render()

  ro = new ResizeObserver(() => {
    if (chart) chart.resize()
  })
  ro.observe(container.value)
})

onBeforeUnmount(() => {
  if (ro && container.value) ro.unobserve(container.value)
  ro = null
  if (chart) chart.dispose()
  chart = null
})

watch(
  () => props.option,
  () => render(),
  { deep: true }
)
</script>

<style scoped>
.echart {
  min-height: 120px;
}
</style>

