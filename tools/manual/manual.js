// Default manual script: click a screenshot to enlarge it, click again to close.
(function () {
  var box = document.querySelector(".lightbox");
  if (!box) return;
  var big = box.querySelector("img");
  document.querySelectorAll("figure.shot a").forEach(function (a) {
    a.addEventListener("click", function (e) {
      e.preventDefault();
      big.src = a.getAttribute("href");
      box.hidden = false;
    });
  });
  box.addEventListener("click", function () { box.hidden = true; });
})();
