import 'react-native-gesture-handler';
import React from 'react';
import {createStackNavigator} from '@react-navigation/stack';
import {NavigationContainer, DefaultTheme} from '@react-navigation/native';
import {StatusBar} from 'react-native';
import {SafeAreaProvider} from 'react-native-safe-area-context';
import {AuthProvider, useAuth} from './auth/AuthContext';
import {LoginScreen} from './screens/LoginScreen';
import {LobbyScreen} from './screens/LobbyScreen';
import {MyQrScreen} from './screens/MyQrScreen';
import {TradeScannerScreen} from './screens/TradeScannerScreen';
import {TradeRoomScreen} from './screens/TradeRoomScreen';
import {PlantsScreen} from './screens/PlantsScreen';
import {CaravansScreen} from './screens/CaravansScreen';
import {PoliticalActionsScreen} from './screens/PoliticalActionsScreen';
import {GuildScreen} from './screens/GuildScreen';
import {HistoryScreen} from './screens/HistoryScreen';
import {colors} from './theme';

const navTheme = {
  ...DefaultTheme,
  colors: {...DefaultTheme.colors, background: colors.background},
};

const Stack = createStackNavigator();

function Root() {
  const {player, loading} = useAuth();

  if (loading) return null;

  return (
    <Stack.Navigator screenOptions={{headerStyle: {backgroundColor: colors.surface},
                                     headerTintColor: colors.parchment}}>
      {!player ? (
        <Stack.Screen name="Login" component={LoginScreen} options={{headerShown: false}} />
      ) : (
        <>
          <Stack.Screen name="Lobby" component={LobbyScreen} options={{title: 'Эра перемен'}} />
          <Stack.Screen name="MyQr" component={MyQrScreen} options={{title: 'Мой QR'}} />
          <Stack.Screen name="TradeScanner" component={TradeScannerScreen} options={{title: 'Сканировать'}} />
          <Stack.Screen name="TradeRoom" component={TradeRoomScreen} options={{title: 'Торговля'}} />
          <Stack.Screen name="Plants" component={PlantsScreen} options={{title: 'Предприятия'}} />
          <Stack.Screen name="Caravans" component={CaravansScreen} options={{title: 'Караваны'}} />
          <Stack.Screen name="PoliticalActions" component={PoliticalActionsScreen}
                        options={{title: 'Политдействия'}} />
          <Stack.Screen name="Guild" component={GuildScreen} options={{title: 'Гильдия'}} />
          <Stack.Screen name="History" component={HistoryScreen} options={{title: 'История'}} />
        </>
      )}
    </Stack.Navigator>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <AuthProvider>
        <NavigationContainer theme={navTheme}>
          <StatusBar barStyle="light-content" backgroundColor={colors.background} />
          <Root />
        </NavigationContainer>
      </AuthProvider>
    </SafeAreaProvider>
  );
}
