import { createRouter, createWebHashHistory } from 'vue-router';
import Layout from '../components/Layout.vue';
import Status from '../views/Status.vue';
import NetworkConfig from '../views/NetworkConfig.vue';
import Uart from '../views/Uart.vue';
import Socket from '../views/Socket.vue';
import Mqtt from '../views/Mqtt.vue';
import System from '../views/System.vue';
import EdgeCompute from '../views/EdgeCompute.vue';
import Cloud from '../views/Cloud.vue';

// 简单的占位组件
const Placeholder = { template: '<div class="main"><h3>功能开发中...</h3></div>' };

const routes = [
    {
        path: '/',
        component: Layout,
        children: [
            { path: '', name: 'status', component: Status }, // 默认首页
            { path: 'network', name: 'network', component: NetworkConfig },
            { path: 'port/uart', name: 'uart', component: Uart },
            { path: 'comm/Socket', name: 'Socket', component: Socket },
            { path: 'comm/MQTT', name: 'MQTT', component: Mqtt },
            { path: 'comm/USR_CLD', name: 'usr_cld', component: Cloud },
            { path: 'gateway/edge_gw', name: 'edge_gw', component: EdgeCompute },
            { path: 'system', name: 'system', component: System }
        ]
    }
];

const router = createRouter({
    history: createWebHashHistory(),
    routes
});

export default router;