document.addEventListener('DOMContentLoaded', function() {
  var footerHTML = `
    <hr>
    <section class="copyright" style="text-align: center;">
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
    <hr>
  `;

  document.body.insertAdjacentHTML('afterbegin', footerHTML);
});