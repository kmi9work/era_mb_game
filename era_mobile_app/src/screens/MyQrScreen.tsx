import React, {useEffect, useRef} from 'react';
import {View, Text, StyleSheet} from 'react-native';
// Яркость экрана: нативный модуль подключается на этапе нативной сборки (v2);
// в каркасе не используем сторонних пакетов.
import {colors, typography, spacing} from '../theme';
import {useAuth} from '../auth/AuthContext';

/**
 * FR-10: персональный QR — статичный, полноэкранный режим, максимальная яркость.
 * QR-строка приходит с бэка (GET /qr_codes/:id.png отдаёт PNG; здесь рендерим строку
 * через <QRCode> компонент — зависимость в package.json).
 */
export function MyQrScreen() {
  useEffect(() => {
    // FR-10: временно повышать яркость — подключить нативный модуль при нативной сборке
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
