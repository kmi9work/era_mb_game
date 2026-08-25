import React, {useState} from 'react';
import {View, Text, StyleSheet, TouchableOpacity, ActivityIndicator} from 'react-native';
import {useAuth} from '../auth/AuthContext';
import {QrScannerScreen} from './QrScannerScreen';
import {colors, typography, spacing} from '../theme';

/**
 * FR-2: первый вход — скан своего QR с бейджа.
 * FR-5: работает и без сети — сканирование возможно, логин даст понятную ошибку.
 */
export function LoginScreen() {
  const {signInWithQr} = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [scanning, setScanning] = useState(false);

  const handleScan = async (qrString: string) => {
    if (busy) return;
    setScanning(false);
    setBusy(true);
    setError(null);
    const result = await signInWithQr(qrString);
    setBusy(false);
    if (!result.ok) {
      setError(result.error ?? 'Ошибка входа');
    }
  };

  if (scanning) {
    return (
      <QrScannerScreen
        title="Наведите камеру на QR бейджа"
        onScan={handleScan}
        onClose={() => setScanning(false)}
      />
    );
  }

  return (
    <View style={styles.root}>
      <Text style={styles.title}>Эра перемен</Text>
      <Text style={styles.subtitle}>Купец</Text>
      {busy ? (
        <ActivityIndicator size="large" color={colors.gold} style={styles.gap} />
      ) : (
        <>
          <Text style={[styles.hint, styles.gap]}>
            Отсканируйте QR-код{'\n'}на вашем бейдже
          </Text>
          <TouchableOpacity style={styles.scanButton} onPress={() => setScanning(true)}>
            <Text style={styles.scanButtonText}>Сканировать QR</Text>
          </TouchableOpacity>
        </>
      )}
      {error ? <Text style={styles.error}>{error}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.background,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.l,
  },
  title: {...typography.title, fontSize: 34},
  subtitle: {...typography.dim, marginTop: spacing.s},
  gap: {marginTop: spacing.xl},
  hint: {...typography.body, textAlign: 'center'},
  scanButton: {
    marginTop: spacing.l,
    backgroundColor: colors.gold,
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 28,
  },
  scanButtonText: {color: '#1a1410', fontSize: 16, fontWeight: '600'},
  error: {...typography.body, color: colors.danger, marginTop: spacing.m, textAlign: 'center'},
});
