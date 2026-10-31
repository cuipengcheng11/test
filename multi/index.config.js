// 多源包配置模板（niuer 式结构，凭据全部留空，用户自己填，不要填别人的 token/cookie）
// video.sites：由包内蜘蛛自动补全，播放器启动时会与包内列表按 nodejs_<key> 合并。
// pan.sites：网盘配置，默认全部禁用；用户填好自己的 token/cookie 后，把对应条目的 enable 改为 true。
//   注意：v1 只提供配置结构，网盘文件解析（panAdapter）尚未实现，开启后仍可能播不了，
//   4K 模板的分享链接播放同样依赖 panAdapter，请先以 CMS/努努/whstyysj 为主。
module.exports = {
  default: {
    sites: { list: [] },
    pans: {
      list: [
        { key: "nodejs_mypan", name: "我的网盘", type: 3, enable: false, token: "", cookie: "" },
        { key: "nodejs_ali", name: "阿里云盘", type: 3, enable: false, token: "", refreshToken: "" },
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
