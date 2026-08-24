import React, {useState} from 'react';
import {View, Text, StyleSheet} from 'react-native';
import {StackNavigationProp} from '@react-navigation/stack';
import {createTradeSession} from '../api/endpoints';
import {colors, typography, buttons} from '../theme';

type Props = {navigation: StackNavigationProp<any>};

/**
 * FR-11: скан QR игрока B → создание торговой сессии.
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
      <Text style={typography.body}>Наведите камеру на QR партнёра</Text>
      {/* Камера: react-native-vision-camera CodeScanner (переиспользуем опыт era_native).
          Заглушка до сборки нативных модулей: */}
      <Text style={[typography.dim, {marginTop: 24}]}>Камера активируется после нативной сборки</Text>
      {status ? <Text style={styles.status}>{status}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center', padding: 24},
  status: {...typography.body, color: colors.danger, marginTop: 16, textAlign: 'center'},
});
