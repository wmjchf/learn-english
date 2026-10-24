/**
 * 词库种子数据（仅供 scripts/seed-bank-words.js 灌进 MySQL `bank_words`）。
 * 运行时抽词 / 释义请查数据库，不要直接 require 本文件做业务逻辑。
 */

function entry(lemma, gloss, root) {
  return { lemma, gloss, root: root || lemma };
}

const POOLS = {
  business: [
    entry('relocate', '搬迁；重新安置', 're + locate'),
    entry('renovation', '翻新；整修', 'renovate'),
    entry('premises', '经营场所；办公场地', 'premise'),
    entry('accessible', '无障碍的；可到达的', 'access'),
    entry('badge', '工牌；徽章'),
    entry('photocopier', '复印机', 'photo + copy'),
    entry('corridor', '走廊'),
    entry('malfunction', '故障；失灵', 'mal + function'),
    entry('maintenance', '维修；维护', 'maintain'),
    entry('workstation', '工位', 'work + station'),
    entry('outlet', '插座；出口', 'out + let'),
    entry('replacement', '替换件；替换物', 'replace'),
    entry('invoice', '发票；账单'),
    entry('quotation', '报价；引文', 'quote'),
    entry('deadline', '截止日期', 'dead + line'),
    entry('shipment', '发货；货运', 'ship'),
    entry('negotiate', '谈判；协商'),
    entry('contract', '合同'),
    entry('client', '客户'),
    entry('agenda', '议程'),
    entry('minutes', '会议纪要', 'minute'),
    entry('budget', '预算'),
    entry('expense', '费用；开支'),
    entry('reimburse', '报销；偿付'),
    entry('procurement', '采购', 'procure'),
    entry('supplier', '供应商', 'supply'),
    entry('logistics', '物流', 'logistic'),
    entry('warehouse', '仓库', 'ware + house'),
    entry('inventory', '库存；盘点'),
    entry('turnover', '营业额；人员流动', 'turn + over'),
    entry('revenue', '收入；营收'),
    entry('margin', '利润率；边距'),
    entry('stakeholder', '利益相关方', 'stake + holder'),
    entry('briefing', '简报；情况说明', 'brief'),
    entry('follow-up', '跟进', 'follow + up'),
    entry('proposal', '提案；建议书', 'propose'),
    entry('pitch', '推介；推销陈述'),
    entry('benchmark', '基准；对标', 'bench + mark'),
    entry('compliance', '合规', 'comply'),
    entry('headcount', '人数；编制', 'head + count'),
    entry('onboarding', '入职培训；上手', 'on + board'),
    entry('offsite', '外出团建；场外会议', 'off + site'),
    entry('remote', '远程的'),
    entry('hybrid', '混合的（如混合办公）'),
    entry('capacity', '产能；能力'),
    entry('escalate', '升级上报'),
    entry('priority', '优先级', 'prior'),
    entry('deliverable', '可交付成果', 'deliver'),
    entry('milestone', '里程碑', 'mile + stone'),
    entry('kickoff', '启动会；开球', 'kick + off'),
    entry('handover', '交接', 'hand + over'),
    entry('approval', '批准；审批', 'approve'),
    entry('signature', '签名', 'sign'),
    entry('attachment', '附件', 'attach'),
    entry('cc', '抄送', 'carbon copy'),
    entry('forward', '转发；向前'),
    entry('reschedule', '改期', 're + schedule'),
    entry('availability', '空闲时间；可用性', 'available'),
    entry('conference', '会议；电话会', 'confer'),
    entry('venue', '场地；会场'),
  ],
  cet4: [
    entry('achieve', '实现；达到'),
    entry('adapt', '适应；改编'),
    entry('affect', '影响'),
    entry('approach', '方法；接近'),
    entry('assume', '假定；承担'),
    entry('available', '可获得的；有空的', 'avail'),
    entry('benefit', '益处；受益'),
    entry('challenge', '挑战'),
    entry('commit', '承诺；投入'),
    entry('compare', '比较'),
    entry('complex', '复杂的'),
    entry('conclude', '得出结论；结束'),
    entry('conduct', '进行；行为'),
    entry('consider', '考虑'),
    entry('contribute', '贡献；促成'),
    entry('create', '创造；创建'),
    entry('demand', '要求；需求'),
    entry('demonstrate', '证明；演示'),
    entry('depend', '依赖'),
    entry('design', '设计'),
    entry('determine', '确定；决定'),
    entry('develop', '发展；开发'),
    entry('discuss', '讨论'),
    entry('economy', '经济'),
    entry('effect', '效果；影响'),
    entry('efficient', '高效的'),
    entry('emphasize', '强调'),
    entry('enable', '使能够'),
    entry('encourage', '鼓励'),
    entry('ensure', '确保'),
    entry('establish', '建立；确立'),
    entry('evaluate', '评估'),
    entry('evidence', '证据'),
    entry('expand', '扩大；扩展'),
    entry('experience', '经验；经历'),
    entry('factor', '因素'),
    entry('feature', '特征；以…为特色'),
    entry('focus', '焦点；集中'),
    entry('function', '功能；运转'),
    entry('generate', '产生；生成'),
    entry('identify', '识别；确认'),
    entry('impact', '影响；冲击'),
    entry('improve', '改进；提高'),
    entry('include', '包括'),
    entry('increase', '增加'),
    entry('indicate', '表明；指示'),
    entry('individual', '个人；个别的'),
    entry('influence', '影响'),
    entry('inform', '告知'),
    entry('issue', '问题；发行'),
  ],
  cet6: [
    entry('allocate', '分配'),
    entry('ambiguous', '含糊的；歧义的'),
    entry('anticipate', '预期；预料'),
    entry('articulate', '清楚表达；关节的'),
    entry('assess', '评估'),
    entry('coherent', '连贯的；一致的'),
    entry('collaborate', '合作'),
    entry('compensate', '补偿；弥补'),
    entry('comprehensive', '全面的', 'comprehend'),
    entry('conceive', '设想；怀孕'),
    entry('consolidate', '巩固；合并'),
    entry('constrain', '限制；约束'),
    entry('contemplate', '沉思；考虑'),
    entry('controversial', '有争议的', 'controversy'),
    entry('correlate', '相关；关联'),
    entry('crucial', '至关重要的'),
    entry('cultivate', '培养；耕作'),
    entry('deteriorate', '恶化'),
    entry('diminish', '减少；削弱'),
    entry('discrete', '离散的；分开的'),
    entry('diverse', '多样的'),
    entry('elaborate', '详尽阐述；复杂的'),
    entry('empirical', '经验的；实证的'),
    entry('enhance', '增强；提高'),
    entry('ensue', '随之发生'),
    entry('equity', '公平；股权'),
    entry('exploit', '利用；剥削'),
    entry('facilitate', '促进；使便利'),
    entry('fluctuate', '波动'),
    entry('formulate', '制定；表述'),
    entry('hypothesis', '假设'),
    entry('implicit', '含蓄的；暗含的'),
    entry('incentive', '激励；诱因'),
    entry('induce', '引起；诱导'),
    entry('inevitable', '不可避免的'),
    entry('infrastructure', '基础设施', 'infra + structure'),
    entry('inherent', '固有的；内在的'),
    entry('integral', '必不可少的；完整的'),
    entry('intervene', '干预；介入'),
    entry('justify', '证明合理；辩解'),
  ],
  kaoyan: [
    entry('abolish', '废除'),
    entry('absorb', '吸收；领会'),
    entry('abstract', '抽象的；摘要'),
    entry('abundant', '丰富的；充足的'),
    entry('accelerate', '加速'),
    entry('accommodate', '容纳；适应'),
    entry('accumulate', '积累'),
    entry('acknowledge', '承认；致谢'),
    entry('acquire', '获得；习得'),
    entry('adequate', '足够的；适当的'),
    entry('adjacent', '邻近的'),
    entry('advocate', '提倡；拥护者'),
    entry('affiliate', '附属；加盟'),
    entry('aggravate', '加重；激怒'),
    entry('aggregate', '合计；聚集'),
    entry('allege', '声称；断言'),
    entry('allocate', '分配'),
    entry('alter', '改变'),
    entry('ambiguous', '含糊的；歧义的'),
    entry('amend', '修正；修订'),
    entry('analogy', '类比'),
    entry('analyze', '分析'),
    entry('annual', '每年的'),
    entry('anticipate', '预期；预料'),
    entry('apparatus', '器械；装置'),
    entry('apparent', '明显的；表面上的'),
    entry('appeal', '呼吁；上诉；吸引力'),
    entry('appendix', '附录；阑尾'),
    entry('applaud', '鼓掌；称赞'),
    entry('applicable', '适用的', 'apply'),
    entry('appoint', '任命；约定'),
    entry('appreciate', '欣赏；感激；升值'),
    entry('approach', '方法；接近'),
    entry('appropriate', '适当的；拨出'),
    entry('approximate', '大约的；近似'),
    entry('arbitrary', '任意的；专断的'),
    entry('architecture', '建筑；架构'),
    entry('argue', '争论；论证'),
    entry('arise', '出现；产生'),
    entry('arouse', '唤起；激起'),
  ],
};

/** 全库 lemma → {gloss, root}（跨词库去重，后写覆盖） */
function buildDictIndex() {
  const map = Object.create(null);
  for (const list of Object.values(POOLS)) {
    for (const item of list) {
      const lemma = String(item.lemma || '')
        .trim()
        .toLowerCase();
      if (!lemma) continue;
      map[lemma] = {
        gloss: String(item.gloss || '').trim(),
        root: String(item.root || lemma).trim() || lemma,
      };
    }
  }
  return map;
}

const DICT_INDEX = buildDictIndex();

function poolLemmas(bankCode) {
  const pool = POOLS[bankCode] || POOLS.business;
  return pool.map((e) => e.lemma);
}

function pickTargetLemmas(bankCode, cursorOrd = 0, count = 12) {
  const pool = poolLemmas(bankCode);
  const n = Math.min(count, pool.length);
  const start = ((cursorOrd % pool.length) + pool.length) % pool.length;
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push(pool[(start + i) % pool.length]);
  }
  return out;
}

function lookupInPools(lemma) {
  const key = String(lemma || '')
    .trim()
    .toLowerCase();
  return DICT_INDEX[key] || null;
}

function allDictEntries() {
  return Object.entries(DICT_INDEX).map(([lemma, v]) => ({
    lemma,
    gloss: v.gloss,
    root: v.root,
  }));
}

module.exports = {
  POOLS,
  DICT_INDEX,
  pickTargetLemmas,
  lookupInPools,
  allDictEntries,
};
