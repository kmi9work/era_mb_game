import React, {createContext, useContext, useEffect, useState} from 'react';
import {loadToken, saveToken, clearToken, api} from '../api/client';

interface PlayerInfo {
  id: number;
  name: string;
  identificator: string;
  guild_id: number | null;
}

interface AuthContextValue {
  player: PlayerInfo | null;
  loading: boolean;
  signInWithQr: (qrString: string) => Promise<{ok: boolean; error?: string}>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue>({
  player: null,
  loading: true,
  signInWithQr: async () => ({ok: false}),
  signOut: async () => {},
});

export function AuthProvider({children}: {children: React.ReactNode}) {
  const [player, setPlayer] = useState<PlayerInfo | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadToken()
      .then(token => {
        // Токен без серверной валидации живёт до первой ошибки 401 (см. api interceptor)
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  const signInWithQr = async (qrString: string) => {
    try {
      const res = await api.post('/auth/login', {
        qr_string: qrString,
        device_info: {platform: 'mobile'},
      });
      await saveToken(res.data.token);
      setPlayer(res.data.player);
      return {ok: true};
    } catch (e: any) {
      const message = e?.response?.data?.error ?? 'Нет сети. Проверьте соединение';
      return {ok: false, error: message};
    }
  };

  const signOut = async () => {
    await clearToken();
    setPlayer(null);
  };

  return (
    <AuthContext.Provider value={{player, loading, signInWithQr, signOut}}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
