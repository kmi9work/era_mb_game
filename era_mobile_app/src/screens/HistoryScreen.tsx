import React, {useCallback, useState} from 'react';
import {View, Text, FlatList, TouchableOpacity, StyleSheet} from 'react-native';
import {useFocusEffect} from '@react-navigation/native';
import {getOperations} from '../api/endpoints';
import {colors, typography, spacing} from '../theme';

const KINDS = ['', 'trade', 'plant_purchase', 'plant_upgrade', 'plant_sell', 'plant_produce',
               'caravan_send', 'caravan_result', 'political_action', 'master_correction'];

interface Operation {
  id: number; kind: string; year: number; status: string;
  comment: string | null; created_at: string;
  items: {identificator: string; name: string | null; delta: number}[];
}

export function HistoryScreen() {
  const [ops, setOps] = useState<Operation[]>([]);
  const [kind, setKind] = useState('');

  const load = useCallback(async () => {
    try {
      const d = await getOperations(kind ? {kind} : undefined);
      setOps(d.operations ?? []);
    } catch {}
  }, [kind]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  return (
    <View style={styles.root}>
      <Text style={typography.title}>История</Text>
      <FlatList
        horizontal
        data={KINDS}
        keyExtractor={k => k || 'all'}
        style={{maxHeight: 44}}
        renderItem={({item}) => (
          <TouchableOpacity
            style={[styles.chip, kind === item && styles.chipActive]}
            onPress={() => setKind(item)}>
            <Text style={{color: kind === item ? colors.background : colors.parchmentDim}}>
              {item || 'все'}
            </Text>
          </TouchableOpacity>
        )}
      />
      <FlatList
        data={ops}
        keyExtractor={o => String(o.id)}
        renderItem={({item}) => (
          <View style={styles.card}>
            <View style={{flexDirection: 'row', justifyContent: 'space-between'}}>
              <Text style={typography.body}>{kindLabel(item.kind)}</Text>
              <Text style={typography.dim}>год {item.year}</Text>
            </View>
            {item.items.map((it, i) => (
              <Text key={i} style={[typography.dim, {color: it.delta >= 0 ? colors.success : colors.danger}]}>
                {it.name ?? it.identificator}: {it.delta > 0 ? `+${it.delta}` : it.delta}
              </Text>
            ))}
            {item.comment ? <Text style={typography.dim}>{item.comment}</Text> : null}
            {item.status === 'reverted' && <Text style={{color: colors.danger}}>отменена мастером</Text>}
          </View>
        )}
      />
    </View>
  );
}

function kindLabel(kind: string): string {
  const map: Record<string, string> = {
    trade: 'Сделка',
    plant_purchase: 'Покупка предприятия',
    plant_upgrade: 'Улучшение предприятия',
    plant_sell: 'Продажа предприятия',
    plant_produce: 'Производство',
    caravan_send: 'Отправка каравана',
    caravan_result: 'Результат каравана',
    political_action: 'Политдействие',
    master_correction: 'Коррекция мастера',
    master_revert: 'Отмена операции мастером',
  };
  return map[kind] ?? kind;
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background, padding: spacing.m},
  chip: {
    paddingHorizontal: spacing.m, paddingVertical: spacing.s,
    backgroundColor: colors.surfaceAlt, borderRadius: 16, marginRight: spacing.s,
  },
  chipActive: {backgroundColor: colors.gold},
  card: {
    backgroundColor: colors.surface, borderRadius: 8, borderWidth: 1,
    borderColor: colors.border, padding: spacing.m, marginBottom: spacing.s,
  },
});
