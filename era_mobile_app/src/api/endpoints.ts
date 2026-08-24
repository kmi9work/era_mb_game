import {api} from './client';

// ─── Лобби (FR-6..FR-9) ─────────────────────────────────────────────────────
export const getLobby = () => api.get('/api/v1/lobby').then(r => r.data);

// ─── Торговля (FR-11..FR-17) ────────────────────────────────────────────────
export const createTradeSession = (partnerPlayerId: number) =>
  api.post('/api/v1/trade_sessions', {partner_player_id: partnerPlayerId}).then(r => r.data);

export const getTradeSession = (id: number) =>
  api.get(`/api/v1/trade_sessions/${id}`).then(r => r.data);

export const updateOffer = (
  id: number,
  offer: {money?: number; resources?: {identificator: string; count: number; name?: string}[]; cards?: number[]},
) => api.post(`/api/v1/trade_sessions/${id}/offer`, offer).then(r => r.data);

export const confirmTrade = (id: number) =>
  api.post(`/api/v1/trade_sessions/${id}/confirm`).then(r => r.data);

export const cancelTrade = (id: number) =>
  api.delete(`/api/v1/trade_sessions/${id}`).then(r => r.data);

// ─── Предприятия (FR-19..FR-24) ─────────────────────────────────────────────
export const getPlants = () => api.get('/api/v1/plants').then(r => r.data);
export const producePlant = (id: number) =>
  api.post(`/api/v1/plants/${id}/produce`).then(r => r.data);
export const produceAllPlants = () =>
  api.post('/api/v1/plants/produce_all').then(r => r.data);
export const sellPlant = (id: number) =>
  api.post(`/api/v1/plants/${id}/sell`).then(r => r.data);
export const upgradePlant = (id: number, toLevel: number) =>
  api.patch(`/api/v1/plants/${id}`, {to_level: toLevel}).then(r => r.data);

// ─── Караваны (FR-25..FR-31) ────────────────────────────────────────────────
export const getCountries = () => api.get('/api/v1/countries').then(r => r.data);
export const getCaravans = () => api.get('/api/v1/caravans').then(r => r.data);
export const sendCaravan = (payload: {
  country_id: number;
  sell_items: {identificator: string; name: string; count: number}[];
  buy_items: {identificator: string; name: string; count: number}[];
  use_contraband: boolean;
}) => api.post('/api/v1/caravans', payload).then(r => r.data);

// ─── Политдействия (FR-32..FR-34) ───────────────────────────────────────────
export const getPoliticalActions = () =>
  api.get('/api/v1/political_actions').then(r => r.data);
export const performPoliticalAction = (id: number) =>
  api.post(`/api/v1/political_actions/${id}/perform`).then(r => r.data);

// ─── Гильдия / история / уведомления (FR-35..FR-39) ─────────────────────────
export const getGuild = () => api.get('/api/v1/guild').then(r => r.data);
export const getOperations = (filters?: {kind?: string; year?: number}) =>
  api.get('/api/v1/operations', {params: filters}).then(r => r.data);
export const getNotifications = () =>
  api.get('/api/v1/notifications').then(r => r.data);
export const markNotificationsRead = () =>
  api.post('/api/v1/notifications/read').then(r => r.data);

// ─── Push (FR-38) ────────────────────────────────────────────────────────────
export const registerPushToken = (platform: 'fcm' | 'apns', token: string) =>
  api.post('/api/v1/push_tokens', {platform, token}).then(r => r.data);

// ─── Вход по QR (FR-2..FR-5) ────────────────────────────────────────────────
export const loginWithQr = (qrString: string, deviceInfo: object) =>
  api.post('/auth/login', {qr_string: qrString, device_info: deviceInfo}).then(r => r.data);
