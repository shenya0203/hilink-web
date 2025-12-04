import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { getProxyConfig } from './config/auth'

// 获取代理配置（包含 Basic Auth）
const proxyConfig = getProxyConfig()
const proxyTarget = 'http://192.168.2.177'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  server: {
    // 默认启动端口，可以根据需要修改
    port: 5173, 
    // 配置代理，解决开发环境跨域问题
    proxy: {
      // 匹配所有 /download_flex.cgi 请求
      '/download_flex.cgi': {
        target: proxyTarget,
        ...proxyConfig
      },
      // 匹配所有 /download_nv.cgi 请求
      '/download_nv.cgi': {
        target: proxyTarget,
        ...proxyConfig
      },
      // 匹配所有 /update_nv.cgi 请求（POST）
      '/update_nv.cgi': {
        target: proxyTarget,
        ...proxyConfig
      },
      // 匹配所有 /update_flex.cgi 请求（POST）
      '/update_flex.cgi': {
        target: proxyTarget,
        ...proxyConfig
      }
    }
  }
})
