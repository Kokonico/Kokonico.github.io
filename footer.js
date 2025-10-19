document.addEventListener('DOMContentLoaded', function() {
  var footerHTML = `
    <hr>
    <section class="copyright" style="text-align: center;">
      <p>© 2025 KKNC web wear</p>
      <p>
        <a href=index.html>Home</a>
        |
        <a href=about.html>About me</a>
        |
        <a href=services.html>Services</a>
        |
        <a href=contact.html>Contact info</a>
      </p>
    </section>
    <section class="socials" style="text-align: center;">
      <p>
          <a href="https://github.com/Kokonico"><img src="socials/github-mark-white.svg" width="25px" height="25px" alt="github"></a>
          <a href="https://replit.com/@Kokonico"><img src="socials/Replit_Logo_Symbol.svg" width="25px" height="25" alt="replit"></a>
          <a href="https://www.youtube.com/channel/UC1m2DPc09SvbbNe1reTaZbw"><img src="socials/ytlogo.png" width="25px" height="25px" alt="youtube"></a>
          <a href="https://gitlab.com/Kokonico" ><img src="socials/gitlab.svg" width="25px" height="25px" alt="gitlab"></a>
          <a href="https://codeberg.org/Kokonico"><img src="socials/Codeberg_Logo.svg" width="25px" height="25px" alt="codeberg"></a>
          <br>
          <a href="https://webring.hackclub.com/" style="display: inline-flex;">
            <iframe style="border:none; pointer-events: none;" src="https://webring.hackclub.com/embed.html" width="90px" height="60px"></iframe>
          </a>
      </p>
    </section>
  `;
  document.body.insertAdjacentHTML('beforeend', footerHTML);
});