import { createRouter, createWebHashHistory } from 'vue-router'
import Layout from '../components/Layout.vue'
import Login from '../views/Login.vue'
import Status from '../views/Status.vue'
import NetworkConfig from '../views/NetworkConfig.vue'
import Uart from '../views/Uart.vue'
import Socket from '../views/Socket.vue'
import Mqtt from '../views/Mqtt.vue'
import System from '../views/System.vue'
import Gateway from '../views/Gateway.vue'
import { authCheck } from '../api/services.js'

const routes = [
    {
        path: '/login',
        name: 'login',
        component: Login,
        meta: { public: true }
    },
    {
        path: '/',
        component: Layout,
        children: [
            { path: '', name: 'status', component: Status },
            { path: 'network', name: 'network', component: NetworkConfig },
            { path: 'port/uart', name: 'uart', component: Uart },
            { path: 'comm/Socket', name: 'Socket', component: Socket },
            { path: 'comm/MQTT', name: 'MQTT', component: Mqtt },
            //{ path: 'comm/HLK_CLD', name: 'hlk_cld', component: Cloud },
            { path: 'gateway', name: 'gateway', component: Gateway },
            { path: 'gateway/dtu', redirect: { name: 'gateway' } },
            { path: 'gateway/edge_gw', redirect: { name: 'gateway' } },
            { path: 'system', name: 'system', component: System }
        ]
    }
]

const router = createRouter({
    history: createWebHashHistory(),
    routes
})

router.beforeEach(async (to) => {
    if (to.meta.public) {
        return true
    }
    try {
        await authCheck()
        return true
    } catch (e) {
        return {
            name: 'login',
            query: { redirect: to.fullPath }
        }
    }
})

export default router
