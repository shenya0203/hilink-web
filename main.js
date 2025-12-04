import { createApp } from 'vue'
import App from './APp.vue'
import router from './router/index.js'
import './src/app.css'

const app = createApp(App)
app.use(router)
app.mount('#app')