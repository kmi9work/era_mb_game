/**
 * Конфигурация клиента. BACKEND_URL указывает на era_mobile_api.
 *
 * Прод: https://era-mb-game.igroteh.su — выделенный домен мобильного API
 * (nginx -> puma :3001 на epoha-сервере, Let's Encrypt, без Basic Auth).
 * REST:   /api/v1/... , /auth/login
 * WS:     /cable (ActionCable, токен передаётся query-параметром)
 */
const DEV_BASE = 'http://10.0.2.2:3001'; // эмулятор Android; реальное устройство в dev: http://<ip-dev-машины>:3001

export const CONFIG = {
  BACKEND_URL: __DEV__ ? DEV_BASE : 'https://era-mb-game.igroteh.su',
  WEBSOCKET_URL: __DEV__
    ? 'ws://10.0.2.2:3001/cable'
    : 'wss://era-mb-game.igroteh.su/cable',
};
