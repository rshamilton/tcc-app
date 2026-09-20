/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: '#166534', // green-800
        secondary: '#15803d', // green-700
        accent: '#22c55e', // green-500
      }
    },
  },
  plugins: [],
}
