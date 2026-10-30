// 努努影院 · 整包配置（MiraPlayer / CatPaw 包格式）
// 只有 nnyy 一个源，无网盘账号、无 token、无任何个人凭据。
// 与 niuer/Mira 整包相同的 4 文件结构：index.js + index.config.js + 两个 .md5。
module.exports = {
  key: 'nnyy',
  name: '努努影院',
  host: 'https://nnyy.in',
  type: 3,
  rows: 24,
  sites: {
    list: [
      {
        name: '努努影院',
        key: 'nnyy',
        type: 3,
        api: 'index.js',
      },
    ],
  },
  pans: {
    list: [],
  },
};
