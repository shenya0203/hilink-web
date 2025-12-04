<template>
  <div id="page-container">
    <!-- 顶部导航 -->
    <header class="navbar">
      <div class="top_logo_default">
        <!-- 你的 Logo 图片，这里暂时留空或用文字代替 -->
        <!-- <img src="..." alt="logo" /> -->
      </div>
      <div class="logo_left">
        <h1>工业路由网关</h1>
        <h4>Web 配置管理系统</h4>
      </div>
      <div class="logo_right">
        <div class="right_top">N720</div>
        <div class="right_bottom">
          <span>中文</span> | <span>English</span>
        </div>
      </div>
    </header>

    <div class="containerInner containerInner_have_bottom">
      <!-- 侧边栏 -->
      <aside class="aside">
        <div class="menu-list">
          <div v-for="(item, index) in menuItems" :key="index" class="menu-item">
            
            <!-- 有子菜单的情况 -->
            <div v-if="item.submenu">
              <div 
                class="menu-title" 
                :class="{ 'now-target-folder': isSubmenuActive(item) }"
                @click="toggleMenu(item.name)"
              >
                <div class="folder-title">
                  <span class="arrow"></span>
                  <span>{{ item.label }}</span>
                </div>
              </div>
              <ul class="subMenu" v-show="expandedMenus.includes(item.name) || isSubmenuActive(item)">
                <li v-for="sub in item.submenu" :key="sub.name" class="subMenu-item">
                  <div class="menu-title" :class="{ 'now-target-item': route.name === sub.name }">
                    <div class="link" @click="navigateTo(sub.name)">{{ sub.label }}</div>
                  </div>
                </li>
              </ul>
            </div>

            <!-- 无子菜单的情况 -->
            <div 
                v-else 
                class="menu-title" 
                :class="{ 'now-target-item': route.name === item.name }"
                @click="navigateTo(item.name)"
            >
              {{ item.label }}
            </div>

          </div>
        </div>
      </aside>

      <!-- 主内容区域 -->
      <main class="main">
        <router-view></router-view>
      </main>
    </div>

    <!-- 底部 (根据CSS可能存在) -->
    <div class="footer">
      Copyright © USR IOT
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';

const router = useRouter();
const route = useRoute();
const expandedMenus = ref(['comm', 'port']); // 默认展开

// 菜单配置（根据你的JS文件还原）
const menuItems = [
  { name: 'status', label: '当前状态' },
  { name: 'network', label: '网络' },
  { 
    name: 'port', label: '端口', 
    submenu: [{ name: 'uart', label: '串口' }] 
  },
  { 
    name: 'comm', label: '通信', 
    submenu: [
      { name: 'Socket', label: 'Socket' },
      { name: 'MQTT', label: 'MQTT' },
      { name: 'usr_cld', label: 'USR_CLD' }
    ] 
  },
  { 
    name: 'gateway', label: '网关', 
    submenu: [{ name: 'edge_gw', label: '边缘计算' }] 
  },
  { name: 'system', label: '系统设置' }
];

const navigateTo = (name) => {
  router.push({ name });
};

const toggleMenu = (name) => {
  const idx = expandedMenus.value.indexOf(name);
  if (idx > -1) expandedMenus.value.splice(idx, 1);
  else expandedMenus.value.push(name);
};

const isSubmenuActive = (item) => {
  if (!item.submenu) return false;
  return item.submenu.some(sub => sub.name === route.name);
};
</script>