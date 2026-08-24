import React, {useState} from 'react';
import {View, Text, StyleSheet, ActivityIndicator} from 'react-native';
import {useAuth} from '../auth/AuthContext';
import {colors, typography, spacing} from '../theme';

/**
 * FR-2: первый вход — скан своего QR с бейджа.
 * FR-5: работает и без сети — сканирование возможно, логин даст понятную ошибку.
 */
export function LoginScreen() {
  const {signInWithQr} = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const handleScan = async (qrString: string) => {
    if (busy) return;
    setBusy(true);
    setError(null);
    const result = await signInWithQr(qrString);
    setBusy(false);
    if (!result.ok) {
      setError(result.error ?? 'Ошибка входа');
    }
  };

  // Заглушка сканера: реальная камера подключается через react-native-vision-camera
  // в ScanQrScreen; на экране входа — переход туда.
  return (
    <View style={styles.root}>
      <Text style={styles.title}>Эра перемен</Text>
      <Text style={styles.subtitle}>Купец</Text>
      {busy ? (
        <ActivityIndicator size="large" color={colors.gold} />
      ) : (
        <Text style={styles.hint}>Отсканируйте QR-код на вашем бейдже</Text>
      )}
      {error ? <Text style={styles.error}>{error}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center', padding: spacing.l},
  title: {...typography.title, fontSize: 34},
  subtitle: {...typography.dim, marginTop: spacing.s},
  hint: {...typography.body, marginTop: spacing.xl, textAlign: 'center'},
  error: {...typography.body, color: colors.danger, marginTop: spacing.m, textAlign: 'center'},
});
