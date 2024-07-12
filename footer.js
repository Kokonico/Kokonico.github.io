document.addEventListener('DOMContentLoaded', function() {
  var footerHTML = `
    <hr>
    <section class="copyright" style="text-align: center;">
      <p>© 2023 KKNC web wear</p>
      <p>
        <a href=index.html>Home</a>
        |
        <a href=about.html>About me</a>
        |
        <a href=index.html>Services</a>
        |
        <a href=index.html>Contact info</a>
      </p>
      <p>
      <a href="https://github.com/Kokonico"><img src="socials/github-mark-white.svg" width="25px" height="25px"></a>
      <a href="https://replit.com/@Kokonico"><img src="socials/Replit_Logo_Symbol.svg" width="25px" height="25"></a>
      <a href="https://www.youtube.com/channel/UC1m2DPc09SvbbNe1reTaZbw"><img src="socials/ytlogo.png" width="25px" height="25px"></a>
      <a href="https://gitlab.com/Kokonico" ><img src="socials/gitlab.svg" width="25px" height="25px"></a>
      <div id="webring-wrapper">
        <a href="https://webring.hackclub.com/" id="previousBtn" class="webring-anchor" title="Previous">‹</a>
        <a href="https://webring.hackclub.com/" class="webring-logo" title="Hack Club Webring" alt="Hack Club Webring"></a>
        <a href="https://webring.hackclub.com/" id="nextBtn" class="webring-anchor" title="Next">›</a>
      </div>
      </p>
    </section>
  `;

  function injectWebringScript() {
    const webringContainer = document.getElementById('webring-wrapper');
    const webringScript = document.createElement('script');
    webringScript.src = 'https://webring.hackclub.com/embed.min.js';
    webringContainer.appendChild(webringScript); 
  }

  

  document.body.insertAdjacentHTML('beforeend', footerHTML);
  injectWebringScript();
});