import req from '../../util/req.js';
import { load } from 'cheerio';

const KEY = 'nnyy';
const NAME = '努努影院';
const HOST = 'https://nnyy.in';
const UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

// 30 集以内：详情里把每集的 /_gp 都拉一遍，拼成多线路（vod_play_from $$$ 分隔），
// 播放时直接就是 m3u8，不用再解析。超过 30 集：详情只给“默认”单线路，
// 集的播放 id 是“数字id:ep_slug”，/play 再去拉 /_gp 取第一条线路，避免详情一次发上百个请求。
const FULL_LINE_MAX_EPISODES = 30;

function abs(url, base = HOST) {
  const raw = String(url || '').trim();
  if (!raw) return '';
  if (/^https?:\/\//i.test(raw)) return raw;
  if (raw.startsWith('//')) return 'https:' + raw;
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
    if (v !== undefined && v !== null && v !== '') {
      parts.push(encodeURIComponent(k) + '=' + encodeURIComponent(String(v)));
    }
  }
  return HOST + path + (parts.length ? '?' + parts.join('&') : '');
}

async function getHtml(url) {
  const { data } = await req.get(url, {
    headers: { 'User-Agent': UA, Referer: HOST + '/' },
    timeout: 15000,
  });
  return String(data || '');
}

async function getJson(url) {
  const { data } = await req.get(url, {
    headers: { 'User-Agent': UA, Referer: HOST + '/' },
    timeout: 15000,
  });
  if (typeof data === 'string') {
    try {
      return JSON.parse(data);
    } catch {
      return null;
    }
  }
  return data || null;
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
  const $ = load(html);
  const list = [];
  $('a.thumbnail').each((_, a) => {
    const $a = $(a);
    const href = $a.attr('href');
    if (!href) return;
    const $li = $a.closest('li');
    const title = ($li.find('h2 a').first().text() || $a.find('img').attr('alt') || '').trim();
    if (!title) return;
    const pic = $a.find('img').attr('data-src') || $a.find('img').attr('src') || '';
    const note = $li.find('.note span').first().text().trim();
    const countrie = $li.find('.countrie span').map((_, s) => $(s).text().trim()).get().filter(Boolean).join(' ');
    const remarks = [note, countrie].filter(Boolean).join(' ');
    list.push({
      vod_id: href,
      vod_name: title,
      vod_pic: abs(pic, base),
      vod_remarks: remarks,
    });
  });
  return list;
}

async function init() {
  return {};
}

async function home() {
  const classes = [
    { type_id: 'dianying', type_name: '电影' },
    { type_id: 'dianshiju', type_name: '电视剧' },
    { type_id: 'zongyi', type_name: '综艺' },
    { type_id: 'dongman', type_name: '动漫' },
  ];
  const genre = [
    { n: '全部', v: '' },
    { n: '剧情', v: 'ju-qing' },
    { n: '喜剧', v: 'xi-ju' },
    { n: '爱情', v: 'ai-qing' },
    { n: '动作', v: 'dong-zuo' },
    { n: '惊悚', v: 'jing-song' },
    { n: '犯罪', v: 'fan-zui' },
    { n: '悬疑', v: 'xuan-yi' },
    { n: '科幻', v: 'ke-huan' },
    { n: '奇幻', v: 'qi-huan' },
    { n: '战争', v: 'zhan-zheng' },
    { n: '家庭', v: 'jia-ting' },
    { n: '历史', v: 'li-shi' },
    { n: '青春', v: 'qing-chun' },
  ];
  const country = [
    { n: '全部', v: '' },
    { n: '大陆', v: 'cn' },
    { n: '美国', v: 'us' },
    { n: '香港', v: 'hk' },
    { n: '台湾', v: 'tw' },
    { n: '日本', v: 'jp' },
    { n: '韩国', v: 'kr' },
    { n: '英国', v: 'gb' },
    { n: '法国', v: 'fr' },
    { n: '德国', v: 'de' },
    { n: '意大利', v: 'it' },
    { n: '印度', v: 'in' },
    { n: '泰国', v: 'th' },
    { n: '俄罗斯', v: 'ru' },
  ];
  const year = [{ n: '全部', v: '' }];
  for (let y = 2026; y >= 2010; y--) year.push({ n: String(y), v: String(y) });
  year.push({ n: '2010以前', v: 'lt__2010' });
  const ob = [
    { n: '按时间', v: '' },
    { n: '按人气', v: 'click' },
    { n: '按评分', v: 'rating' },
  ];
  const filters = {};
  for (const c of classes) {
    filters[c.type_id] = [
      { key: 'genre', name: '类型', value: genre },
      { key: 'country', name: '地区', value: country },
      { key: 'year', name: '年份', value: year },
      { key: 'ob', name: '排序', value: ob },
    ];
  }
  return { class: classes, filters, list: [] };
}

async function homeVod() {
  const html = await getHtml(buildUrl('/dianying/', { page: 1 }));
  return { list: parseList(html, HOST) };
}

async function category(reqIn) {
  const body = bodyOf(reqIn);
  const page = pageOf(body.page);
  let cat = String(body.id || 'dianying').replace(/^\/+|\/+$/g, '');
  cat = cat.split('/')[0] || 'dianying';
  if (!['dianying', 'dianshiju', 'zongyi', 'dongman'].includes(cat)) cat = 'dianying';
  const f = filtersOf(reqIn);
  const html = await getHtml(buildUrl('/' + cat + '/', {
    genre: f.genre,
    country: f.country,
    year: f.year,
    ob: f.ob,
    page,
  }));
  const list = parseList(html, HOST);
  return {
    page,
    pagecount: list.length > 0 ? page + 1 : page,
    limit: 24,
    total: list.length > 0 ? page * 24 + 1 : 0,
    list,
  };
}

function numericIdOf(detailPath) {
  const m = String(detailPath || '').match(/(\d+)\.html/);
  return m ? m[1] : '';
}

function parseEpisodes($) {
  const eps = [];
  $('#eps-ul li.play-btn').each((_, li) => {
    const slug = $(li).attr('ep_slug');
    const name = $(li).find('a').first().text().trim() || slug;
    if (slug) eps.push({ slug, name });
  });
  // 站内剧集是倒序（ep8 在前），正序返回；电影的 正片/其他 不是 epN，保持原顺序。
  if (eps.length > 1 && eps.every((e) => /^ep\d+$/.test(e.slug))) eps.reverse();
  return eps;
}

async function fetchPlays(numericId, slug) {
  const data = await getJson(HOST + '/_gp/' + numericId + '/' + slug);
  if (!data || !Array.isArray(data.video_plays)) return [];
  return data.video_plays
    .map((p) => ({ site: String(p.src_site || ''), url: String(p.play_data || '') }))
    .filter((p) => p.url);
}

async function detail(reqIn) {
  const ids = Array.isArray(bodyOf(reqIn).id) ? bodyOf(reqIn).id : [bodyOf(reqIn).id];
  const list = [];
  for (const id of ids.filter(Boolean)) {
    const detailUrl = abs(id);
    const html = await getHtml(detailUrl);
    const $ = load(html);
    const $title = $('h1.product-title').first();
    const vodName = $title.clone().children().remove().end().text().trim();
    const year = ($title.find('span').first().text() || '').replace(/[^0-9]/g, '');
    const vodPic = abs($('img.detail-img').first().attr('src') || '', detailUrl);
    let director = '';
    let actor = '';
    let typeName = '';
    let area = '';
    let content = '';
    $('.product-excerpt').each((_, el) => {
      const text = $(el).text().replace(/\s+/g, ' ').trim();
      const value = $(el).find('span').text().replace(/\s+/g, ' ').trim();
      if (text.startsWith('导演')) director = value;
      else if (text.startsWith('主演')) actor = value;
      else if (text.startsWith('类型')) typeName = value;
      else if (text.startsWith('制片国家')) area = value;
      else if (text.startsWith('剧情简介')) content = value;
    });
    const episodes = parseEpisodes($);
    const numericId = numericIdOf(id);
    let vodPlayFrom = '默认';
    let vodPlayUrl = '';
    if (episodes.length && numericId && episodes.length <= FULL_LINE_MAX_EPISODES) {
      // 多线路模式：每集拉一次 /_gp，按 src_site 汇总成线路。
      const lineNames = [];
      const lineEpisodes = {};
      for (const ep of episodes) {
        const plays = await fetchPlays(numericId, ep.slug).catch(() => []);
        for (const p of plays) {
          if (!lineNames.includes(p.site)) {
            lineNames.push(p.site);
            lineEpisodes[p.site] = [];
          }
          lineEpisodes[p.site].push(ep.name + '$' + p.url);
        }
      }
      if (lineNames.length) {
        vodPlayFrom = lineNames.join('$$$');
        vodPlayUrl = lineNames.map((n) => lineEpisodes[n].join('#')).join('$$$');
      } else {
        vodPlayUrl = episodes.map((ep) => ep.name + '$' + numericId + ':' + ep.slug).join('#');
      }
    } else {
      // 轻量模式：集的播放 id 交给 /play 再拉 /_gp。
      vodPlayUrl = episodes.map((ep) => ep.name + '$' + numericId + ':' + ep.slug).join('#');
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
      vod_play_url: vodPlayUrl,
    });
  }
  return { list };
}

async function play(reqIn) {
  const body = bodyOf(reqIn);
  const id = String(body.id || '').trim();
  // 多线路模式下 id 本身就是 m3u8 直链。
  if (/^https?:\/\//i.test(id)) {
    return { parse: 0, url: id, header: { 'User-Agent': UA, Referer: HOST + '/' } };
  }
  // 轻量模式：id 是“数字id:ep_slug”。
  const m = id.match(/^(\d+):(.+)$/);
  if (!m) return { parse: 0, url: '', message: '未识别的播放 id' };
  const plays = await fetchPlays(m[1], m[2]).catch(() => []);
  if (!plays.length) return { parse: 0, url: '', message: '未提取到播放地址' };
  return {
    parse: 0,
    url: plays[0].url,
    header: { 'User-Agent': UA, Referer: HOST + '/' },
  };
}

async function search(reqIn) {
  const body = bodyOf(reqIn);
  const page = pageOf(body.page);
  const wd = String(body.wd || '').trim();
  if (!wd) return { page, pagecount: page, limit: 20, total: 0, list: [] };
  const html = await getHtml(buildUrl('/so', { q: wd, page }));
  const list = parseList(html, HOST);
  return {
    page,
    pagecount: list.length > 0 ? page + 1 : page,
    limit: 20,
    total: list.length > 0 ? page * 20 + 1 : 0,
    list,
  };
}

export default function createSpider() {
  return {
    meta: { key: KEY, name: NAME, type: 3 },
    api: async (fastify) => {
      fastify.post('/init', init);
      fastify.post('/home', home);
      fastify.post('/homeVod', homeVod);
      fastify.post('/category', category);
      fastify.post('/detail', detail);
      fastify.post('/play', play);
      fastify.post('/search', search);
    },
    check: async () => true,
  };
}
