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
    </section>
  `;

  document.body.insertAdjacentHTML('beforeend', footerHTML);
});