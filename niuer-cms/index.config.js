// 多源包配置模板 v1.0.3：niuer 式结构，凭据全部留空，用户自己在配置中心里填。
// 不要填别人的 token/cookie；填完保存后，4K 蜘蛛优先用这里的站点地址。
// 注意：这里只是配置结构 + 配置页，网盘分享链接的解析（panAdapter）是下一步，
// 填了 token 不等于 4K 马上能播。
module.exports = {
  default: {
    ali: { token: "", token280: "" },
    quark: { cookie: "" },
    uc: { cookie: "", token: "", refreshtoken: "", ut: "" },
    baidu: { cookie: "" },
    y115: { cookie: "" },
    pan123: { cookie: "" },
    muou: { url: "" },
    duoduo: { url: "" },
    huban: { url: "" },
    shandian: { url: "" },
    labi: { url: "" },
    kuaiying: { url: "" },
    wogg: { url: "" },
    sites: { list: [] },
    pans: {
      list: [
        { key: "nodejs_mypan", name: "我的网盘", type: 3, enable: false, token: "", cookie: "" },
        { key: "nodejs_ali", name: "阿里云盘", type: 3, enable: false, token: "", cookie: "" },
        { key: "nodejs_quark", name: "夸克网盘", type: 3, enable: false, token: "", cookie: "" },
        { key: "nodejs_uc", name: "UC网盘", type: 3, enable: false, token: "", cookie: "" },
        { key: "nodejs_baidu", name: "百度网盘", type: 3, enable: false, token: "", cookie: "" },
        { key: "nodejs_pan115", name: "115网盘", type: 3, enable: false, token: "", cookie: "" },
        { key: "nodejs_pan123", name: "123网盘", type: 3, enable: false, token: "", cookie: "" }
      ]
    },
    alist: [],
    color: []
  }
};
