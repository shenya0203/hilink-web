/**
 * 国际化(i18n)模块
 * 支持中英文切换，可扩展支持其他语言
 */
import { ref, computed } from 'vue'
import zhCN from './locales/zh-CN.js'
import enUS from './locales/en-US.js'

// 支持的语言列表
const locales = {
    'zh-CN': zhCN,
    'en-US': enUS
}

// 语言显示名称
export const languageNames = {
    'zh-CN': '中文',
    'en-US': 'English'
}

// 当前语言 (从 localStorage 读取，默认中文)
const currentLocale = ref(localStorage.getItem('locale') || 'zh-CN')

// 获取当前语言包
const messages = computed(() => locales[currentLocale.value] || locales['zh-CN'])

/**
 * 翻译函数
 * @param {string} key - 翻译键，支持点号分隔的嵌套路径，如 'menu.status'
 * @param {object} params - 可选的插值参数，如 { name: 'John' } 用于 'Hello, {name}'
 * @returns {string} 翻译后的文本，如果未找到则返回键名
 */
export const t = (key, params = {}) => {
    const keys = key.split('.')
    let value = messages.value

    for (const k of keys) {
        if (value && typeof value === 'object' && k in value) {
            value = value[k]
        } else {
            // 未找到翻译，返回键名
            console.warn(`[i18n] Missing translation for key: ${key}`)
            return key
        }
    }

    // 处理插值参数
    if (typeof value === 'string' && Object.keys(params).length > 0) {
        return value.replace(/\{(\w+)\}/g, (match, name) => {
            return params[name] !== undefined ? params[name] : match
        })
    }

    return value
}

/**
 * 切换语言
 * @param {string} locale - 语言代码，如 'zh-CN' 或 'en-US'
 */
export const setLocale = (locale) => {
    if (locales[locale]) {
        currentLocale.value = locale
        localStorage.setItem('locale', locale)
        // 更新 HTML lang 属性
        document.documentElement.lang = locale
    } else {
        console.warn(`[i18n] Unsupported locale: ${locale}`)
    }
}

/**
 * 获取当前语言代码
 * @returns {string} 当前语言代码
 */
export const getLocale = () => currentLocale.value

/**
 * 获取所有支持的语言列表
 * @returns {Array} 语言列表，包含 code 和 name
 */
export const getSupportedLocales = () => {
    return Object.keys(locales).map(code => ({
        code,
        name: languageNames[code] || code
    }))
}

/**
 * 添加新语言支持
 * @param {string} code - 语言代码
 * @param {object} translations - 翻译对象
 * @param {string} name - 语言显示名称
 */
export const addLocale = (code, translations, name) => {
    locales[code] = translations
    languageNames[code] = name || code
}

// 导出响应式的当前语言
export { currentLocale }

// 默认导出
export default {
    t,
    setLocale,
    getLocale,
    getSupportedLocales,
    addLocale,
    currentLocale,
    languageNames
}
