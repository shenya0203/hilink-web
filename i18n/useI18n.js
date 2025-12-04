/**
 * i18n Composable for Vue 3
 * 在组件中使用: const { t, locale, setLocale, supportedLocales } = useI18n()
 */
import { computed } from 'vue'
import i18n, { t, setLocale, getLocale, getSupportedLocales, currentLocale } from './index.js'

export function useI18n() {
    // 当前语言代码
    const locale = computed(() => currentLocale.value)

    // 是否为中文
    const isChinese = computed(() => currentLocale.value === 'zh-CN')

    // 是否为英文
    const isEnglish = computed(() => currentLocale.value === 'en-US')

    // 支持的语言列表
    const supportedLocales = computed(() => getSupportedLocales())

    // 切换到中文
    const switchToChinese = () => setLocale('zh-CN')

    // 切换到英文
    const switchToEnglish = () => setLocale('en-US')

    // 切换语言 (在中英文之间切换)
    const toggleLocale = () => {
        if (currentLocale.value === 'zh-CN') {
            setLocale('en-US')
        } else {
            setLocale('zh-CN')
        }
    }

    return {
        // 翻译函数
        t,

        // 当前语言代码
        locale,

        // 设置语言
        setLocale,

        // 获取当前语言
        getLocale,

        // 支持的语言列表
        supportedLocales,

        // 快捷方法
        isChinese,
        isEnglish,
        switchToChinese,
        switchToEnglish,
        toggleLocale,

        // 原始 i18n 对象
        i18n
    }
}

export { t, setLocale, getLocale, getSupportedLocales, currentLocale }
export default useI18n
