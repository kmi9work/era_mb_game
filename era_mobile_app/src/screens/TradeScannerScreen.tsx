import React, {useState} from 'react';
import {StyleSheet} from 'react-native';
import {StackNavigationProp} from '@react-navigation/stack';
import {createTradeSession} from '../api/endpoints';
import {QrScannerScreen} from './QrScannerScreen';
import {typography} from '../theme';

type Props = {navigation: StackNavigationProp<any>};

/**
 * FR-11: скан QR игрока B -> создание торговой сессии.
 * Отказ с причиной: «игрок офлайн», «занят другой сделкой» (сервер).
 */
export function TradeScannerScreen({navigation}: Props) {
  const [status, setStatus] = useState<string | null>(null);

  const handleScanned = async (payload: string) => {
    try {
      const parsed = JSON.parse(payload);
      if (parsed.t === 'mb_player_auth') {
        // Это личный QR входа; для торговли нужен выбор партнёра из списка онлайн
        setStatus('Это ваш личный QR. Для торговли выберите партнёра в списке');
        return;
      }
    } catch {}
    try {
      const session = await createTradeSession(Number(payload));
      navigation.replace('TradeRoom', {sessionId: session.id});
    } catch (e: any) {
      setStatus(e?.response?.data?.error ?? 'Не удалось начать сделку');
    }
  };

  return (
    <View style={styles.root}>
      <QrScannerScreen
        title="Наведите камеру на QR партнёра"
        onScan={handleScanned}
        onClose={() => navigation.goBack()}
      />
      {status ? (
        <Text style={styles.statusOverlay}>{status}</Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: '#000'},
  statusOverlay: {
    ...typography.body,
    position: 'absolute',
    bottom: 120,
    left: 24,
    right: 24,
    color: '#ff6b6b',
    textAlign: 'center',
    backgroundColor: 'rgba(0,0,0,0.7)',
    padding: 12,
    borderRadius: 8,
  },
});
