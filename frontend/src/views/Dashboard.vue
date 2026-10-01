<template>
  <section class="page">
    <header class="page-head">
      <div>
        <h2>运营概览</h2>
        <p class="page-desc">汇总各业务模块的关键指标，先看总量再看异常。</p>
        <p v-if="dataVersion" class="page-desc">存量数据按归档版「{{ dataVersion }}」回填</p>
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
  modules: { name: string; created: number; pending: number; abnormal: number }[]
  data_version?: string
}

const cards = ref<Overview['cards']>([])
const moduleRows = ref<Overview['modules']>([])
const dataVersion = ref('')

onMounted(async () => {
  try {
    const payload = await fetchJson<Overview>('/api/overview')
    cards.value = payload.cards
    moduleRows.value = payload.modules
    dataVersion.value = payload.data_version ?? ''
  } catch {
    cards.value = [{"label": "业务模块", "value": 0}, {"label": "今日新增", "value": 0}]
    moduleRows.value = [{"name": "管段档案", "created": 0, "pending": 0, "abnormal": 0}, {"name": "检查井", "created": 0, "pending": 0, "abnormal": 0}, {"name": "阀门井室", "created": 0, "pending": 0, "abnormal": 0}, {"name": "泵站设施", "created": 0, "pending": 0, "abnormal": 0}, {"name": "巡查任务", "created": 0, "pending": 0, "abnormal": 0}, {"name": "缺陷登记", "created": 0, "pending": 0, "abnormal": 0}, {"name": "内窥检测", "created": 0, "pending": 0, "abnormal": 0}, {"name": "修复施工", "created": 0, "pending": 0, "abnormal": 0}, {"name": "压力监测", "created": 0, "pending": 0, "abnormal": 0}, {"name": "流量监测", "created": 0, "pending": 0, "abnormal": 0}, {"name": "泄漏排查", "created": 0, "pending": 0, "abnormal": 0}, {"name": "清淤疏浚", "created": 0, "pending": 0, "abnormal": 0}, {"name": "养护材料", "created": 0, "pending": 0, "abnormal": 0}, {"name": "养护机械", "created": 0, "pending": 0, "abnormal": 0}, {"name": "占道许可", "created": 0, "pending": 0, "abnormal": 0}, {"name": "公众诉求", "created": 0, "pending": 0, "abnormal": 0}, {"name": "养护资金", "created": 0, "pending": 0, "abnormal": 0}, {"name": "管网档案", "created": 0, "pending": 0, "abnormal": 0}]
  }
})
</script>
