import React, {useEffect, useState} from 'react';
import {View, Text, StyleSheet, Image} from 'react-native';
// Яркость экрана: нативный модуль подключается на этапе нативной сборки (v2);
// в каркасе не используем сторонних пакетов.
import {colors, typography, spacing} from '../theme';
import {useAuth} from '../auth/AuthContext';
import {getToken} from '../api/client';
import {CONFIG} from '../config';

/**
 * FR-10: персональный QR — статичный, полноэкранный режим, максимальная яркость.
 * PNG генерирует бэкенд (GET /qr_codes/:id.png, rqrcode), строка — в формате
 * era_front /players. Нативные зависимости не нужны.
 */
export function MyQrScreen() {
  const {player} = useAuth();
  const [source, setSource] = useState<{uri: string; headers: Record<string, string>} | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!player?.id) {
        return;
      }
      const token = await getToken();
      if (!token) {
        return;
      }
      // ts=... ломает кэш: идентификатор мог смениться мастером в era_front
      setSource({
        uri: `${CONFIG.BACKEND_URL}/qr_codes/${player.id}.png?ts=${Date.now()}`,
        headers: {Authorization: `Bearer ${token}`},
      });
    })();
    return () => {
      cancelled = true;
    };
  }, [player?.id]);

  return (
    <View style={styles.root}>
      <Text style={styles.name}>{player?.name ?? ''}</Text>
      {source && !failed ? (
        <Image
          source={source}
          style={styles.qrImage}
          resizeMode="contain"
          onError={() => setFailed(true)}
        />
      ) : (
        <View style={styles.qrPlaceholder}>
          <Text style={{color: '#14100c'}}>{failed ? 'QR недоступен' : 'Загрузка…'}</Text>
        </View>
      )}
      <Text style={styles.hint}>Предъявите код партнёру для торговли или мастеру для входа</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center', padding: spacing.l},
  name: {...typography.title, fontSize: 30, marginBottom: spacing.xl},
  qrImage: {width: 320, height: 320},
  qrPlaceholder: {
    width: 320, height: 320, backgroundColor: '#fff', borderRadius: 12,
    alignItems: 'center', justifyContent: 'center',
  },
  hint: {...typography.dim, marginTop: spacing.xl, textAlign: 'center'},
});
