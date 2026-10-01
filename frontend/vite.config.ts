import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

// 代理目标按优先级取值：
// 1. 启动时的 VITE_PROXY_TARGET 环境变量（临时换端口/探针用）；
// 2. scripts/setup.sh 生成的 frontend/.env.local（统一初始化流程写入，不手改代码）；
// 3. .env.development 里的 VITE_PROXY_TARGET；
// 4. 兜底本地后端地址。
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const proxyTarget =
    process.env.VITE_PROXY_TARGET ??
    env.VITE_PROXY_TARGET ??
    'http://127.0.0.1:8000'

  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },
    server: {
      host: '127.0.0.1',
      port: 5173,
      // 关掉自动打开页面：起服务时只打印地址，不拉起浏览器
      open: false,
      strictPort: false,
      proxy: {
        '/api': {
          target: proxyTarget,
          changeOrigin: true,
        },
      },
    },
    build: {
      outDir: 'dist',
      sourcemap: false,
    },
  }
})
