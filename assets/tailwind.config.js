const theme = require("tailwindcss/defaultTheme");
const colors = require("tailwindcss/colors");

module.exports = {
  purge: [
    "../**/*.html.eex",
    "../**/*.html.leex",
    "../**/views/**/*.ex",
    "../**/live/**/*.ex",
    "./js/**/*.js",
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      fontFamily: {
        'sans': ['poppins', ...theme.fontFamily.sans]
      },
      colors: {
        trueGray: colors.trueGray
      },
    },
  },
  variants: {
    extend: {
      scale: ['hover'],
      animation: ['hover'],
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('./shadowpaletteplugin'),
  ],
}