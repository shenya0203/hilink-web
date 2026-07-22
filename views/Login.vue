<template>
  <div class="login-page">
    <form class="login-card" @submit.prevent="onSubmit">
      <h1>{{ t('login.title') }}</h1>
      <p class="subtitle">{{ t('login.subtitle') }}</p>

      <div class="form-group">
        <label>{{ t('login.username') }}</label>
        <input v-model="username" type="text" autocomplete="username" required />
      </div>
      <div class="form-group">
        <label>{{ t('login.password') }}</label>
        <input v-model="password" type="password" autocomplete="current-password" required />
      </div>

      <p v-if="errorMsg" class="error">{{ errorMsg }}</p>

      <button type="submit" class="btn-login" :disabled="loading">
        {{ loading ? t('login.loggingIn') : t('login.submit') }}
      </button>
    </form>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useI18n } from '../i18n/useI18n.js'
import { fetchLoginPubkey, login } from '../api/services.js'
import { encryptLoginPassword } from '../utils/loginCrypto.js'

const { t } = useI18n()
const router = useRouter()
const route = useRoute()

const username = ref('admin')
const password = ref('')
const loading = ref(false)
const errorMsg = ref('')

const onSubmit = async () => {
  errorMsg.value = ''
  loading.value = true
  try {
    const pubkey = await fetchLoginPubkey()
    const { password_enc, nonce } = await encryptLoginPassword(password.value, pubkey)
    await login(username.value, password_enc, nonce)
    password.value = ''
    const redirect = route.query.redirect || '/'
    router.replace(typeof redirect === 'string' ? redirect : '/')
  } catch (err) {
    const status = err.response && err.response.status
    const data = err.response && err.response.data
    if (status === 429) {
      const sec = (data && data.retry_after) || 600
      const min = Math.ceil(sec / 60)
      errorMsg.value = t('login.locked', { minutes: min })
    } else {
      errorMsg.value = t('login.invalid')
    }
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(160deg, #003366 0%, #001a33 55%, #002244 100%);
  padding: 24px;
}

.login-card {
  width: 100%;
  max-width: 380px;
  background: #fff;
  border-radius: 8px;
  padding: 32px 28px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.25);
}

.login-card h1 {
  margin: 0 0 8px;
  font-size: 22px;
  color: #003366;
}

.subtitle {
  margin: 0 0 24px;
  color: #666;
  font-size: 13px;
}

.form-group {
  margin-bottom: 16px;
}

.form-group label {
  display: block;
  margin-bottom: 6px;
  font-size: 13px;
  color: #333;
}

.form-group input {
  width: 100%;
  box-sizing: border-box;
  padding: 10px 12px;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 14px;
}

.form-group input:focus {
  outline: none;
  border-color: #0066cc;
  box-shadow: 0 0 0 2px rgba(0, 102, 204, 0.15);
}

.error {
  color: #c0392b;
  font-size: 13px;
  margin: 0 0 12px;
}

.btn-login {
  width: 100%;
  padding: 10px 16px;
  background: #0066cc;
  color: #fff;
  border: none;
  border-radius: 4px;
  font-size: 15px;
  cursor: pointer;
}

.btn-login:hover:not(:disabled) {
  background: #0055aa;
}

.btn-login:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}
</style>
