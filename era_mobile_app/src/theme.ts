/**
 * Стиль «минималистично-средневековый»: тёмный фон, пергаментные акценты,
 * крупные читаемые цифры (ТЗ 10.1). Крупные элементы управления — игра стоя.
 */
export const colors = {
  background: '#14100c',
  surface: '#1f1913',
  surfaceAlt: '#2a221a',
  border: '#3d3325',
  parchment: '#e8d9b5',
  parchmentDim: '#b3a586',
  gold: '#d4af37',
  danger: '#b04a3a',
  success: '#5f8a4e',
  accent: '#8a6d3b',
};

export const spacing = {xs: 4, s: 8, m: 16, l: 24, xl: 32};

export const typography = {
  title: {fontSize: 26, fontWeight: '700' as const, color: colors.parchment},
  big: {fontSize: 34, fontWeight: '700' as const, color: colors.gold},
  body: {fontSize: 17, color: colors.parchment},
  dim: {fontSize: 14, color: colors.parchmentDim},
  button: {fontSize: 20, fontWeight: '600' as const, color: colors.background},
};

export const buttons = {
  primary: {
    backgroundColor: colors.gold,
    paddingVertical: 16,
    paddingHorizontal: 24,
    borderRadius: 8,
    minHeight: 56, // крупная кнопка для игры стоя (ТЗ 10.3)
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  secondary: {
    ...{
      backgroundColor: colors.surfaceAlt,
      borderColor: colors.accent,
      borderWidth: 1,
    },
    paddingVertical: 16,
    paddingHorizontal: 24,
    borderRadius: 8,
    minHeight: 56,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  danger: {
    backgroundColor: colors.danger,
    paddingVertical: 16,
    paddingHorizontal: 24,
    borderRadius: 8,
    minHeight: 56,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
};
