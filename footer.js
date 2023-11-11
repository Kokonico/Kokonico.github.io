document.addEventListener('DOMContentLoaded', function() {
  var footerHTML = `
    <hr>
    <section class="copyright" style="text-align: center;">
      <p>© 2023 KKNC web wear</p>
      <p>
        <a href=index.html>Home</a>
        |
        <a href=index.html>About us</a>
        |
        <a href=index.html>Services</a>
        |
        <a href=index.html>Contacting Us</a>
      </p>
      <p>
      <a href="https://github.com/Kokonico"><img src="socials/github-mark-white.svg" width="25px" height="25px"></a>
      <a href="https://replit.com/@Kokonico"><img src="socials/Replit_Logo_Symbol.svg" width="25px" height="25"></a>
      <a href="https://www.youtube.com/channel/UC1m2DPc09SvbbNe1reTaZbw"><img src="socials/ytlogo.png" width="25px" height="25px"></a>
      </p>
    </section>
  `;

  document.body.insertAdjacentHTML('beforeend', footerHTML);
});