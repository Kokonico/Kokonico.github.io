// oh, so pretty

const colors = ['#60D394', '#0072BB', '#FEE440', '#EF959D', '#FF715B'];

const links = document.querySelectorAll('.button_inner');

function darkerColor(color, amount) {
  const parsed = document.createElement('div');
  parsed.style.color = color;
  document.body.appendChild(parsed);
  const rgb = getComputedStyle(parsed).color.match(/\d+/g).map(Number);
  document.body.removeChild(parsed);

  const darkened = rgb.map((value) => Math.max(0, Math.round(value * (1 - amount))));
  return `rgb(${darkened[0]}, ${darkened[1]}, ${darkened[2]})`;
}

let previousColor = null;

links.forEach(function(div) {
  let rand = colors[Math.floor(Math.random() * colors.length)];
  while (rand === previousColor) {
    rand = colors[Math.floor(Math.random() * colors.length)];
  }
  previousColor = rand;
  const buttonOuter = div.closest('.button_outer');
  div.style.backgroundColor = rand;
  if (buttonOuter) {
    buttonOuter.style.setProperty('--button-color', rand);
    buttonOuter.style.setProperty('--shadow-color-1', darkerColor(rand, 0.25));
    buttonOuter.style.setProperty('--shadow-color-2', darkerColor(rand, 0.45));
  }
});