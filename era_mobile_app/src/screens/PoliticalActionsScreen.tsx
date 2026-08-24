import React, {useCallback, useState} from 'react';
import {View, Text, FlatList, TouchableOpacity, StyleSheet, Alert} from 'react-native';
import {useFocusEffect} from '@react-navigation/native';
import {getPoliticalActions, performPoliticalAction} from '../api/endpoints';
import {colors, typography, spacing, buttons} from '../theme';

interface Action {
  id: number; name: string; description: string;
  cost: number; probability: string;
}

export function PoliticalActionsScreen() {
  const [actions, setActions] = useState<Action[]>([]);

  const load = useCallback(async () => {
    try { const d = await getPoliticalActions(); setActions(d.actions ?? d); } catch {}
  }, []);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  const perform = (a: Action) => {
    Alert.alert(
      a.name,
      `Цена: ${a.cost} золота. Порог кубика: ${a.probability}.\n\n${a.description}`,
      [
        {text: 'Отмена', style: 'cancel'},
        {
          text: 'Платить и бросить кубик',
          onPress: async () => {
            try {
              const res = await performPoliticalAction(a.id);
              // Анимация броска — точечная анимация (ТЗ 10.1); здесь итог:
              if (res.success) {
                Alert.alert('Успех!', `Кубик: ${res.roll.roll} ≥ ${res.roll.threshold}. Карточка «${a.name}» в казне.`);
              } else {
                Alert.alert('Провал', `Кубик: ${res.roll.roll} < ${res.roll.threshold}. Деньги уплачены.`);
              }
              await load();
            } catch (e: any) {
              Alert.alert('Ошибка', e?.response?.data?.error ?? 'Ошибка');
            }
          },
        },
      ],
    );
  };

  return (
    <View style={styles.root}>
      <Text style={typography.title}>Политические действия</Text>
      <Text style={typography.dim}>Доступно главе гильдии</Text>
      <FlatList
        data={actions}
        keyExtractor={a => String(a.id)}
        renderItem={({item}) => (
          <TouchableOpacity style={styles.card} onPress={() => perform(item)}>
            <Text style={typography.body}>{item.name}</Text>
            <Text style={typography.dim}>Цена: {item.cost} · Кубик: {item.probability}</Text>
          </TouchableOpacity>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background, padding: spacing.m},
  card: {
    backgroundColor: colors.surface, borderRadius: 8, borderWidth: 1,
    borderColor: colors.border, padding: spacing.m, marginBottom: spacing.s,
  },
});
