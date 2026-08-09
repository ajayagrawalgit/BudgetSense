/* ==========================================================================
   BudgetSense animated landing (vanilla JS, no dependencies)
   - falling coin/particle field on a canvas behind the hero
   - mouse parallax on the hero stage
   - reveal-on-scroll (.bs-fade -> .in) with card stagger
   - "anxiety" notifications sweep away when the problem scene is read
   - count-up numbers
   - interactive, clickable no-spend grid
   - top scroll-progress bar
   Respects prefers-reduced-motion.
   ========================================================================== */
(function () {
  "use strict";

  var reduce =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---- Coin particle field ------------------------------------------ */
  function initCoins() {
    var canvas = document.getElementById("bs-coins");
    if (!canvas || reduce) return;
    var ctx = canvas.getContext("2d");
    var coins = [];
    var raf = null;
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    var colors = ["#8ca386", "#b98d6f", "#cbb48a", "#a7b8a0", "#d8c9a3"];

    function size() {
      var r = canvas.getBoundingClientRect();
      canvas.width = r.width * dpr;
      canvas.height = r.height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      return r;
    }
    var rect = size();

    function make() {
      var w = rect.width;
      return {
        x: Math.random() * w,
        y: Math.random() * -rect.height,
        r: 5 + Math.random() * 10,
        vy: 0.18 + Math.random() * 0.5,
        vx: -0.1 + Math.random() * 0.2,
        spin: -0.025 + Math.random() * 0.05,
        a: Math.random() * Math.PI,
        sway: 0.4 + Math.random() * 1.1,
        swayA: Math.random() * Math.PI * 2,
        swaySpeed: 0.012 + Math.random() * 0.02,
        c: colors[(Math.random() * colors.length) | 0],
        o: 0.12 + Math.random() * 0.2,
      };
    }
    var count = Math.max(20, Math.min(52, Math.floor(rect.width / 26)));
    for (var i = 0; i < count; i++) {
      var c = make();
      c.y = Math.random() * rect.height;
      coins.push(c);
    }

    function draw() {
      ctx.clearRect(0, 0, rect.width, rect.height);
      for (var i = 0; i < coins.length; i++) {
        var c = coins[i];
        c.y += c.vy;
        c.swayA += c.swaySpeed;
        c.x += c.vx + Math.sin(c.swayA) * c.sway;
        c.a += c.spin;
        if (c.y - c.r > rect.height) {
          coins[i] = make();
          continue;
        }
        ctx.save();
        ctx.translate(c.x, c.y);
        ctx.rotate(c.a);
        ctx.globalAlpha = c.o;
        ctx.fillStyle = c.c;
        // a coin = a squished ellipse so it looks like it is spinning
        ctx.beginPath();
        ctx.ellipse(0, 0, c.r, c.r * (0.4 + 0.6 * Math.abs(Math.cos(c.a))), 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      }
      raf = requestAnimationFrame(draw);
    }
    draw();

    var to;
    window.addEventListener("resize", function () {
      clearTimeout(to);
      to = setTimeout(function () {
        rect = size();
      }, 200);
    });

    // Pause when the hero is off-screen (save battery).
    if ("IntersectionObserver" in window) {
      var hero = document.getElementById("bs-hero");
      var io = new IntersectionObserver(function (e) {
        if (e[0].isIntersecting) {
          if (!raf) draw();
        } else {
          cancelAnimationFrame(raf);
          raf = null;
        }
      });
      if (hero) io.observe(hero);
    }
  }

  /* ---- Hero mouse parallax ------------------------------------------ */
  function initParallax() {
    if (reduce) return;
    var stage = document.querySelector("[data-parallax]");
    var hero = document.getElementById("bs-hero");
    if (!stage || !hero) return;
    hero.addEventListener("mousemove", function (e) {
      var r = hero.getBoundingClientRect();
      var dx = (e.clientX - r.left) / r.width - 0.5;
      var dy = (e.clientY - r.top) / r.height - 0.5;
      stage.style.transform =
        "translate(" + dx * 18 + "px," + dy * 14 + "px)";
    });
    hero.addEventListener("mouseleave", function () {
      stage.style.transform = "";
    });
  }

  /* ---- Reveal on scroll --------------------------------------------- */
  function initReveal() {
    var items = document.querySelectorAll(".bs-fade");
    // stagger index for cards
    document.querySelectorAll(".bs-cards .bs-card").forEach(function (c, i) {
      c.style.setProperty("--i", i);
    });
    if (!items.length) return;
    if (reduce || !("IntersectionObserver" in window)) {
      items.forEach(function (el) {
        el.classList.add("in");
      });
      return;
    }
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("in");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15, rootMargin: "0px 0px -6% 0px" }
    );
    items.forEach(function (el) {
      io.observe(el);
    });
  }

  /* ---- Anxiety sweep ------------------------------------------------- */
  function initSweep() {
    var scene = document.getElementById("bs-problem");
    if (!scene || !("IntersectionObserver" in window)) return;
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          // Once the reader has settled on the scene, calm the chaos.
          if (entry.isIntersecting && entry.intersectionRatio > 0.55) {
            setTimeout(function () {
              scene.classList.add("is-calm");
            }, 1200);
            io.unobserve(scene);
          }
        });
      },
      { threshold: [0, 0.55, 1] }
    );
    io.observe(scene);
  }

  /* ---- Count up ------------------------------------------------------ */
  function animateCount(el) {
    var target = parseFloat(el.getAttribute("data-countup"));
    var suffix = el.getAttribute("data-suffix") || "";
    if (reduce) {
      el.textContent = target + suffix;
      return;
    }
    var start = null;
    var dur = 1500;
    function step(ts) {
      if (start === null) start = ts;
      var p = Math.min((ts - start) / dur, 1);
      var eased = 1 - Math.pow(1 - p, 3);
      el.textContent = Math.round(target * eased) + suffix;
      if (p < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }
  function initCounts() {
    var nums = document.querySelectorAll("[data-countup]");
    if (!nums.length) return;
    if (!("IntersectionObserver" in window)) {
      nums.forEach(animateCount);
      return;
    }
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            animateCount(entry.target);
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.6 }
    );
    nums.forEach(function (el) {
      io.observe(el);
    });
  }

  /* ---- Interactive no-spend grid ------------------------------------ */
  function initGrid() {
    var grid = document.getElementById("bs-grid");
    var countEl = document.getElementById("bs-grid-count");
    if (!grid) return;
    var total = 30;
    var preset = [1, 2, 5, 6, 9, 12, 13, 16, 20, 24, 25, 28];

    function refresh() {
      var on = grid.querySelectorAll(".bs-grid__cell.is-on").length;
      if (countEl) countEl.textContent = on;
    }

    for (var i = 0; i < total; i++) {
      var cell = document.createElement("button");
      cell.type = "button";
      cell.className = "bs-grid__cell";
      cell.setAttribute("aria-label", "Toggle day " + (i + 1));
      cell.addEventListener("click", function () {
        this.classList.toggle("is-on");
        refresh();
      });
      grid.appendChild(cell);
    }
    var cells = grid.querySelectorAll(".bs-grid__cell");

    function seed() {
      preset.forEach(function (idx, k) {
        if (reduce) {
          cells[idx].classList.add("is-on");
          refresh();
          return;
        }
        setTimeout(function () {
          cells[idx].classList.add("is-on");
          refresh();
        }, 300 + k * 90);
      });
    }

    if (reduce || !("IntersectionObserver" in window)) {
      seed();
      return;
    }
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            seed();
            io.unobserve(grid);
          }
        });
      },
      { threshold: 0.4 }
    );
    io.observe(grid);
  }

  /* ---- Scroll progress bar ------------------------------------------ */
  function initProgress() {
    var bar = document.getElementById("bs-progress");
    if (!bar) return;
    function onScroll() {
      var h = document.documentElement;
      var max = h.scrollHeight - h.clientHeight;
      var pct = max > 0 ? (h.scrollTop / max) * 100 : 0;
      bar.style.width = pct + "%";
    }
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  /* ---- Widget showcase ---------------------------------------------- */
  function fmt(n) {
    try { return Math.round(n).toLocaleString("en-IN"); }
    catch (e) { return String(Math.round(n)); }
  }
  function runCounts(root) {
    root.querySelectorAll("[data-c]").forEach(function (el) {
      var target = parseFloat(el.getAttribute("data-c"));
      var pre = el.getAttribute("data-prefix") || "";
      var suf = el.getAttribute("data-suffix") || "";
      if (reduce) { el.textContent = pre + fmt(target) + suf; return; }
      var start = null, dur = 1300;
      function step(ts) {
        if (start === null) start = ts;
        var p = Math.min((ts - start) / dur, 1);
        var e = 1 - Math.pow(1 - p, 3);
        el.textContent = pre + fmt(target * e) + suf;
        if (p < 1) requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
    });
  }

  var WIDGET_HTML = {
    balance:
      '<span class="bs-w-cap">Balance this month</span>' +
      '<span class="bs-w-num" data-c="24860" data-prefix="\u20b9">\u20b90</span>',
    overview:
      '<div class="bs-w-row">' +
        '<div class="bs-w-cell up"><small>In</small><b>\u20b968.4k</b></div>' +
        '<div class="bs-w-cell down"><small>Out</small><b>\u20b943.5k</b></div>' +
        '<div class="bs-w-cell"><small>Invested</small><b>\u20b912k</b></div>' +
      '</div>' +
      '<span class="bs-w-cap" style="margin-top:.45rem">Balance</span>' +
      '<span class="bs-w-num bs-w-num--sm" data-c="24860" data-prefix="\u20b9">\u20b90</span>',
    buckets:
      bar("Food", 82) + bar("Rent", 62) + bar("Travel", 44) + bar("Bills", 28),
    insights:
      '<div class="bs-w-cols">' +
        '<div class="bs-w-colwrap"><div class="bs-w-col bs-w-col--in" style="--h:82%"></div><small>Income</small></div>' +
        '<div class="bs-w-colwrap"><div class="bs-w-col bs-w-col--out" style="--h:56%"></div><small>Expenses</small></div>' +
      '</div>',
    rates:
      '<div class="bs-w-rings">' +
        ring(34, 0.66, "var(--bs-sage)", "Saved") +
        ring(18, 0.82, "var(--bs-clay)", "Invested") +
      '</div>',
    runway:
      '<svg class="bs-w-spark" viewBox="0 0 120 56" preserveAspectRatio="none">' +
        '<path class="bs-w-spark__area" d="M2 40 L22 34 L42 38 L60 26 L78 30 L96 20 L96 54 L2 54 Z"/>' +
        '<path class="bs-w-spark__line" pathLength="1" d="M2 40 L22 34 L42 38 L60 26 L78 30 L96 20"/>' +
        '<path class="bs-w-spark__proj" pathLength="1" d="M96 20 L118 12"/>' +
      '</svg>' +
      '<div class="bs-w-row"><span class="bs-w-cap">\u20b9412 / day</span>' +
      '<span class="bs-w-cap" style="color:var(--bs-sage-deep)">on track</span></div>',
    nextdue:
      '<div class="bs-w-due"><span class="bs-w-due__pill">3 days</span>' +
        '<div><div class="bs-w-due__name">Home rent</div>' +
        '<div class="bs-w-due__sub">\u20b911,000 &middot; due on the 5th</div></div></div>' +
      '<div class="bs-w-track" style="margin-top:.55rem"><i class="bs-w-fill" style="--w:78%"></i></div>',
    glance:
      '<div class="bs-w-glance">' +
        '<div><b data-c="18">0</b><small>Expenses</small></div>' +
        '<div><b data-c="412" data-prefix="\u20b9">\u20b90</b><small>Average</small></div>' +
        '<div><b>\u20b93.2k</b><small>Biggest</small></div>' +
      '</div>',
    quickadd:
      '<div class="bs-w-add"><div class="bs-w-plus">+</div>' +
      '<span class="bs-w-add__lbl">Add expense</span></div>',
    actions:
      '<div class="bs-w-pills"><div class="bs-w-pill">+ Add expense</div>' +
      '<div class="bs-w-pill">Log \u20b9100 chai</div></div>',
    nospend: '<div class="bs-w-mini"></div>',
  };

  function bar(label, pct) {
    return '<div class="bs-w-bar"><span>' + label + '</span>' +
      '<div class="bs-w-track"><i class="bs-w-fill" style="--w:' + pct + '%"></i></div></div>';
  }
  function ring(pct, off, color, label) {
    return '<div class="bs-w-ring">' +
      '<svg viewBox="0 0 62 62" width="62" height="62">' +
        '<circle class="bs-w-ring__bg" cx="31" cy="31" r="27"/>' +
        '<circle class="bs-w-ring__val" cx="31" cy="31" r="27" pathLength="1" ' +
        'style="--off:' + off + ';stroke:' + color + '"/>' +
      '</svg>' +
      '<div class="bs-w-ring__lbl">' + pct + '%<small>' + label + '</small></div></div>';
  }

  function initWidgets() {
    var widgets = document.querySelectorAll(".bs-widget[data-widget]");
    if (!widgets.length) return;

    widgets.forEach(function (w) {
      var viz = w.querySelector(".bs-widget__viz");
      var type = w.getAttribute("data-widget");
      if (!viz || !WIDGET_HTML[type]) return;
      viz.innerHTML = WIDGET_HTML[type];
      if (type === "nospend") {
        var mini = viz.querySelector(".bs-w-mini");
        for (var i = 0; i < 21; i++) mini.appendChild(document.createElement("span"));
      }
    });

    function fire(w) {
      w.classList.add("go");
      runCounts(w);
      if (w.getAttribute("data-widget") === "nospend") {
        var cells = w.querySelectorAll(".bs-w-mini span");
        var on = [0, 1, 4, 6, 8, 9, 12, 15, 16, 19];
        on.forEach(function (idx, k) {
          if (!cells[idx]) return;
          if (reduce) { cells[idx].classList.add("on"); return; }
          setTimeout(function () { cells[idx].classList.add("on"); }, k * 70);
        });
      }
    }

    if (reduce || !("IntersectionObserver" in window)) {
      widgets.forEach(fire);
      return;
    }
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            fire(entry.target);
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.35 }
    );
    widgets.forEach(function (w) { io.observe(w); });
  }

  /* ---- Boot (only on the home page) --------------------------------- */
  function boot() {
    if (!document.querySelector(".bs-home")) return;
    initCoins();
    initParallax();
    initReveal();
    initSweep();
    initCounts();
    initGrid();
    initWidgets();
    initProgress();
  }

  if (window.document$ && typeof window.document$.subscribe === "function") {
    window.document$.subscribe(boot);
  } else if (document.readyState !== "loading") {
    boot();
  } else {
    document.addEventListener("DOMContentLoaded", boot);
  }
})();
