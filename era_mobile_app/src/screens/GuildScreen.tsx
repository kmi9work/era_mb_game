import React, {useCallback, useState} from 'react';
import {View, Text, StyleSheet, ScrollView, RefreshControl} from 'react-native';
import {useFocusEffect} from '@react-navigation/native';
import {getGuild} from '../api/endpoints';
import {colors, typography, spacing} from '../theme';

interface GuildData {
  name: string;
  caravan_protected: boolean;
  balance: {money: number; resources: any[]};
  members: {id: number; name: string}[];
  last_operations: any[];
}

export function GuildScreen() {
  const [guild, setGuild] = useState<GuildData | null>(null);

  const load = useCallback(async () => {
    try { setGuild(await getGuild()); } catch {}
  }, []);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  return (
    <ScrollView style={styles.root} contentContainerStyle={{padding: spacing.m}}
      refreshControl={<RefreshControl refreshing={!guild} onRefresh={load} tintColor={colors.gold} />}>
      <Text style={typography.title}>{guild?.name ?? 'Гильдия'}</Text>
      {guild?.caravan_protected && (
        <View style={styles.protectedBadge}>
          <Text style={{color: colors.success}}>Караваны под защитой в этом году</Text>
        </View>
      )}
      <View style={styles.card}>
        <Text style={typography.dim}>Казна:</Text>
        <Text style={typography.big}>{guild?.balance.money ?? 0}</Text>
        {(guild?.balance.resources ?? []).map(r => (
          <Text key={r.identificator} style={typography.body}>{r.identificator}: {r.count}</Text>
        ))}
      </View>

      <Text style={[typography.dim, {marginTop: spacing.s}]}>Состав:</Text>
      {(guild?.members ?? []).map(m => (
        <Text key={m.id} style={typography.body}>{m.name}</Text>
      ))}

      <Text style={[typography.dim, {marginTop: spacing.m}]}>Последние операции казны:</Text>
      {(guild?.last_operations ?? []).slice(0, 10).map(op => (
        <View key={op.id} style={styles.opRow}>
          <Text style={typography.body}>{op.kind}</Text>
          <Text style={typography.dim}>{new Date(op.created_at).toLocaleTimeString()}</Text>
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: colors.background},
  protectedBadge: {backgroundColor: colors.surfaceAlt, padding: spacing.s, borderRadius: 6, marginTop: spacing.s},
  card: {backgroundColor: colors.surface, borderRadius: 8, borderWidth: 1, borderColor: colors.border,
         padding: spacing.m, marginVertical: spacing.m},
  opRow: {flexDirection: 'row', justifyContent: 'space-between', paddingVertical: spacing.xs},
});
