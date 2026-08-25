import axios, {AxiosInstance} from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {CONFIG} from '../config';
import {randomUUID} from '../utils/uuid';

const TOKEN_KEY = 'mb_session_token';

let authToken: string | null = null;

export async function loadToken(): Promise<string | null> {
  authToken = await AsyncStorage.getItem(TOKEN_KEY);
  return authToken;
}

export async function saveToken(token: string): Promise<void> {
  authToken = token;
  await AsyncStorage.setItem(TOKEN_KEY, token);
}

export async function clearToken(): Promise<void> {
  authToken = null;
  await AsyncStorage.removeItem(TOKEN_KEY);
}

// Для нативных компонентов (например, <Image> с авторизованным URL)
export async function getToken(): Promise<string | null> {
  if (!authToken) {
    await loadToken();
  }
  return authToken;
}

export const api: AxiosInstance = axios.create({
  baseURL: `${CONFIG.BACKEND_URL}`,
  timeout: 8000,
});

api.interceptors.request.use(async config => {
  if (!authToken) {
    await loadToken();
  }
  if (authToken) {
    config.headers.Authorization = `Bearer ${authToken}`;
  }
  // Идемпотентность мутаций (ТЗ 6.4): повтор при плохой связи не дважды списывает
  if (config.method && ['post', 'patch', 'put', 'delete'].includes(config.method)) {
    config.headers['X-Idempotency-Key'] = randomUUID();
  }
  return config;
});
