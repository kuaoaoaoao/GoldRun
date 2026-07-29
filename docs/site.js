(function () {
  "use strict";

  var navToggle = document.querySelector(".nav-toggle");
  var navLinks = document.querySelector(".nav-links");

  if (navToggle && navLinks) {
    navToggle.addEventListener("click", function () {
      var isOpen = navToggle.getAttribute("aria-expanded") === "true";
      navToggle.setAttribute("aria-expanded", String(!isOpen));
      navLinks.classList.toggle("is-open", !isOpen);
    });

    navLinks.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        navToggle.setAttribute("aria-expanded", "false");
        navLinks.classList.remove("is-open");
      });
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && navToggle.getAttribute("aria-expanded") === "true") {
        navToggle.setAttribute("aria-expanded", "false");
        navLinks.classList.remove("is-open");
        navToggle.focus();
      }
    });
  }

  var heroPreview = document.getElementById("hero-preview");
  var heroTabs = document.querySelectorAll(".hero-tab");

  heroTabs.forEach(function (tab) {
    tab.addEventListener("click", function () {
      if (!heroPreview || tab.classList.contains("is-active")) {
        return;
      }

      heroTabs.forEach(function (item) {
        var isCurrent = item === tab;
        item.classList.toggle("is-active", isCurrent);
        item.setAttribute("aria-pressed", String(isCurrent));
      });

      heroPreview.classList.add("is-changing");
      window.setTimeout(function () {
        heroPreview.src = tab.dataset.heroImage;
        heroPreview.alt = tab.dataset.heroAlt;
        heroPreview.classList.remove("is-changing");
      }, 150);
    });
  });

  var featureTabs = document.querySelectorAll(".feature-tab");
  var featurePanels = document.querySelectorAll(".feature-panel");

  featureTabs.forEach(function (tab) {
    tab.addEventListener("click", function () {
      featureTabs.forEach(function (item) {
        var isCurrent = item === tab;
        item.classList.toggle("is-active", isCurrent);
        item.setAttribute("aria-selected", String(isCurrent));
      });

      featurePanels.forEach(function (panel) {
        panel.hidden = panel.id !== tab.dataset.panel;
      });
    });

    tab.addEventListener("keydown", function (event) {
      var handledKeys = ["ArrowDown", "ArrowRight", "ArrowUp", "ArrowLeft", "Home", "End"];
      if (!handledKeys.includes(event.key)) {
        return;
      }

      event.preventDefault();
      var currentIndex = Array.prototype.indexOf.call(featureTabs, tab);
      var nextIndex = currentIndex;

      if (event.key === "ArrowDown" || event.key === "ArrowRight") {
        nextIndex = (currentIndex + 1) % featureTabs.length;
      } else if (event.key === "ArrowUp" || event.key === "ArrowLeft") {
        nextIndex = (currentIndex - 1 + featureTabs.length) % featureTabs.length;
      } else if (event.key === "Home") {
        nextIndex = 0;
      } else if (event.key === "End") {
        nextIndex = featureTabs.length - 1;
      }

      featureTabs[nextIndex].focus();
      featureTabs[nextIndex].click();
    });
  });

  var year = document.getElementById("year");
  if (year) {
    year.textContent = String(new Date().getFullYear());
  }

  var revealItems = document.querySelectorAll(".reveal");
  var reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (!("IntersectionObserver" in window) || reducedMotion) {
    revealItems.forEach(function (item) {
      item.classList.add("is-visible");
    });
    return;
  }

  var observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.12,
    rootMargin: "0px 0px -40px"
  });

  revealItems.forEach(function (item) {
    observer.observe(item);
  });
}());
