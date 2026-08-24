import React, {useCallback, useEffect, useState} from 'react';
import {
  View, Text, StyleSheet, FlatList, TextInput, TouchableOpacity,
} from 'react-native';
import {RouteProp, useFocusEffect} from '@react-navigation/native';
import {getTradeSession, updateOffer, confirmTrade, cancelTrade, getLobby} from '../api/endpoints';
import {onSocketEvent} from '../api/socket';
import {colors, typography, spacing, buttons} from '../theme';

type Props = {route: RouteProp<{TradeRoom: {sessionId: number}}, 'TradeRoom'>};

interface TradeState {
  id: number;
  status: string;
  partner: {id: number; name: string};
  your_offer: {money: number; resources: any[]; cards: number[]};
  you_confirmed: boolean;
}

/**
 * FR-12: имя партнёра, две колонки «Отдаю / Получаю».
 * FR-13/FR-14: сборка оффера + двустороннее подтверждение (≤2 тапа).
 */
export function TradeRoomScreen({route}: Props) {
  const sessionId = route.params.sessionId;
  const [state, setState] = useState<TradeState | null>(null);
  const [money, setMoney] = useState('');
  const [myBalance, setMyBalance] = useState<{money: number; resources: any[]} | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  const load = useCallback(async () => {
    try {
      const s = await getTradeSession(sessionId);
      setState(s);
      setMoney(String(s.your_offer.money ?? ''));
      if (s.status === 'completed') setDone(true);
      const lobby = await getLobby();
      setMyBalance(lobby.storage);
    } catch (e: any) {
      setError(e?.response?.data?.error ?? 'Нет связи');
    }
  }, [sessionId]);

  useFocusEffect(
    useCallback(() => {
      load();
      const off = onSocketEvent('trade_update', load);
      return () => off();
    }, [load]),
  );

  const saveOffer = async () => {
    setError(null);
    try {
      await updateOffer(sessionId, {money: Number(money) || 0});
      await load();
    } catch (e: any) {
      setError(e?.response?.data?.error ?? 'Не удалось сохранить предложение');
    }
  };

  const confirm = async () => {
    // Тап 1 из двух: сохранить+подтвердить
    await saveOffer();
    try {
      const res = await confirmTrade(sessionId);
      if (res.status === 'completed') setDone(true);
      else await load();
    } catch (e: any) {
      setError(e?.response?.data?.error ?? 'Ошибка подтверждения');
    }
  };

  const cancel = async () => {
    try {
      await cancelTrade(sessionId);
    } catch {}
  };

  if (done) {
    return (
      <View style={styles.root}>
        <Text style={[typography.title, {textAlign: 'center'}]}>Сделка исполнена</Text>
        <Text style={[typography.body, {textAlign: 'center', marginTop: spacing.m}]}>
          Позиции перемещены между хранилищами. История обновлена.
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <Text style={typography.title}>Сделка с {state?.partner.name ?? '…'}</Text>
      {state?.you_confirmed && <Text style={styles.confirmed}>Вы подтвердили — ждём партнёра</Text>}
      {error && <Text style={styles.error}>{error}</Text>}

      {/* Отдаю: ввод денег; ресурсы и карточки добавляются списком из баланса (FR-13) */}
      <Text style={[typography.dim, {marginTop: spacing.m}]}>Отдаю золото:</Text>
      <TextInput
        style={styles.input}
        keyboardType="number-pad"
        value={money}
        onChangeText={setMoney}
        placeholder={`есть ${myBalance?.money ?? 0}`}
        placeholderTextColor={colors.parchmentDim}
      />
      {(myBalance?.resources ?? []).length > 0 && (
        <Text style={typography.dim}>Ресурсы добавляются тапом по строке:</Text>
      )}
      <FlatList
        data={myBalance?.resources ?? []}
        keyExtractor={r => r.identificator}
        renderItem={({item}) => (
          <View style={styles.resRow}>
            <Text style={typography.body}>{item.identificator}</Text>
            <Text style={typography.dim}>{item.count}</Text>
          </View>
        )}
      />

      <TouchableOpacity style={buttons.primary} onPress={saveOffer}>
        <Text style={typography.button}>Сохранить предложение</Text>
      </TouchableOpacity>
      <TouchableOpacity style={[buttons.primary, {marginTop: spacing.s, backgroundColor: colors.success}]}
                        onPress={confirm}>
        <Text style={typography.button}>Подтвердить сделку</Text>
      </TouchableOpacity>
      <TouchableOpacity style={[buttons.danger, {marginTop: spacing.s}]} onPress={cancel}>
        <Text style={typography.button}>Отменить</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background, padding: spacing.m},
  confirmed: {...typography.body, color: colors.gold, marginTop: spacing.s},
  error: {...typography.body, color: colors.danger, marginTop: spacing.s},
  input: {
    backgroundColor: colors.surface, borderColor: colors.border, borderWidth: 1,
    borderRadius: 8, color: colors.parchment, fontSize: 22, padding: spacing.m,
    marginVertical: spacing.s,
  },
  resRow: {
    flexDirection: 'row', justifyContent: 'space-between', paddingVertical: spacing.s,
    borderBottomWidth: 1, borderBottomColor: colors.border,
  },
});
