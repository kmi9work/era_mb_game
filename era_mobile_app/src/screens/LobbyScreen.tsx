import React, {useCallback, useEffect, useState} from 'react';
import {
  View, Text, ScrollView, StyleSheet, TouchableOpacity, RefreshControl,
} from 'react-native';
import {StackNavigationProp} from '@react-navigation/stack';
import {getLobby} from '../api/endpoints';
import {onSocketEvent, connectPlayerSocket} from '../api/socket';
import {colors, typography, spacing, buttons} from '../theme';
import {useAuth} from '../auth/AuthContext';

type RootStack = {MyQr: undefined; TradeScanner: undefined; Plants: undefined;
  Caravans: undefined; Guild: undefined; History: undefined; PoliticalActions: undefined};
type Props = {navigation: StackNavigationProp<RootStack>};

interface LobbyData {
  year: number;
  years_total: number;
  cycle_item: {identificator: string; finish: string} | null;
  seconds_left: number | null;
  storage: {
    money: number;
    resources: {identificator: string; count: number}[];
    cards: {id: number; name: string; year: number}[];
  };
}

function fmtTime(sec: number | null): string {
  if (sec === null || sec === undefined) return '--:--';
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

export function LobbyScreen({navigation}: Props) {
  const {player} = useAuth();
  const [data, setData] = useState<LobbyData | null>(null);
  const [online, setOnline] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState<number | null>(null);

  const load = useCallback(async () => {
    try {
      const d = await getLobby();
      setData(d);
      setSecondsLeft(d.seconds_left);
      setOnline(true);
    } catch {
      setOnline(false); // FR-41: баннер «нет соединения», автоповтор чтения
    }
  }, []);

  useEffect(() => {
    load();
    connectPlayerSocket(setOnline);
    const off = onSocketEvent('year_tick', (payload: any) => {
      setSecondsLeft(payload.seconds_left);
    });
    const offBalance = onSocketEvent('lobby_update', () => load());
    const iv = setInterval(() => setSecondsLeft(s => (s === null ? null : Math.max(0, s - 1))), 1000);
    const poll = setInterval(load, 15000); // автоповтор чтения при потере сети
    return () => { off(); offBalance(); clearInterval(iv); clearInterval(poll); };
  }, [load]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  return (
    <View style={styles.root}>
      {/* Шапка: игрок, год/цикл, таймер + индикатор связи (FR-6, FR-41) */}
      <View style={styles.header}>
        <View style={{flex: 1}}>
          <Text style={typography.body}>{player?.name ?? ''}</Text>
          <Text style={typography.dim}>Год {data?.year ?? '—'} · Цикл: {data?.cycle_item?.identificator ?? 'вне цикла'}</Text>
        </View>
        <View style={{alignItems: 'flex-end'}}>
          <Text style={styles.timer}>{fmtTime(secondsLeft ?? data?.seconds_left ?? null)}</Text>
          <Text style={[typography.dim, {color: online ? colors.success : colors.danger}]}>
            {online ? 'связь есть' : 'нет сети'}
          </Text>
        </View>
      </View>

      {!online && (
        <View style={styles.offlineBanner}>
          <Text style={styles.offlineText}>Нет соединения. Операции недоступны, идёт переподключение…</Text>
        </View>
      )}

      <ScrollView refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.gold} />}>
        {/* Баланс хранилища (FR-7): казна гильдии как кошелёк игрока (ТЗ 6.3) */}
        <View style={styles.card}>
          <Text style={typography.dim}>Казна гильдии</Text>
          <Text style={typography.big}>{data?.storage.money ?? 0}</Text>
          {(data?.storage.resources ?? []).map(r => (
            <Text key={r.identificator} style={typography.body}>
              {r.identificator}: {r.count}
            </Text>
          ))}
          {(data?.storage.cards ?? []).map(c => (
            <Text key={c.id} style={[typography.body, {color: colors.accent}]}>
              Карточка «{c.name}» ({c.year})
            </Text>
          ))}
        </View>

        {/* Быстрые действия (FR-8): 1 тап до цели по метрике ТЗ 10.2 */}
        <TouchableOpacity style={buttons.primary} onPress={() => navigation.navigate('MyQr')}>
          <Text style={typography.button}>Мой QR</Text>
        </TouchableOpacity>
        <TouchableOpacity style={buttons.secondary} onPress={() => navigation.navigate('TradeScanner')}>
          <Text style={[typography.button, {color: colors.parchment}]}>Сканировать для торговли</Text>
        </TouchableOpacity>
        <TouchableOpacity style={buttons.secondary} onPress={() => navigation.navigate('Plants')}>
          <Text style={[typography.button, {color: colors.parchment}]}>Предприятия</Text>
        </TouchableOpacity>
        <TouchableOpacity style={buttons.secondary} onPress={() => navigation.navigate('Caravans')}>
          <Text style={[typography.button, {color: colors.parchment}]}>Караваны</Text>
        </TouchableOpacity>
        <TouchableOpacity style={buttons.secondary} onPress={() => navigation.navigate('PoliticalActions')}>
          <Text style={[typography.button, {color: colors.parchment}]}>Политдействия</Text>
        </TouchableOpacity>
        <TouchableOpacity style={buttons.secondary} onPress={() => navigation.navigate('Guild')}>
          <Text style={[typography.button, {color: colors.parchment}]}>Гильдия</Text>
        </TouchableOpacity>
        <TouchableOpacity style={buttons.secondary} onPress={() => navigation.navigate('History')}>
          <Text style={[typography.button, {color: colors.parchment}]}>История</Text>
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background},
  header: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    padding: spacing.m, borderBottomWidth: 1, borderBottomColor: colors.border,
  },
  timer: {...typography.title, color: colors.gold, fontVariant: ['tabular-nums']},
  offlineBanner: {backgroundColor: colors.danger, padding: spacing.s},
  offlineText: {color: '#fff', textAlign: 'center'},
  card: {
    backgroundColor: colors.surface, borderRadius: 8, padding: spacing.m,
    margin: spacing.m, borderWidth: 1, borderColor: colors.border,
  },
});
