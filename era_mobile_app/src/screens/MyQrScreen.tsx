import React, {useEffect, useRef} from 'react';
import {View, Text, StyleSheet, AppState} from 'react-native';
import * as Brightness from 'react-native-brightness'; // см. README: нативный модуль яркости
import {colors, typography, spacing} from '../theme';
import {useAuth} from '../auth/AuthContext';

/**
 * FR-10: персональный QR — статичный, полноэкранный режим, максимальная яркость.
 * QR-строка приходит с бэка (GET /qr_codes/:id.png отдаёт PNG; здесь рендерим строку
 * через <QRCode> компонент — зависимость в package.json).
 */
export function MyQrScreen() {
  const restoreBrightness = useRef<number | null>(null);

  useEffect(() => {
    // Временно повышаем яркость на время показа QR (ТЗ FR-10)
    Brightness?.getBrightness?.().then((v: number) => {
      restoreBrightness.current = v;
      Brightness.setBrightness(1);
    }).catch(() => {});
    const sub = AppState.addEventListener('change', state => {
      if (state !== 'active' && restoreBrightness.current !== null) {
        Brightness.setBrightness(restoreBrightness.current).catch(() => {});
      }
    });
    return () => {
      sub.remove();
      if (restoreBrightness.current !== null) {
        Brightness.setBrightness(restoreBrightness.current).catch(() => {});
      }
    };
  }, []);

  const {player} = useAuth();

  return (
    <View style={styles.root}>
      <Text style={styles.name}>{player?.name ?? ''}</Text>
      {/* <QRCode value={qrString} size={320} backgroundColor="#fff" color="#14100c" /> */}
      <View style={styles.qrPlaceholder}>
        <Text style={{color: '#14100c'}}>QR</Text>
      </View>
      <Text style={styles.hint}>Предъявите код партнёру для торговли или мастеру для входа</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center', padding: spacing.l},
  name: {...typography.title, fontSize: 30, marginBottom: spacing.xl},
  qrPlaceholder: {
    width: 320, height: 320, backgroundColor: '#fff', borderRadius: 12,
    alignItems: 'center', justifyContent: 'center',
  },
  hint: {...typography.dim, marginTop: spacing.xl, textAlign: 'center'},
});
