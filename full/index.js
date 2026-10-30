// ../../home/hatch/workspace/your_files/nnyy-full/index.src.js
var KEY = "nnyy";
var NAME = "\u52AA\u52AA\u5F71\u9662";
var HOST = "https://nnyy.in";
var UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1";
var FULL_LINE_MAX_EPISODES = 30;
function abs(url, base = HOST) {
  const raw = String(url || "").trim();
  if (!raw) return "";
  if (/^https?:\/\//i.test(raw)) return raw;
  if (raw.startsWith("//")) return "https:" + raw;
  try {
    return new URL(raw, base).toString();
  } catch {
    return raw;
  }
}
function buildUrl(path, query) {
  const parts = [];
  for (const k in query) {
    const v = query[k];
    if (v !== void 0 && v !== null && v !== "") {
      parts.push(encodeURIComponent(k) + "=" + encodeURIComponent(String(v)));
    }
  }
  return HOST + path + (parts.length ? "?" + parts.join("&") : "");
}
function cleanText(s) {
  return String(s || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&nbsp;/g, " ").replace(/\s+/g, " ").trim();
}
function attr(tag, name) {
  const m = String(tag || "").match(new RegExp(name + `\\s*=\\s*["']([^"']*)["']`, "i"));
  return m ? m[1] : "";
}
async function fetchText(url) {
  try {
    let res;
    if (typeof AbortController !== "undefined") {
      const ctl = new AbortController();
      const timer = setTimeout(() => {
        try {
          ctl.abort();
        } catch {
        }
      }, 15e3);
      try {
        res = await fetch(url, {
          headers: { "User-Agent": UA, Referer: HOST + "/" },
          signal: ctl.signal
        });
      } finally {
        clearTimeout(timer);
      }
    } else {
      res = await fetch(url, { headers: { "User-Agent": UA, Referer: HOST + "/" } });
    }
    return await res.text();
  } catch {
    return "";
  }
}
async function getHtml(url) {
  return fetchText(url);
}
async function getJson(url) {
  const txt = await fetchText(url);
  if (!txt) return null;
  try {
    return JSON.parse(txt);
  } catch {
    return null;
  }
}
function bodyOf(reqIn) {
  return reqIn?.body || {};
}
function pageOf(value) {
  const page = Number.parseInt(value, 10);
  return Number.isFinite(page) && page > 0 ? page : 1;
}
function filtersOf(reqIn) {
  const body = bodyOf(reqIn);
  return body.filters || body.extend || body.ext || body.filter || {};
}
function parseList(html, base) {
  const list = [];
  const liBlocks = String(html || "").match(/<li[\s\S]*?<\/li>/gi) || [];
  for (const li of liBlocks) {
    const aTags = li.match(/<a[^>]*>/gi) || [];
    let href = "";
    for (const t of aTags) {
      if (/thumbnail/i.test(t)) {
        href = attr(t, "href");
        break;
      }
    }
    if (!href) continue;
    const imgTags = li.match(/<img[^>]*>/gi) || [];
    let pic = "";
    let alt = "";
    if (imgTags.length) {
      pic = attr(imgTags[0], "data-src") || attr(imgTags[0], "src");
      alt = attr(imgTags[0], "alt");
    }
    let title = "";
    const h2 = li.match(/<h2[\s\S]*?<\/h2>/i);
    if (h2) {
      const aInH2 = h2[0].match(/<a[^>]*>([\s\S]*?)<\/a>/i);
      title = cleanText(aInH2 ? aInH2[1] : h2[0]) || alt;
    } else {
      title = alt;
    }
    if (!title) continue;
    let note = "";
    const noteM = li.match(/class="[^"]*\bnote\b[^"]*"[^>]*>\s*<span[^>]*>([\s\S]*?)<\/span>/i);
    if (noteM) note = cleanText(noteM[1]);
    let countrie = "";
    const counM = li.match(/class="[^"]*\bcountrie\b[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
    if (counM) {
      const spans = counM[1].match(/<span[^>]*>([\s\S]*?)<\/span>/gi) || [];
      countrie = spans.map((s) => cleanText(s)).filter(Boolean).join(" ");
    }
    const remarks = [note, countrie].filter(Boolean).join(" ");
    list.push({
      vod_id: href,
      vod_name: title,
      vod_pic: abs(pic, base),
      vod_remarks: remarks
    });
  }
  return list;
}
async function init() {
  return {};
}
async function home() {
  const classes = [
    { type_id: "dianying", type_name: "\u7535\u5F71" },
    { type_id: "dianshiju", type_name: "\u7535\u89C6\u5267" },
    { type_id: "zongyi", type_name: "\u7EFC\u827A" },
    { type_id: "dongman", type_name: "\u52A8\u6F2B" }
  ];
  const genre = [
    { n: "\u5168\u90E8", v: "" },
    { n: "\u5267\u60C5", v: "ju-qing" },
    { n: "\u559C\u5267", v: "xi-ju" },
    { n: "\u7231\u60C5", v: "ai-qing" },
    { n: "\u52A8\u4F5C", v: "dong-zuo" },
    { n: "\u60CA\u609A", v: "jing-song" },
    { n: "\u72AF\u7F6A", v: "fan-zui" },
    { n: "\u60AC\u7591", v: "xuan-yi" },
    { n: "\u79D1\u5E7B", v: "ke-huan" },
    { n: "\u5947\u5E7B", v: "qi-huan" },
    { n: "\u6218\u4E89", v: "zhan-zheng" },
    { n: "\u5BB6\u5EAD", v: "jia-ting" },
    { n: "\u5386\u53F2", v: "li-shi" },
    { n: "\u9752\u6625", v: "qing-chun" }
  ];
  const country = [
    { n: "\u5168\u90E8", v: "" },
    { n: "\u5927\u9646", v: "cn" },
    { n: "\u7F8E\u56FD", v: "us" },
    { n: "\u9999\u6E2F", v: "hk" },
    { n: "\u53F0\u6E7E", v: "tw" },
    { n: "\u65E5\u672C", v: "jp" },
    { n: "\u97E9\u56FD", v: "kr" },
    { n: "\u82F1\u56FD", v: "gb" },
    { n: "\u6CD5\u56FD", v: "fr" },
    { n: "\u5FB7\u56FD", v: "de" },
    { n: "\u610F\u5927\u5229", v: "it" },
    { n: "\u5370\u5EA6", v: "in" },
    { n: "\u6CF0\u56FD", v: "th" },
    { n: "\u4FC4\u7F57\u65AF", v: "ru" }
  ];
  const year = [{ n: "\u5168\u90E8", v: "" }];
  for (let y = 2026; y >= 2010; y--) year.push({ n: String(y), v: String(y) });
  year.push({ n: "2010\u4EE5\u524D", v: "lt__2010" });
  const ob = [
    { n: "\u6309\u65F6\u95F4", v: "" },
    { n: "\u6309\u4EBA\u6C14", v: "click" },
    { n: "\u6309\u8BC4\u5206", v: "rating" }
  ];
  const filters = {};
  for (const c of classes) {
    filters[c.type_id] = [
      { key: "genre", name: "\u7C7B\u578B", value: genre },
      { key: "country", name: "\u5730\u533A", value: country },
      { key: "year", name: "\u5E74\u4EFD", value: year },
      { key: "ob", name: "\u6392\u5E8F", value: ob }
    ];
  }
  return { class: classes, filters, list: [] };
}
async function homeVod() {
  const html = await getHtml(buildUrl("/dianying/", { page: 1 }));
  return { list: parseList(html, HOST) };
}
async function category(reqIn) {
  const body = bodyOf(reqIn);
  const page = pageOf(body.page);
  let cat = String(body.id || "dianying").replace(/^\/+|\/+$/g, "");
  cat = cat.split("/")[0] || "dianying";
  if (!["dianying", "dianshiju", "zongyi", "dongman"].includes(cat)) cat = "dianying";
  const f = filtersOf(reqIn);
  const html = await getHtml(buildUrl("/" + cat + "/", {
    genre: f.genre,
    country: f.country,
    year: f.year,
    ob: f.ob,
    page
  }));
  const list = parseList(html, HOST);
  return {
    page,
    pagecount: list.length > 0 ? page + 1 : page,
    limit: 24,
    total: list.length > 0 ? page * 24 + 1 : 0,
    list
  };
}
function numericIdOf(detailPath) {
  const m = String(detailPath || "").match(/(\d+)\.html/);
  return m ? m[1] : "";
}
function parseEpisodes(html) {
  const eps = [];
  const liBlocks = String(html || "").match(/<li[^>]*>[\s\S]*?<\/li>/gi) || [];
  for (const li of liBlocks) {
    const openTag = li.match(/<li[^>]*>/i);
    if (!openTag) continue;
    if (!/play-btn/i.test(openTag[0])) continue;
    const slug = attr(openTag[0], "ep_slug");
    if (!slug) continue;
    const aM = li.match(/<a[^>]*>([\s\S]*?)<\/a>/i);
    const name = (aM ? cleanText(aM[1]) : "") || slug;
    eps.push({ slug, name });
  }
  if (eps.length > 1 && eps.every((e) => /^ep\d+$/.test(e.slug))) eps.reverse();
  return eps;
}
async function fetchPlays(numericId, slug) {
  const data = await getJson(HOST + "/_gp/" + numericId + "/" + slug);
  if (!data || !Array.isArray(data.video_plays)) return [];
  return data.video_plays.map((p) => ({ site: String(p.src_site || ""), url: String(p.play_data || "") })).filter((p) => p.url);
}
async function detail(reqIn) {
  const ids = Array.isArray(bodyOf(reqIn).id) ? bodyOf(reqIn).id : [bodyOf(reqIn).id];
  const list = [];
  for (const id of ids.filter(Boolean)) {
    const detailUrl = abs(id);
    const html = await getHtml(detailUrl);
    let vodName = "";
    let year = "";
    const titleM = html.match(/<h1[^>]*class="[^"]*product-title[^"]*"[^>]*>([\s\S]*?)<\/h1>/i);
    if (titleM) {
      const inner = titleM[1];
      const spanM = inner.match(/<span[^>]*>([\s\S]*?)<\/span>/i);
      if (spanM) year = cleanText(spanM[1]).replace(/[^0-9]/g, "");
      vodName = cleanText(inner.replace(/<span[^>]*>[\s\S]*?<\/span>/gi, ""));
    }
    let vodPic = "";
    const imgTags = html.match(/<img[^>]*>/gi) || [];
    for (const t of imgTags) {
      if (/detail-img/i.test(t)) {
        vodPic = abs(attr(t, "src"), detailUrl);
        break;
      }
    }
    let director = "";
    let actor = "";
    let typeName = "";
    let area = "";
    let content = "";
    const excerptBlocks = html.match(/<div[^>]*class="[^"]*product-excerpt[^"]*"[^>]*>([\s\S]*?)<\/div>/gi) || [];
    for (const block of excerptBlocks) {
      const text = cleanText(block);
      const spanM = block.match(/<span[^>]*>([\s\S]*?)<\/span>/i);
      const value = spanM ? cleanText(spanM[1]) : "";
      if (text.startsWith("\u5BFC\u6F14")) director = value;
      else if (text.startsWith("\u4E3B\u6F14")) actor = value;
      else if (text.startsWith("\u7C7B\u578B")) typeName = value;
      else if (text.startsWith("\u5236\u7247\u56FD\u5BB6")) area = value;
      else if (text.startsWith("\u5267\u60C5\u7B80\u4ECB")) content = value;
    }
    void typeName;
    const episodes = parseEpisodes(html);
    const numericId = numericIdOf(id);
    let vodPlayFrom = "\u9ED8\u8BA4";
    let vodPlayUrl = "";
    if (episodes.length && numericId && episodes.length <= FULL_LINE_MAX_EPISODES) {
      const lineNames = [];
      const lineEpisodes = {};
      for (const ep of episodes) {
        const plays = await fetchPlays(numericId, ep.slug).catch(() => []);
        for (const p of plays) {
          if (!lineNames.includes(p.site)) {
            lineNames.push(p.site);
            lineEpisodes[p.site] = [];
          }
          lineEpisodes[p.site].push(ep.name + "$" + p.url);
        }
      }
      if (lineNames.length) {
        vodPlayFrom = lineNames.join("$$$");
        vodPlayUrl = lineNames.map((n) => lineEpisodes[n].join("#")).join("$$$");
      } else {
        vodPlayUrl = episodes.map((ep) => ep.name + "$" + numericId + ":" + ep.slug).join("#");
      }
    } else {
      vodPlayUrl = episodes.map((ep) => ep.name + "$" + numericId + ":" + ep.slug).join("#");
    }
    list.push({
      vod_id: id,
      vod_name: vodName,
      vod_pic: vodPic,
      vod_year: year,
      vod_area: area,
      vod_actor: actor,
      vod_director: director,
      vod_content: content,
      vod_play_from: vodPlayFrom,
      vod_play_url: vodPlayUrl
    });
  }
  return { list };
}
async function play(reqIn) {
  const body = bodyOf(reqIn);
  const id = String(body.id || "").trim();
  if (/^https?:\/\//i.test(id)) {
    return { parse: 0, url: id, header: { "User-Agent": UA, Referer: HOST + "/" } };
  }
  const m = id.match(/^(\d+):(.+)$/);
  if (!m) return { parse: 0, url: "", message: "\u672A\u8BC6\u522B\u7684\u64AD\u653E id" };
  const plays = await fetchPlays(m[1], m[2]).catch(() => []);
  if (!plays.length) return { parse: 0, url: "", message: "\u672A\u63D0\u53D6\u5230\u64AD\u653E\u5730\u5740" };
  return {
    parse: 0,
    url: plays[0].url,
    header: { "User-Agent": UA, Referer: HOST + "/" }
  };
}
async function search(reqIn) {
  const body = bodyOf(reqIn);
  const page = pageOf(body.page);
  const wd = String(body.wd || "").trim();
  if (!wd) return { page, pagecount: page, limit: 20, total: 0, list: [] };
  const html = await getHtml(buildUrl("/so", { q: wd, page }));
  const list = parseList(html, HOST);
  return {
    page,
    pagecount: list.length > 0 ? page + 1 : page,
    limit: 20,
    total: list.length > 0 ? page * 20 + 1 : 0,
    list
  };
}
function createSpider() {
  return {
    meta: { key: KEY, name: NAME, type: 3 },
    api: async (fastify) => {
      fastify.post("/init", init);
      fastify.post("/home", home);
      fastify.post("/homeVod", homeVod);
      fastify.post("/category", category);
      fastify.post("/detail", detail);
      fastify.post("/play", play);
      fastify.post("/search", search);
    },
    check: async () => true
  };
}
createSpider.meta = { key: KEY, name: NAME, type: 3 };
createSpider.api = async (fastify) => {
  fastify.post("/init", init);
  fastify.post("/home", home);
  fastify.post("/homeVod", homeVod);
  fastify.post("/category", category);
  fastify.post("/detail", detail);
  fastify.post("/play", play);
  fastify.post("/search", search);
};
export {
  createSpider as default
};
