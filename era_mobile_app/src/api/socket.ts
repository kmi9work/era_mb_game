import {CONFIG} from '../config';
import AsyncStorage from '@react-native-async-storage/async-storage';

type Handler = (payload: any) => void;

let socket: WebSocket | null = null;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let pingTimer: ReturnType<typeof setInterval> | null = null;
const handlers = new Map<string, Set<Handler>>();

/**
 * Подключение к ActionCable-каналу игрока (лобби + торговые сессии, FR-9).
 * Автопереподключение с экспоненциальной задержкой; офлайн — баннер (FR-41).
 */
export async function connectPlayerSocket(onStatus?: (online: boolean) => void): Promise<void> {
  const token = await AsyncStorage.getItem('mb_session_token');
  if (!token || socket) {
    return;
  }

  const url = `${CONFIG.WEBSOCKET_URL}?token=${encodeURIComponent(token)}`;

  try {
    socket = new WebSocket(url);
  } catch {
    scheduleReconnect(onStatus);
    return;
  }

  socket.onopen = () => {
    onStatus?.(true);
    // subscribe to PlayerChannel
    socket?.send(
      JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({channel: 'PlayerChannel'}),
      }),
    );
    // keep-alive пинг каждые 20 сек
    pingTimer = setInterval(() => {
      try {
        socket?.send(JSON.stringify({command: 'ping'}));
      } catch {}
    }, 20000);
  };

  socket.onmessage = event => {
    try {
      const msg = JSON.parse(event.data as string);
      if (msg.type === 'reject_subscription' || msg.type === 'disconnect') {
        return;
      }
      const payload = msg.message;
      if (!payload?.event) return;
      handlers.get(payload.event)?.forEach(h => h(payload));
      handlers.get('*')?.forEach(h => h(payload));
    } catch {
      // ignore malformed frames
    }
  };

  socket.onclose = () => {
    cleanup();
    onStatus?.(false);
    scheduleReconnect(onStatus);
  };

  socket.onerror = () => {
    cleanup();
    onStatus?.(false);
  };
}

function cleanup() {
  if (pingTimer) clearInterval(pingTimer);
  pingTimer = null;
  socket = null;
}

function scheduleReconnect(onStatus?: (online: boolean) => void) {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connectPlayerSocket(onStatus).catch(() => scheduleReconnect(onStatus));
  }, 3000);
}

export function disconnectPlayerSocket(): void {
  if (reconnectTimer) clearTimeout(reconnectTimer);
  reconnectTimer = null;
  if (pingTimer) clearInterval(pingTimer);
  pingTimer = null;
  socket?.close();
  socket = null;
}

export function onSocketEvent(event: string, handler: Handler): () => void {
  if (!handlers.has(event)) handlers.set(event, new Set());
  handlers.get(event)!.add(handler);
  return () => handlers.get(event)?.delete(handler);
}
