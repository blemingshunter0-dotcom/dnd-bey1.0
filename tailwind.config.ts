import type { Config } from 'tailwindcss';

/**
 * Gothic-fantasy design tokens. Dark, candlelit palette with parchment accents,
 * ox-blood and antique-gold highlights, and serif display type. All app UI pulls
 * from these tokens so the aesthetic stays consistent across every feature.
 */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Base surfaces — deep, near-black with a warm cast (candlelit stone)
        ink: {
          950: '#0b0908',
          900: '#141110',
          800: '#1e1917',
          700: '#2a2320',
          600: '#3a302b',
        },
        // Parchment — aged paper for text and light surfaces
        parchment: {
          50: '#f5efe0',
          100: '#ece2cd',
          200: '#dccdae',
          300: '#c4b088',
        },
        // Ox-blood — primary accent, danger, DM/blood-magic motifs
        blood: {
          500: '#7a1f2b',
          600: '#5f171f',
          700: '#4a1119',
        },
        // Antique gold — highlights, active states, ornamentation
        gold: {
          300: '#d9b866',
          400: '#c69b3f',
          500: '#a67c2e',
        },
        // Arcane — secondary accent for magic/spellcasting UI
        arcane: {
          400: '#6b5b95',
          500: '#4f4374',
        },
      },
      fontFamily: {
        display: ['"Cinzel"', 'Georgia', 'serif'],
        serif: ['"EB Garamond"', 'Georgia', 'serif'],
        sans: ['ui-sans-serif', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        candle: '0 0 40px -8px rgba(198, 155, 63, 0.25)',
        recessed: 'inset 0 2px 8px rgba(0, 0, 0, 0.6)',
      },
      backgroundImage: {
        'vignette':
          'radial-gradient(ellipse at center, rgba(20,17,16,0) 0%, rgba(11,9,8,0.85) 100%)',
      },
    },
  },
  plugins: [],
} satisfies Config;
