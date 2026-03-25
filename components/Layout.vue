<template>
  <div id="page-container">
    <!-- 顶部导航 -->
    <header class="navbar">
      <div class="top_logo_default">
        <!-- 你的 Logo 图片，这里暂时留空或用文字代替 -->
        <!-- <img src="..." alt="logo" /> -->
      </div>
      <div class="logo_left">
        <h1>{{ t('navbar.title') }}</h1>
        <h4>{{ t('navbar.subtitle') }}</h4>
      </div>
      <div class="logo_right">
        <div class="right_top">{{ APP_DEVICE_MODEL }}</div>
        <div class="right_bottom language-switcher">
          <span 
            :class="{ active: locale === 'zh-CN' }" 
            @click="setLocale('zh-CN')"
          >中文</span>
          <span class="divider">|</span>
          <span 
            :class="{ active: locale === 'en-US' }" 
            @click="setLocale('en-US')"
          >English</span>
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
                  <span>{{ t(item.labelKey) }}</span>
                </div>
              </div>
              <ul class="subMenu" v-show="expandedMenus.includes(item.name) || isSubmenuActive(item)">
                <li v-for="sub in item.submenu" :key="sub.name" class="subMenu-item">
                  <div class="menu-title" :class="{ 'now-target-item': route.name === sub.name }">
                    <div class="link" @click="navigateTo(sub.name)">{{ t(sub.labelKey) }}</div>
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
              {{ t(item.labelKey) }}
            </div>

          </div>
        </div>
      </aside>

      <!-- 主内容区域 -->
      <main class="main">
        <router-view :key="locale"></router-view>
      </main>
    </div>

    <!-- 底部 (根据CSS可能存在) -->
    <div class="footer">
      {{ t('footer.copyright') }}
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useI18n } from '../i18n/useI18n.js';
import { APP_DEVICE_MODEL } from '../config/features.js';

const router = useRouter();
const route = useRoute();
const expandedMenus = ref(['comm', 'port']); // 默认展开

// 使用 i18n
const { t, locale, setLocale } = useI18n();

// 菜单配置（使用翻译键）
const menuItems = computed(() => [
  { name: 'status', labelKey: 'menu.status' },
  { name: 'network', labelKey: 'menu.network' },
  { 
    name: 'port', labelKey: 'menu.port', 
    submenu: [{ name: 'uart', labelKey: 'menu.uart' }] 
  },
  { 
    name: 'comm', labelKey: 'menu.comm', 
    submenu: [
      { name: 'Socket', labelKey: 'menu.socket' },
      { name: 'MQTT', labelKey: 'menu.mqtt' },
      { name: 'hlk_cld', labelKey: 'menu.usrCld' }
    ] 
  },
  { 
    name: 'gateway', labelKey: 'menu.gateway', 
    submenu: [{ name: 'edge_gw', labelKey: 'menu.edgeCompute' }] 
  },
  { name: 'system', labelKey: 'menu.system' }
]);

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

<style scoped>
/* 语言切换器样式 */
.language-switcher {
  cursor: pointer;
  user-select: none;
}

.language-switcher span {
  transition: color 0.2s, opacity 0.2s;
}

.language-switcher span:not(.divider):hover {
  color: #66b3ff;
}

.language-switcher span.active {
  color: #ffcc00;
  font-weight: bold;
}

.language-switcher .divider {
  margin: 0 5px;
  color: #999;
}
</style>