/**
 * 异步重试：共尝试 times 轮，失败后 delayMs 再试
 */
export async function withRetry(fn, { times = 3, delayMs = 1500, onRetry } = {}) {
  let lastError
  for (let attempt = 1; attempt <= times; attempt++) {
    try {
      return await fn(attempt)
    } catch (err) {
      lastError = err
      if (attempt >= times) break
      if (typeof onRetry === 'function') {
        onRetry(attempt, times, err)
      }
      await new Promise((resolve) => setTimeout(resolve, delayMs))
    }
  }
  throw lastError
}
