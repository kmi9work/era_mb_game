import React, {useState, useEffect, useRef} from 'react';
import {View, Text, StyleSheet, TouchableOpacity, Alert} from 'react-native';
import {Camera, useCameraDevice, useCodeScanner} from 'react-native-vision-camera';

type Props = {
  title: string;
  onScan: (payload: string) => void;
  onClose: () => void;
};

/**
 * Полноэкранный QR-сканер на react-native-vision-camera.
 * Переиспользует проверенный подход era_players/QRCodeScanner:
 *   requestCameraPermission -> useCameraDevice('back') -> useCodeScanner(['qr']).
 * Однократное срабатывание (scanned-флаг) — чтобы не спамить onScan.
 */
export function QrScannerScreen({title, onScan, onClose}: Props) {
  const [hasPermission, setHasPermission] = useState(false);
  const [scanned, setScanned] = useState(false);
  const device = useCameraDevice('back');
  const cameraRef = useRef<Camera>(null);

  useEffect(() => {
    (async () => {
      try {
        const permission = await Camera.requestCameraPermission();
        if (permission === 'granted') {
          setHasPermission(true);
        } else {
          Alert.alert(
            'Нет доступа к камере',
            'Разрешите приложению использовать камеру в настройках системы.',
          );
          onClose();
        }
      } catch {
        Alert.alert('Ошибка', 'Не удалось запросить доступ к камере.');
        onClose();
      }
    })();
  }, [onClose]);

  const codeScanner = useCodeScanner({
    codeTypes: ['qr'],
    onCodeScanned: codes => {
      if (!scanned && codes.length > 0) {
        const value = codes[0].value;
        if (value) {
          setScanned(true);
          onScan(value);
        }
      }
    },
  });

  return (
    <View style={styles.container}>
      {hasPermission && device != null ? (
        <Camera
          ref={cameraRef}
          style={StyleSheet.absoluteFill}
          device={device}
          isActive={true}
          codeScanner={codeScanner}
        />
      ) : (
        <Text style={styles.status}>
          {!hasPermission ? 'Ожидание разрешения на камеру...' : 'Инициализация камеры...'}
        </Text>
      )}

      <View style={styles.overlay} pointerEvents="box-none">
        <Text style={styles.title}>{title}</Text>
        <View style={styles.frame} />
        <TouchableOpacity style={styles.closeButton} onPress={onClose}>
          <Text style={styles.closeButtonText}>Закрыть</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const FRAME = 240;

const styles = StyleSheet.create({
  container: {flex: 1, backgroundColor: '#000'},
  status: {color: '#fff', textAlign: 'center', marginTop: 120},
  overlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
  },
  title: {
    color: '#fff',
    fontSize: 16,
    marginTop: 80,
    backgroundColor: 'rgba(0,0,0,0.5)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
    overflow: 'hidden',
  },
  frame: {
    width: FRAME,
    height: FRAME,
    marginTop: 40,
    borderWidth: 2,
    borderColor: '#d4af37',
    borderRadius: 12,
    backgroundColor: 'transparent',
  },
  closeButton: {
    position: 'absolute',
    bottom: 48,
    alignSelf: 'center',
    backgroundColor: 'rgba(255,255,255,0.15)',
    paddingHorizontal: 28,
    paddingVertical: 12,
    borderRadius: 24,
  },
  closeButtonText: {color: '#fff', fontSize: 16},
});
