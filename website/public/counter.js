fetch("__API_URL__/count")
  .then(r => r.json())
  .then(data => {
    const el = document.getElementById("visitor-count");
    if (el) el.innerText = data.views;
  });
