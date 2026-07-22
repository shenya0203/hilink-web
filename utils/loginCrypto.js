/**
 * 登录 RSA-OAEP 加密（Web Crypto，无第三方库）
 */

function pemToArrayBuffer(pem) {
    const b64 = pem
        .replace(/-----BEGIN PUBLIC KEY-----/g, '')
        .replace(/-----END PUBLIC KEY-----/g, '')
        .replace(/\s+/g, '')
    const raw = atob(b64)
    const buf = new Uint8Array(raw.length)
    for (let i = 0; i < raw.length; i++) {
        buf[i] = raw.charCodeAt(i)
    }
    return buf.buffer
}

function bufToBase64(buf) {
    const bytes = new Uint8Array(buf)
    let s = ''
    for (let i = 0; i < bytes.length; i++) {
        s += String.fromCharCode(bytes[i])
    }
    return btoa(s)
}

function randomNonce(bytes = 16) {
    const arr = new Uint8Array(bytes)
    crypto.getRandomValues(arr)
    return Array.from(arr, (b) => b.toString(16).padStart(2, '0')).join('')
}

export async function importLoginPublicKey(pem) {
    return crypto.subtle.importKey(
        'spki',
        pemToArrayBuffer(pem),
        { name: 'RSA-OAEP', hash: 'SHA-256' },
        false,
        ['encrypt']
    )
}

/**
 * @returns {{ password_enc: string, nonce: string }}
 */
export async function encryptLoginPassword(password, pubkeyPem) {
    const key = await importLoginPublicKey(pubkeyPem)
    const nonce = randomNonce(16)
    const ts = Math.floor(Date.now() / 1000)
    const plain = new TextEncoder().encode(`${password}\n${nonce}\n${ts}`)
    const cipher = await crypto.subtle.encrypt({ name: 'RSA-OAEP' }, key, plain)
    return {
        password_enc: bufToBase64(cipher),
        nonce
    }
}
