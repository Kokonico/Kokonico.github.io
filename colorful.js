// oh, so pretty

const colors = ['#FF5050', '#5050FF', '#EEEE50', 'orange', '#EFC0CB', '#50DDDD', '#55CC55', '#CC50CC'];

const links = document.querySelectorAll('.button_inner');

links.forEach(function(div) {
  var rand = colors[Math.floor(Math.random() * colors.length)];
  div.style.backgroundColor = rand;
});