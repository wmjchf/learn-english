/**
 * MVP 词池：按词库 code 取一批 lemma，供日课生成抽目标词。
 * 后续可迁到 bank_words 表。
 */
const POOLS = {
  business: [
    'relocate', 'renovation', 'premises', 'accessible', 'badge',
    'photocopier', 'corridor', 'malfunction', 'maintenance', 'workstation',
    'outlet', 'replacement', 'invoice', 'quotation', 'deadline',
    'shipment', 'negotiate', 'contract', 'client', 'agenda',
    'minutes', 'budget', 'expense', 'reimburse', 'procurement',
    'supplier', 'logistics', 'warehouse', 'inventory', 'turnover',
    'revenue', 'margin', 'stakeholder', 'briefing', 'follow-up',
    'proposal', 'pitch', 'benchmark', 'compliance', 'headcount',
    'onboarding', 'offsite', 'remote', 'hybrid', 'capacity',
    'escalate', 'priority', 'deliverable', 'milestone', 'kickoff',
    'handover', 'approval', 'signature', 'attachment', 'cc',
    'forward', 'reschedule', 'availability', 'conference', 'venue',
  ],
  cet4: [
    'achieve', 'adapt', 'affect', 'approach', 'assume',
    'available', 'benefit', 'challenge', 'commit', 'compare',
    'complex', 'conclude', 'conduct', 'consider', 'contribute',
    'create', 'demand', 'demonstrate', 'depend', 'design',
    'determine', 'develop', 'discuss', 'economy', 'effect',
    'efficient', 'emphasize', 'enable', 'encourage', 'ensure',
    'establish', 'evaluate', 'evidence', 'expand', 'experience',
    'factor', 'feature', 'focus', 'function', 'generate',
    'identify', 'impact', 'improve', 'include', 'increase',
    'indicate', 'individual', 'influence', 'inform', 'issue',
  ],
  cet6: [
    'allocate', 'ambiguous', 'anticipate', 'articulate', 'assess',
    'coherent', 'collaborate', 'compensate', 'comprehensive', 'conceive',
    'consolidate', 'constrain', 'contemplate', 'controversial', 'correlate',
    'crucial', 'cultivate', 'deteriorate', 'diminish', 'discrete',
    'diverse', 'elaborate', 'empirical', 'enhance', 'ensue',
    'equity', 'exploit', 'facilitate', 'fluctuate', 'formulate',
    'hypothesis', 'implicit', 'incentive', 'induce', 'inevitable',
    'infrastructure', 'inherent', 'integral', 'intervene', 'justify',
  ],
  kaoyan: [
    'abolish', 'absorb', 'abstract', 'abundant', 'accelerate',
    'accommodate', 'accumulate', 'acknowledge', 'acquire', 'adequate',
    'adjacent', 'advocate', 'affiliate', 'aggravate', 'aggregate',
    'allege', 'allocate', 'alter', 'ambiguous', 'amend',
    'analogy', 'analyze', 'annual', 'anticipate', 'apparatus',
    'apparent', 'appeal', 'appendix', 'applaud', 'applicable',
    'appoint', 'appreciate', 'approach', 'appropriate', 'approximate',
    'arbitrary', 'architecture', 'argue', 'arise', 'arouse',
  ],
};

function pickTargetLemmas(bankCode, cursorOrd = 0, count = 12) {
  const pool = POOLS[bankCode] || POOLS.business;
  const n = Math.min(count, pool.length);
  const start = ((cursorOrd % pool.length) + pool.length) % pool.length;
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push(pool[(start + i) % pool.length]);
  }
  return out;
}

module.exports = { POOLS, pickTargetLemmas };
