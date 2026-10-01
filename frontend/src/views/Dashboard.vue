<template>
  <section class="page">
    <header class="page-head">
      <div>
        <h2>运营概览</h2>
        <p class="page-desc">汇总各业务模块的关键指标，先看总量再看异常。</p>
      </div>
    </header>
    <div class="stat-row">
      <article v-for="card in cards" :key="card.label" class="stat-card">
        <span class="stat-label">{{ card.label }}</span>
        <strong class="stat-value">{{ card.value }}</strong>
      </article>
    </div>
    <table class="data-table">
      <thead>
        <tr><th>业务模块</th><th>今日新增</th><th>待处理</th><th>异常量</th></tr>
      </thead>
      <tbody>
        <tr v-for="row in moduleRows" :key="row.name">
          <td>{{ row.name }}</td>
          <td>{{ row.created }}</td>
          <td>{{ row.pending }}</td>
          <td>{{ row.abnormal }}</td>
        </tr>
      </tbody>
    </table>
  </section>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'

import { fetchJson } from '@/api/client'

type Overview = {
  cards: { label: string; value: number }[]
  modules: { name: string; key?: string; created: number; pending: number; abnormal: number }[]
}

const cards = ref<Overview['cards']>([])
const moduleRows = ref<Overview['modules']>([])

// 接口不可达时展示归档版运营概览的空骨架：4 张卡片、18 个业务模块，与正常返回结构对齐
const FALLBACK_CARDS: Overview['cards'] = [
  { label: '业务模块', value: 0 },
  { label: '今日新增', value: 0 },
  { label: '待处理', value: 0 },
  { label: '异常量', value: 0 },
]
const FALLBACK_MODULES: Overview['modules'] = [
  '管段档案', '检查井', '阀门井室', '泵站设施', '巡查任务', '缺陷登记',
  '内窥检测', '修复施工', '压力监测', '流量监测', '泄漏排查', '清淤疏浚',
  '养护材料', '养护机械', '占道许可', '公众诉求', '养护资金', '管网档案',
].map((name) => ({ name, created: 0, pending: 0, abnormal: 0 }))

onMounted(async () => {
  try {
    const payload = await fetchJson<Overview>('/api/overview')
    cards.value = payload.cards
    moduleRows.value = payload.modules
  } catch {
    cards.value = FALLBACK_CARDS
    moduleRows.value = FALLBACK_MODULES
  }
})
</script>
