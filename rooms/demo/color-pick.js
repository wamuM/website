const select = document.getElementById('color');
const toggle = document.getElementById('darkmode-toggle');

const urlParams = new URLSearchParams(window.location.search);
let color    = urlParams.get('color') || "none";
let darkmode = urlParams.get('dark') == 'true';

if(color)select.value = color;
         toggle.checked = darkmode;
updateClass()

function updateClass(){
    const url = new URL(window.location);
    if(darkmode) url.searchParams.set('dark','true');
    else url.searchParams.delete('dark');
    url.searchParams.set('color',color);
    window.history.replaceState(null, '', url.toString());
    document.body.className =`${darkmode? "darkmode":""} ${color}`;
}

select.addEventListener('change', (e) => {
    color = e.target.value;
    updateClass();
});

toggle.addEventListener('change', (e) => {
    darkmode = e.target.checked;
    updateClass();
});
