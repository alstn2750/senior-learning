(function () {
  var html = document.documentElement;
  var FONT_KEY = 'ieum-font-size';
  var CONTRAST_KEY = 'ieum-contrast';

  function applyFontSize(size) {
    if (size === 'base') {
      html.removeAttribute('data-font-size');
    } else {
      html.setAttribute('data-font-size', size);
    }
    document.querySelectorAll('[data-font-btn]').forEach(function (btn) {
      btn.classList.toggle('is-active', btn.getAttribute('data-font-btn') === size);
    });
    localStorage.setItem(FONT_KEY, size);
  }

  function applyContrast(isHigh) {
    if (isHigh) {
      html.setAttribute('data-contrast', 'high');
    } else {
      html.removeAttribute('data-contrast');
    }
    var btn = document.querySelector('[data-contrast-btn]');
    if (btn) btn.classList.toggle('is-active', isHigh);
    localStorage.setItem(CONTRAST_KEY, isHigh ? '1' : '0');
  }

  document.addEventListener('DOMContentLoaded', function () {
    var savedFont = localStorage.getItem(FONT_KEY) || 'base';
    applyFontSize(savedFont);
    applyContrast(localStorage.getItem(CONTRAST_KEY) === '1');

    document.querySelectorAll('[data-font-btn]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        applyFontSize(btn.getAttribute('data-font-btn'));
      });
    });

    var contrastBtn = document.querySelector('[data-contrast-btn]');
    if (contrastBtn) {
      contrastBtn.addEventListener('click', function () {
        applyContrast(html.getAttribute('data-contrast') !== 'high');
      });
    }

    document.querySelectorAll('[data-plan-pricing]').forEach(function (form) {
      var frequency = form.querySelector('[name="weeklyFrequency"]');
      var output = form.querySelector('[data-monthly-price]');
      var basePrice = Number(form.getAttribute('data-base-price')) || 0;
      function updatePrice() {
        output.textContent = (basePrice * Number(frequency.value)).toLocaleString('ko-KR') + '원';
      }
      frequency.addEventListener('change', updatePrice);
      updatePrice();
    });

    // flash 메시지 자동 사라짐
    document.querySelectorAll('.flash').forEach(function (el) {
      setTimeout(function () {
        el.style.transition = 'opacity 0.4s ease';
        el.style.opacity = '0';
        setTimeout(function () { el.remove(); }, 400);
      }, 4500);
    });
  });
})();
