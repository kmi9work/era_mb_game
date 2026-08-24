import React, {useCallback, useState} from 'react';
import {View, Text, FlatList, TouchableOpacity, StyleSheet, Alert} from 'react-native';
import {useFocusEffect} from '@react-navigation/native';
import {getPlants, producePlant, produceAllPlants, sellPlant} from '../api/endpoints';
import {colors, typography, spacing, buttons} from '../theme';

interface Plant {
  id: number;
  type: string;
  level: number;
  region: string | null;
  produced_this_year: boolean;
  deposit: number;
}

/**
 * FR-19/FR-23: список предприятий, кнопка «Произвести» на карточке (≤2 тапа),
 * batch «Произвести на всех» (1 тап + подтверждение).
 */
export function PlantsScreen() {
  const [plants, setPlants] = useState<Plant[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const data = await getPlants();
      setPlants(data.plants ?? data);
      setError(null);
    } catch (e: any) {
      setError(e?.response?.data?.error ?? 'Нет связи');
    }
  }, []);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  const produce = async (p: Plant) => {
    try {
      await producePlant(p.id);
      await load();
    } catch (e: any) {
      // FR-40: человекочитаемая причина от сервера
      Alert.alert('Не удалось произвести', e?.response?.data?.error ?? 'Ошибка');
    }
  };

  const sell = (p: Plant) => {
    Alert.alert(
      'Продать предприятие',
      `Получите залоговую стоимость ${p.deposit} золота`,
      [
        {text: 'Отмена', style: 'cancel'},
        {
          text: 'Продать',
          style: 'destructive',
          onPress: async () => {
            try { await sellPlant(p.id); await load(); }
            catch (e: any) { Alert.alert('Ошибка', e?.response?.data?.error ?? 'Ошибка'); }
          },
        },
      ],
    );
  };

  const produceAll = () => {
    Alert.alert(
      'Произвести на всех доступных',
      'Одно подтверждение — и все предприятия отработают год',
      [
        {text: 'Отмена', style: 'cancel'},
        {
          text: 'Произвести',
          onPress: async () => {
            try { await produceAllPlants(); await load(); }
            catch (e: any) { Alert.alert('Ошибка', e?.response?.data?.error ?? 'Ошибка'); }
          },
        },
      ],
    );
  };

  return (
    <View style={styles.root}>
      <TouchableOpacity style={[buttons.primary, {marginBottom: spacing.m}]} onPress={produceAll}>
        <Text style={typography.button}>Произвести на всех доступных</Text>
      </TouchableOpacity>
      {error && <Text style={styles.error}>{error}</Text>}
      <FlatList
        data={plants}
        keyExtractor={p => String(p.id)}
        renderItem={({item}) => (
          <View style={styles.card}>
            <View style={{flex: 1}}>
              <Text style={typography.body}>
                {item.type} · уровень {item.level}
              </Text>
              <Text style={typography.dim}>
                {item.region ?? '—'} ·{' '}
                {item.produced_this_year ? 'отработало в этом году' : 'готово к работе'}
              </Text>
            </View>
            {!item.produced_this_year && (
              <TouchableOpacity style={styles.produceBtn} onPress={() => produce(item)}>
                <Text style={{color: colors.background, fontWeight: '600'}}>Произвести</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity onPress={() => sell(item)}>
              <Text style={{color: colors.danger}}>Продать</Text>
            </TouchableOpacity>
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background, padding: spacing.m},
  error: {...typography.body, color: colors.danger},
  card: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: colors.surface,
    borderRadius: 8, borderWidth: 1, borderColor: colors.border,
    padding: spacing.m, marginBottom: spacing.s, gap: spacing.s,
  },
  produceBtn: {
    backgroundColor: colors.gold, paddingHorizontal: spacing.m, paddingVertical: spacing.s,
    borderRadius: 6,
  },
});
