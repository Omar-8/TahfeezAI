// TahfeezAI's site: English or Arabic, light or dark, the screens carousel.
(() => {
  const ar = {
    "nav.features": "المزايا",
    "nav.tajweed": "التجويد",
    "nav.screens": "لقطات",
    "nav.privacy": "الخصوصية",
    "hero.eyebrow": "مجاني · بلا إنترنت · بلا إعلانات",
    "hero.title": "احفظ القرآن ومعك مستمعٌ في جيبك",
    "hero.lead": "اقرأ مصحف المدينة، وافهم كل كلمة، وسمِّع من حفظك بينما يتابعك ذكاءٌ اصطناعي يعمل على هاتفك — فينبّهك إلى الكلمة التي سقطت والمدّ الذي قصُر.",
    "chip.free": "مجاني ١٠٠٪",
    "chip.offline": "يعمل دون إنترنت",
    "chip.ads": "بلا إعلانات",
    "chip.account": "بلا حساب",
    "chip.ai": "الذكاء الاصطناعي على هاتفك",
    "store.soon": "قريبًا على",
    "store.open": "مفتوح المصدر على",
    "ayah.meaning": "سورة القمر ٥٤:١٧",
    "features.title": "كل ما تحتاجه في رحلتك مع القرآن",
    "f.read.t": "اقرأ المصحف",
    "f.read.d": "مصحف المدينة صفحةً صفحة كما طُبع — أو آيةً آية، بالتقليب أو بتمريرٍ متصل.",
    "f.understand.t": "افهم كل كلمة",
    "f.understand.d": "معاني الكلمات (وبالعربية من السراج)، والنطق اللاتيني، وترجمات بثماني عشرة لغة، والتفسير بجانب كل آية — بلغتك.",
    "f.listen.t": "استمع إلى ٢٨ قارئًا",
    "f.listen.d": "العفاسي، والحصري، والمنشاوي، وعبد الباسط، والسديس، والغامدي، والدوسري وغيرهم — وتُضاء الآية حين تُتلى. نزّل المصحف كاملًا أو جزءًا أو سورة واحدة.",
    "f.recite.t": "سمِّع مع التصحيح",
    "f.recite.d": "سمِّع من حفظك: تتوهّج الكلمة الصحيحة وتهتز الخاطئة، وتتلوّن الكلمات أثناء التلاوة — مع التحقق من التجويد، وحلقةٌ تتنفّس مع صوتك.",
    "f.memorize.t": "احفظ بخطة",
    "f.memorize.d": "وضع الإخفاء، والتكرار، والقراءة مع القارئ، ودرسٌ يومي ومراجعةٌ متباعدة — وأيامك المتتالية، وتقويم أيامك، وحلقة الأجزاء الثلاثين، ومحطاتٌ لطيفة.",
    "f.yours.t": "اجعله على ذوقك",
    "f.yours.d": "سماءٌ بألوان وقت اليوم، وبطاقاتٌ زجاجية، وزخرفةٌ هندسية إسلامية؛ وأسماء السور بخط المصحف؛ ووضع التركيز؛ ٥ سمات و٤ خطوط للقرآن ونص حتى ٢٠٠٪؛ بتسع عشرة لغة.",
    "tj.eyebrow": "تصحيح التجويد",
    "tj.title": "يستمع إلى <em>كيف</em> تقرأ — لا إلى ماذا فقط",
    "tj.lead": "نموذجٌ صوتي يقارن كل كلمة تقولها بنطقها المتوقّع برواية حفص، صوتًا صوتًا — على هاتفك، دون إنترنت.",
    "tj.madd": "المدّ",
    "tj.madd.d": "إتمام زمن المدود",
    "tj.qalqala": "القلقلة",
    "tj.qalqala.d": "نبرة «قطب جد»",
    "tj.ghunnah": "الغنّة",
    "tj.ghunnah.d": "الإخفاء والإقلاب والإدغام — وإتمام غنة النون والميم المشددتين حركتين",
    "tj.heavy": "التفخيم والترقيق",
    "tj.heavy.d": "ط ت · ص س · ض د · ظ ذ · ق ك",
    "tj.throat": "الحروف الحلقية",
    "tj.throat.d": "ء ع ح ه خ غ",
    "tj.shadda": "الشدّة والحركات",
    "tj.shadda.d": "الحروف المشدّدة، والحركات، وأواخر الكلم",
    "tj.note": "النموذج ما زال يتعلّم: قد يفوته خطأ أو ينبّه على كلمةٍ صحيحة. يتحسّن مع كل إصدار — وملاحظاتك تساعدنا.",
    "screens.title": "نظرة أقرب",
    "pv.title": "هديةٌ لا سلعة",
    "pv.ads.t": "إعلانات أو اشتراكات أو مشتريات",
    "pv.ads.d": "مجاني للجميع، دائمًا.",
    "pv.voice.t": "صوتك يبقى على هاتفك",
    "pv.voice.d": "تُفحص التلاوة على الجهاز ثم تُحذف. بلا حساب ولا تحليلات ولا تتبّع.",
    "pv.offline.t": "يعمل دون إنترنت",
    "pv.offline.d": "القراءة والترجمات والتفسير والبحث والحفظ وتصحيح التلاوة — دون إنترنت. نزّل قارئًا — المصحف كاملًا أو جزءًا أو سورة — لتستمع دون إنترنت أيضًا.",
    "dl.title": "قريبًا على أندرويد وآيفون",
    "dl.lead": "تحفيظ AI مفتوح المصدر برخصة GPL-3.0. ضع نجمةً على GitHub لتتابع الإطلاق — أو ابنِه بنفسك اليوم.",
    "ft.credits": "شكرًا لمشروع تنزيل، ومجمع الملك فهد، وQuran Engine، وQUL (ترتيل)، وQuranEnc، وquran.com، وeveryayah.com، والقرّاء، ومؤلفي نموذج المعلّم.",
    "ft.privacy": "الخصوصية",
  };

  // English: what the page holds.
  const en = {};
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    en[el.dataset.i18n] = el.innerHTML;
  });

  const store = {
    get: (k) => { try { return localStorage.getItem(k); } catch { return null; } },
    set: (k, v) => { try { localStorage.setItem(k, v); } catch { /* no storage */ } },
  };

  const langBtn = document.getElementById("lang");
  function setLang(lang) {
    const dict = lang === "ar" ? ar : en;
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const text = dict[el.dataset.i18n];
      if (text !== undefined) el.innerHTML = text;
    });
    langBtn.textContent = lang === "ar" ? "English" : "العربية";
    store.set("lang", lang);
  }
  langBtn.addEventListener("click", () =>
    setLang(document.documentElement.lang === "ar" ? "en" : "ar"));
  const preferred = store.get("lang") ||
    ((navigator.language || "").startsWith("ar") ? "ar" : "en");
  if (preferred === "ar") setLang("ar");

  const themeBtn = document.getElementById("theme");
  const savedTheme = store.get("theme");
  if (savedTheme) document.documentElement.dataset.theme = savedTheme;
  themeBtn.addEventListener("click", () => {
    const dark = document.documentElement.dataset.theme
      ? document.documentElement.dataset.theme === "dark"
      : matchMedia("(prefers-color-scheme: dark)").matches;
    const next = dark ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    store.set("theme", next);
  });

  const carousel = document.getElementById("carousel");
  document.querySelectorAll(".carousel-nav button").forEach((b) => {
    b.addEventListener("click", () => {
      const rtl = document.documentElement.dir === "rtl";
      const step = carousel.clientWidth * 0.8 * Number(b.dataset.dir);
      carousel.scrollBy({ left: rtl ? -step : step, behavior: "smooth" });
    });
  });
})();
