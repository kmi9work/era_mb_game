/**
 * Конфигурация клиента. BACKEND_URL указывает на era_mobile_api.
 * В проде шлюз epoha.igroteh.su с Basic Auth — учтено в api client.
 */
export const CONFIG = {
  // dev: машина разработчика по Wi-Fi площадки; эмулятор: 10.0.2.2
  BACKEND_URL: __DEV__ ? 'http://10.0.2.2:3000' : 'https://epoha.igroteh.su/mobile_api',
  BASIC_AUTH: {
    username: '',
    password: '',
  },
  WEBSOCKET_URL: __DEV__ ? 'ws://10.0.2.2:3000/cable' : 'wss://epoha.igroteh.su/mobile_api/cable',
};
