document.addEventListener('DOMContentLoaded', function() {
  var footerHTML = `
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
  `;

  document.body.insertAdjacentHTML('afterbegin', footerHTML);
});