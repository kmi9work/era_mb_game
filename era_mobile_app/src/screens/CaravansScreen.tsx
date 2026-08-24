import React, {useCallback, useState} from 'react';
import {View, Text, FlatList, TouchableOpacity, StyleSheet, Alert} from 'react-native';
import {useFocusEffect} from '@react-navigation/native';
import {getCaravans, getCountries, sendCaravan} from '../api/endpoints';
import {colors, typography, spacing, buttons} from '../theme';

interface Country {
  id: number; name: string; relations: number; embargo: boolean;
  prices: {identificator: string; name: string; sale_price: number | null; buy_price: number | null}[];
}
interface Caravan {
  id: number; country: string; status: string; process_at: string;
  sell_items: any[]; buy_items: any[];
}

const STATUS_LABELS: Record<string, {label: string; color: string}> = {
  in_transit: {label: 'В пути', color: colors.gold},
  processed_ok: {label: 'Исполнен', color: colors.success},
  robbed: {label: 'Ограблен', color: colors.danger},
  cancelled_by_master: {label: 'Отменён мастером', color: colors.parchmentDim},
};

/**
 * FR-25..FR-28. Путь отправки ≤6 тапов: Караваны → страна → «Продать» ресурс →
 * количество → Отправить → подтверждение.
 */
export function CaravansScreen() {
  const [countries, setCountries] = useState<Country[]>([]);
  const [caravans, setCaravans] = useState<Caravan[]>([]);
  const [selected, setSelected] = useState<Country | null>(null);

  const load = useCallback(async () => {
    try {
      const c = await getCountries();
      const v = await getCaravans();
      setCountries(c.countries ?? c);
      setCaravans(v.caravans ?? []);
    } catch {}
  }, []);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  const send = (country: Country, useContraband: boolean) => {
    Alert.alert(
      'Отправить караван',
      `Страна: ${country.name}${useContraband ? ' (с контрабандой)' : ''}`,
      [
        {text: 'Отмена', style: 'cancel'},
        {
          text: 'Отправить',
          onPress: async () => {
            try {
              // Демо-состав: продаём первый ресурс с ценой продажи
              const sellable = country.prices.find(p => p.sale_price);
              await sendCaravan({
                country_id: country.id,
                sell_items: sellable ? [{identificator: sellable.identificator,
                                         name: sellable.name, count: 10}] : [],
                buy_items: [],
                use_contraband: useContraband,
              });
              setSelected(null);
              await load();
            } catch (e: any) {
              Alert.alert('Ошибка', e?.response?.data?.error ?? 'Не удалось отправить');
            }
          },
        },
      ],
    );
  };

  return (
    <View style={styles.root}>
      <Text style={typography.title}>Караваны</Text>
      <FlatList
        data={countries}
        keyExtractor={c => String(c.id)}
        ListHeaderComponent={<Text style={[typography.dim, {marginVertical: spacing.s}]}>Страны:</Text>}
        renderItem={({item}) => (
          <TouchableOpacity style={styles.row} onPress={() => setSelected(item)}>
            <View style={{flex: 1}}>
              <Text style={typography.body}>
                {item.name} {item.embargo ? '· ЭМБАРГО' : ''}
              </Text>
              <Text style={typography.dim}>
                Отношения: {item.relations > 0 ? `+${item.relations}` : item.relations}
              </Text>
            </View>
          </TouchableOpacity>
        )}
      />

      {selected && (
        <View style={styles.sheet}>
          <Text style={typography.title}>{selected.name}</Text>
          <FlatList
            data={selected.prices.filter(p => p.sale_price || p.buy_price)}
            keyExtractor={p => p.identificator}
            renderItem={({item}) => (
              <View style={styles.row}>
                <Text style={typography.body}>{item.name}</Text>
                <Text style={typography.dim}>
                  продажа {item.sale_price ?? '—'} · покупка {item.buy_price ?? '—'}
                </Text>
              </View>
            )}
          />
          {selected.embargo ? (
            <TouchableOpacity style={buttons.danger} onPress={() => send(selected, true)}>
              <Text style={typography.button}>Отправить с контрабандой</Text>
            </TouchableOpacity>
          ) : (
            <TouchableOpacity style={buttons.primary} onPress={() => send(selected, false)}>
              <Text style={typography.button}>Отправить караван</Text>
            </TouchableOpacity>
          )}
          <TouchableOpacity onPress={() => setSelected(null)}>
            <Text style={[typography.dim, {textAlign: 'center', marginTop: spacing.s}]}>Закрыть</Text>
          </TouchableOpacity>
        </View>
      )}

      <FlatList
        data={caravans}
        keyExtractor={c => String(c.id)}
        ListHeaderComponent={<Text style={[typography.dim, {marginVertical: spacing.s}]}>Мои заявки:</Text>}
        renderItem={({item}) => {
          const st = STATUS_LABELS[item.status] ?? {label: item.status, color: colors.parchment};
          return (
            <View style={styles.row}>
              <Text style={typography.body}>{item.country}</Text>
              <Text style={{color: st.color}}>{st.label}</Text>
            </View>
          );
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background, padding: spacing.m},
  row: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    backgroundColor: colors.surface, borderRadius: 8, borderWidth: 1, borderColor: colors.border,
    padding: spacing.m, marginBottom: spacing.s,
  },
  sheet: {
    position: 'absolute', bottom: 0, left: 0, right: 0, maxHeight: '70%',
    backgroundColor: colors.surface, borderTopLeftRadius: 16, borderTopRightRadius: 16,
    padding: spacing.m, borderColor: colors.accent, borderWidth: 1,
  },
});
