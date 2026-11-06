const select = document.getElementById('color');

const urlParams = new URLSearchParams(window.location.search);
const colorParam = urlParams.get('color');

if(colorParam)select.value = colorParam;
document.body.className = colorParam;



select.addEventListener('change', (e) => {
  document.body.className = e.target.value;
  const url = new URL(window.location);
  url.searchParams.set('color', e.target.value);
  window.history.replaceState(null, '', url.toString());
});
