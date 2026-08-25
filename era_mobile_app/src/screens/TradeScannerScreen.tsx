import React, {useState} from 'react';
import {View, Text, StyleSheet} from 'react-native';
import {StackNavigationProp} from '@react-navigation/stack';
import {createTradeSession} from '../api/endpoints';
import {QrScannerScreen} from './QrScannerScreen';
import {typography} from '../theme';

type Props = {navigation: StackNavigationProp<any>};

/**
 * FR-11: скан QR игрока B -> создание торговой сессии.
 * QR генерирует era_front /players: {"type":"player_auth","identificator":...}.
 * Отказ с причиной: «игрок офлайн», «занят другой сделкой» (сервер).
 */
interface QrPayload {
  identificator?: unknown;
  player_name?: string;
}

function extractIdentificator(payload: string): string | null {
  try {
    const parsed: QrPayload = JSON.parse(payload);
    if (typeof parsed.identificator === 'string' && parsed.identificator.trim() !== '') {
      return parsed.identificator.trim();
    }
    return null;
  } catch {
    // Резерв: QR с «голым» идентификатором без JSON
    const text = payload.trim();
    return text !== '' ? text : null;
  }
}

export function TradeScannerScreen({navigation}: Props) {
  const [status, setStatus] = useState<string | null>(null);

  const handleScanned = async (payload: string) => {
    const identificator = extractIdentificator(payload);
    if (!identificator) {
      setStatus('В QR нет идентификатора игрока');
      return;
    }
    try {
      const session = await createTradeSession(identificator);
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
