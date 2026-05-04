import { useState, useEffect, useRef } from 'react';

const TYPES = {
  fire:  { emoji: '🔥', name: '불꽃', soft: 'bg-orange-100',  text: 'text-orange-700' },
  wind:  { emoji: '💨', name: '바람', soft: 'bg-sky-100',     text: 'text-sky-700' },
  earth: { emoji: '🌍', name: '대지', soft: 'bg-emerald-100', text: 'text-emerald-700' }
};

const COMPANION_STAGES = [
  { upTo: 0,  name: '알',     emoji: '🥚' },
  { upTo: 4,  name: '아가',   emoji: '🐣' },
  { upTo: 9,  name: '꼬마',   emoji: '🐥' },
  { upTo: 24, name: '청년',   emoji: '🦊' },
  { upTo: 49, name: '장년',   emoji: '🐺' },
  { upTo: 99, name: '현자',   emoji: '🦉' }
];

const PET_STAGES = [
  { upTo: 4,  name: '새끼',   emoji: '🐉', aura: 'shadow-orange-200' },
  { upTo: 14, name: '용맹',   emoji: '🐲', aura: 'shadow-orange-300' },
  { upTo: 29, name: '패왕',   emoji: '⚡', aura: 'shadow-amber-400' },
  { upTo: 99, name: '전설',   emoji: '✨', aura: 'shadow-purple-400' }
];

const MILESTONES = [
  { steps: 500,   exp: 10,  msg: '🎉 500보!' },
  { steps: 1000,  exp: 25,  msg: '⭐ 1,000보! 입장권 +1', reward: 'ticket' },
  { steps: 3000,  exp: 60,  msg: '🔥 3,000보! 입장권 +1', reward: 'ticket' },
  { steps: 5000,  exp: 120, msg: '💎 5,000보! 입장권 +2', reward: 'ticket2' },
  { steps: 10000, exp: 250, msg: '🏆 10,000보! 보너스 상자' }
];

const COSTUMES = [
  '🎩 골든 모자',
  '🌟 별빛 망토',
  '🌈 무지개 오라',
  '🏆 챔피언 벨트',
  '🎖️ 영웅 메달',
  '👑 왕관'
];

const PET_UNLOCK_LEVEL = 5;

function getCompanionStage(lvl) {
  return COMPANION_STAGES.find(s => lvl <= s.upTo) || COMPANION_STAGES[COMPANION_STAGES.length - 1];
}

function getPetStage(lvl) {
  return PET_STAGES.find(s => lvl <= s.upTo) || PET_STAGES[PET_STAGES.length - 1];
}

function expForLevel(lvl) {
  if (lvl < 10) return 100;
  if (lvl < 25) return 300;
  if (lvl < 50) return 600;
  return 1200;
}

function calcPetStats(petLvl, totalSteps) {
  return {
    atk: Math.floor(50 + petLvl * 3 + totalSteps * 0.001),
    def: Math.floor(45 + petLvl * 2),
    hp:  200 + petLvl * 12,
    crit: Math.min(20, petLvl * 0.3)
  };
}

function getHandicap(myLvl, oppLvl) {
  const diff = Math.abs(myLvl - oppLvl);
  let bonus = 0;
  if (diff <= 5) bonus = 0;
  else if (diff <= 15) bonus = 0.15;
  else if (diff <= 30) bonus = 0.25;
  else bonus = 0.35;
  if (myLvl < oppLvl) return { mine: 1 + bonus, opp: 1 - bonus * 0.5, role: 'underdog', bonus };
  if (myLvl > oppLvl) return { mine: 1 - bonus * 0.5, opp: 1 + bonus, role: 'favorite', bonus };
  return { mine: 1, opp: 1, role: 'even', bonus: 0 };
}

export default function DallimonGameV2() {
  const [game, setGame] = useState({
    type: 'fire',
    companionLevel: 1,
    companionExp: 0,
    todaySteps: 0,
    totalSteps: 0,
    costumes: [],
    activeCostume: null,
    petUnlocked: false,
    petLevel: 1,
    petExp: 0,
    petWins: 0,
    tickets: 0
  });
  const [tab, setTab] = useState('companion');
  const [autoWalk, setAutoWalk] = useState(false);
  const [toasts, setToasts] = useState([]);
  const [evoFlash, setEvoFlash] = useState(null);
  const [petUnlockModal, setPetUnlockModal] = useState(false);
  const [battle, setBattle] = useState(null);
  const toastIdRef = useRef(0);

  useEffect(() => {
    if (!autoWalk) return;
    const id = setInterval(() => addSteps(150), 220);
    return () => clearInterval(id);
  }, [autoWalk, game.companionLevel, game.todaySteps]);

  function pushToast(msg, kind = 'info') {
    const id = ++toastIdRef.current;
    setToasts(t => [...t, { id, msg, kind }]);
    setTimeout(() => setToasts(t => t.filter(x => x.id !== id)), 2400);
  }

  function applyCompanionExp(state, amount) {
    let exp = state.companionExp + amount;
    let level = state.companionLevel;
    let needed = expForLevel(level);
    const evos = [];
    let unlockedPet = false;
    while (exp >= needed && level < 99) {
      exp -= needed;
      level++;
      if ([10, 25, 50, 80].includes(level)) evos.push(level);
      if (level === PET_UNLOCK_LEVEL && !state.petUnlocked) {
        unlockedPet = true;
      }
      needed = expForLevel(level);
    }
    return {
      state: { ...state, companionExp: exp, companionLevel: level, petUnlocked: state.petUnlocked || unlockedPet },
      evos,
      leveledUp: level !== state.companionLevel,
      unlockedPet
    };
  }

  function addSteps(n) {
    setGame(prev => {
      let next = { ...prev, todaySteps: prev.todaySteps + n, totalSteps: prev.totalSteps + n };
      let res = applyCompanionExp(next, n * 0.4);
      next = res.state;
      const evos = [...res.evos];
      let petJustUnlocked = res.unlockedPet;
      const triggered = [];

      for (const m of MILESTONES) {
        if (prev.todaySteps < m.steps && next.todaySteps >= m.steps) {
          res = applyCompanionExp(next, m.exp);
          next = res.state;
          evos.push(...res.evos);
          if (res.unlockedPet) petJustUnlocked = true;
          if (m.reward === 'ticket') next.tickets++;
          if (m.reward === 'ticket2') next.tickets += 2;
          triggered.push(m.msg);
        }
      }

      triggered.forEach((msg, i) => setTimeout(() => pushToast(msg, 'milestone'), i * 250));

      if (petJustUnlocked) {
        setTimeout(() => {
          setPetUnlockModal(true);
          setAutoWalk(false);
        }, triggered.length * 250 + 400);
      } else if (evos.length > 0) {
        const finalLvl = evos[evos.length - 1];
        setTimeout(() => {
          setEvoFlash({ stage: getCompanionStage(finalLvl), level: finalLvl });
          setTimeout(() => setEvoFlash(null), 2200);
        }, triggered.length * 250 + 200);
      } else if (res.leveledUp) {
        setTimeout(() => pushToast(`달리 Lv.${next.companionLevel} 도달!`, 'levelup'), triggered.length * 250 + 100);
      }

      return next;
    });
  }

  function startBattle(opponentLevel) {
    if (game.tickets <= 0) {
      pushToast('입장권이 부족해요! 더 걸어주세요', 'warn');
      return;
    }
    setGame(g => ({ ...g, tickets: g.tickets - 1 }));
    const myStats = calcPetStats(game.petLevel, game.totalSteps);
    const oppStats = calcPetStats(opponentLevel, opponentLevel * 1500);
    const handicap = getHandicap(game.petLevel, opponentLevel);
    setBattle({
      phase: 'intro',
      myLevel: game.petLevel,
      myType: game.type,
      myStats,
      myHP: Math.floor(myStats.hp * Math.max(handicap.mine, 0.6)),
      myMaxHP: Math.floor(myStats.hp * Math.max(handicap.mine, 0.6)),
      oppLevel: opponentLevel,
      oppType: ['fire', 'wind', 'earth'][Math.floor(Math.random() * 3)],
      oppStats,
      oppHP: Math.floor(oppStats.hp * Math.max(handicap.opp, 0.6)),
      oppMaxHP: Math.floor(oppStats.hp * Math.max(handicap.opp, 0.6)),
      handicap,
      log: [],
      turn: 0,
      kantooFired: false
    });
  }

  function endBattle(victory) {
    setBattle(b => ({ ...b, phase: 'end', victory }));
    if (victory) {
      const expGain = 80;
      setGame(prev => {
        let exp = prev.petExp + expGain;
        let level = prev.petLevel;
        let needed = expForLevel(level);
        // Pet level cap = companion level
        while (exp >= needed && level < prev.companionLevel) {
          exp -= needed;
          level++;
          needed = expForLevel(level);
        }
        const updates = { ...prev, petExp: exp, petLevel: level, petWins: prev.petWins + 1 };
        // 35% costume drop
        if (Math.random() < 0.35) {
          const available = COSTUMES.filter(c => !prev.costumes.includes(c));
          if (available.length > 0) {
            const dropped = available[Math.floor(Math.random() * available.length)];
            updates.costumes = [...prev.costumes, dropped];
            updates.activeCostume = updates.activeCostume || dropped;
            setTimeout(() => pushToast(`🎁 동반자 코스튬 획득: ${dropped}`, 'win'), 800);
          }
        }
        return updates;
      });
      setTimeout(() => pushToast(`🏆 승리! 펫 +${expGain} EXP`, 'win'), 200);
    } else {
      pushToast('아쉬워요. 다시 도전!', 'info');
    }
  }

  const companionStage = getCompanionStage(game.companionLevel);
  const petStage = getPetStage(game.petLevel);
  const typeInfo = TYPES[game.type];
  const companionExpCap = expForLevel(game.companionLevel);
  const companionExpPct = Math.min(100, (game.companionExp / companionExpCap) * 100);
  const petAtCap = game.petLevel >= game.companionLevel;
  const petExpCap = expForLevel(game.petLevel);
  const petExpPct = petAtCap ? 100 : Math.min(100, (game.petExp / petExpCap) * 100);

  return (
    <div className="min-h-screen w-full flex justify-center" style={{ background: '#f0e9dc', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <div className="w-full max-w-md min-h-screen relative overflow-hidden flex flex-col" style={{ background: '#fffaf2' }}>

        <div className={`px-5 pt-5 pb-3 ${tab === 'companion' ? 'bg-teal-50' : 'bg-orange-50'} transition-colors`}>
          <div className="flex items-center justify-between gap-2">
            <button onClick={() => setTab('companion')} className={`flex-1 py-2 rounded-lg text-sm font-medium transition-all ${tab === 'companion' ? 'bg-teal-500 text-white shadow' : 'bg-white/60 text-stone-500'}`}>
              🌱 달리
            </button>
            <button
              onClick={() => game.petUnlocked && setTab('pet')}
              disabled={!game.petUnlocked}
              className={`flex-1 py-2 rounded-lg text-sm font-medium transition-all ${
                !game.petUnlocked ? 'bg-stone-200 text-stone-400 cursor-not-allowed' :
                tab === 'pet' ? 'bg-orange-500 text-white shadow' : 'bg-white/60 text-stone-500'
              }`}
            >
              {game.petUnlocked ? '⚔️ 달리몬' : `🔒 Lv.${PET_UNLOCK_LEVEL}에 해금`}
            </button>
          </div>
        </div>

        {tab === 'companion' && (
          <CompanionView
            game={game}
            stage={companionStage}
            typeInfo={typeInfo}
            expPct={companionExpPct}
            expCap={companionExpCap}
          />
        )}
        {tab === 'pet' && (
          <PetView
            game={game}
            stage={petStage}
            typeInfo={typeInfo}
            expPct={petExpPct}
            expCap={petExpCap}
            atCap={petAtCap}
            onBattle={startBattle}
          />
        )}

        {tab === 'companion' && (
          <div className="px-5 pb-2">
            <div className="text-[11px] text-stone-500 mb-1.5 px-1">걷기 시뮬레이터</div>
            <div className="flex gap-2">
              <button onClick={() => addSteps(100)} className="flex-1 py-2.5 rounded-xl bg-white border border-stone-200 text-sm font-medium text-stone-700 active:scale-95 transition-transform">+100보</button>
              <button onClick={() => addSteps(500)} className="flex-1 py-2.5 rounded-xl bg-white border border-stone-200 text-sm font-medium text-stone-700 active:scale-95 transition-transform">+500보</button>
              <button onClick={() => addSteps(1000)} className="flex-1 py-2.5 rounded-xl bg-white border border-stone-200 text-sm font-medium text-stone-700 active:scale-95 transition-transform">+1000보</button>
            </div>
            <button
              onClick={() => setAutoWalk(a => !a)}
              className={`w-full mt-2 py-2.5 rounded-xl text-sm font-medium transition-all active:scale-[0.98] ${autoWalk ? 'bg-teal-500 text-white' : 'bg-white border border-stone-200 text-stone-700'}`}
            >
              {autoWalk ? '⏸  자동 걷기 정지' : '▶  자동 걷기 시작'}
            </button>
          </div>
        )}

        <div className="px-5 py-3 bg-stone-50 border-t border-stone-200 mt-auto">
          <div className="text-[10px] text-stone-400 mb-1">투트랙 연결 상태</div>
          <div className="grid grid-cols-3 gap-2 text-[10px]">
            <div className="bg-white rounded-lg p-2 text-center">
              <div className="text-stone-400">입장권</div>
              <div className="font-semibold text-stone-700 text-base tabular-nums">🎫 {game.tickets}</div>
              <div className="text-stone-400 mt-0.5">걷기 → 펫</div>
            </div>
            <div className="bg-white rounded-lg p-2 text-center">
              <div className="text-stone-400">펫 상한</div>
              <div className="font-semibold text-stone-700 text-base tabular-nums">Lv.{game.companionLevel}</div>
              <div className="text-stone-400 mt-0.5">달리 = 천장</div>
            </div>
            <div className="bg-white rounded-lg p-2 text-center">
              <div className="text-stone-400">코스튬</div>
              <div className="font-semibold text-stone-700 text-base tabular-nums">🎁 {game.costumes.length}</div>
              <div className="text-stone-400 mt-0.5">PvP → 달리</div>
            </div>
          </div>
        </div>

        <div className="absolute top-20 left-0 right-0 flex flex-col items-center gap-2 pointer-events-none px-5 z-30">
          {toasts.map(t => (
            <div key={t.id} className={`pointer-events-auto px-4 py-2 rounded-full text-xs font-medium shadow-lg animate-bounce-in ${
              t.kind === 'levelup' ? 'bg-purple-500 text-white' :
              t.kind === 'win' ? 'bg-emerald-500 text-white' :
              t.kind === 'milestone' ? 'bg-amber-400 text-amber-900' :
              t.kind === 'warn' ? 'bg-red-400 text-white' :
              'bg-stone-700 text-white'
            }`}>
              {t.msg}
            </div>
          ))}
        </div>

        {evoFlash && (
          <div className="absolute inset-0 z-40 flex items-center justify-center bg-black/50 backdrop-blur">
            <div className="text-center px-8">
              <div className="text-[10px] tracking-widest text-white/70 mb-2">EVOLUTION</div>
              <div className="text-8xl mb-3 animate-pulse-fast">{evoFlash.stage.emoji}</div>
              <div className="text-2xl font-bold text-white">{evoFlash.stage.name}</div>
              <div className="text-sm text-white/80 mt-1">달리 Lv.{evoFlash.level} 도달!</div>
            </div>
          </div>
        )}

        {petUnlockModal && (
          <div className="absolute inset-0 z-50 bg-black/70 backdrop-blur flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl p-6 max-w-sm text-center shadow-2xl">
              <div className="text-[10px] tracking-widest text-orange-500 font-semibold mb-3">DALLIMON UNLOCKED</div>
              <div className="flex items-center justify-center gap-3 mb-4">
                <div className="text-5xl">🥚</div>
                <div className="text-2xl text-stone-400">→</div>
                <div className="text-5xl animate-pulse-fast">🐉</div>
              </div>
              <div className="text-lg font-bold text-stone-800 mb-2">달리가 알을 발견했어요!</div>
              <p className="text-sm text-stone-600 leading-relaxed mb-5">
                달리(Lv.5)와 함께 동굴을 탐험하다 신비로운 알을 발견했습니다. 이제 <span className="font-semibold text-orange-600">달리몬 트랙</span>이 열렸어요. 던전과 NFC 배틀로 펫을 강하게 키워보세요.
              </p>
              <div className="bg-orange-50 rounded-xl p-3 mb-5 text-xs text-orange-700">
                💡 <strong>두 트랙은 연결돼 있어요</strong><br/>
                · 걸을수록 던전 입장권이 쌓이고<br/>
                · 달리몬 레벨은 달리 레벨까지만 올라가요<br/>
                · 배틀 승리 시 달리에게 코스튬이 떨어져요
              </div>
              <button
                onClick={() => { setPetUnlockModal(false); setTab('pet'); }}
                className="w-full py-3 bg-orange-500 text-white rounded-xl text-sm font-semibold active:scale-95 transition-transform"
              >
                달리몬 만나러 가기
              </button>
            </div>
          </div>
        )}

        {battle && <BattleModal battle={battle} setBattle={setBattle} onEnd={endBattle} onClose={() => setBattle(null)} />}

        <style>{`
          @keyframes bounce-in { 0% { transform: translateY(-20px); opacity: 0; } 60% { transform: translateY(4px); opacity: 1; } 100% { transform: translateY(0); } }
          .animate-bounce-in { animation: bounce-in 0.4s ease-out; }
          @keyframes pulse-fast { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.15); } }
          .animate-pulse-fast { animation: pulse-fast 0.6s ease-in-out infinite; }
          @keyframes float { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-6px); } }
          .animate-float { animation: float 2.5s ease-in-out infinite; }
        `}</style>
      </div>
    </div>
  );
}

function CompanionView({ game, stage, typeInfo, expPct, expCap }) {
  const milestonePending = MILESTONES.find(m => game.todaySteps < m.steps);
  return (
    <div className="flex-1 flex flex-col">
      <div className="px-5 pt-3 pb-2">
        <div className="flex items-end justify-between">
          <div>
            <div className="text-xs text-teal-700 font-medium">트랙 1 · 산책 동반자</div>
            <div className="text-base font-semibold text-stone-800 mt-0.5">달리 ({stage.name})</div>
          </div>
          <div className="text-right">
            <div className="text-[10px] text-stone-500">오늘</div>
            <div className="text-2xl font-bold tabular-nums text-stone-800">{game.todaySteps.toLocaleString()}</div>
            <div className="text-[10px] text-stone-400">보</div>
          </div>
        </div>
        <div className="mt-3">
          <div className="flex items-center justify-between text-[10px] text-stone-500 mb-1">
            <span>달리 EXP · Lv.{game.companionLevel}</span>
            <span className="tabular-nums">{Math.floor(game.companionExp)} / {expCap}</span>
          </div>
          <div className="h-2 bg-stone-100 rounded-full overflow-hidden">
            <div className="h-full bg-teal-500 transition-all duration-300" style={{ width: `${expPct}%` }} />
          </div>
        </div>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center px-6 py-2">
        <div className="relative">
          <div className="w-44 h-44 rounded-full bg-teal-50 ring-4 ring-teal-200 ring-offset-4 ring-offset-transparent flex items-center justify-center animate-float">
            <div className="text-7xl select-none" style={{ filter: 'drop-shadow(0 4px 8px rgba(0,0,0,0.08))' }}>{stage.emoji}</div>
          </div>
          {game.activeCostume && (
            <div className="absolute -top-2 -right-2 bg-white rounded-full px-2.5 py-1 shadow-md text-xs border border-stone-200">
              {game.activeCostume.split(' ')[0]}
            </div>
          )}
        </div>
        <div className="mt-3 text-center">
          <div className={`inline-block text-[10px] px-2 py-0.5 rounded-full ${typeInfo.soft} ${typeInfo.text} font-medium`}>
            {typeInfo.emoji} {typeInfo.name}
          </div>
        </div>
        {milestonePending && (
          <div className="mt-4 px-4 py-2 bg-stone-50 rounded-full text-[11px] text-stone-600">
            다음 마일스톤까지 <span className="font-semibold text-stone-800 tabular-nums">{(milestonePending.steps - game.todaySteps).toLocaleString()}</span>보
          </div>
        )}
      </div>

      {game.costumes.length > 0 && (
        <div className="px-5 pb-2">
          <div className="text-[10px] text-stone-400 mb-1.5">획득한 코스튬 (PvP 보상)</div>
          <div className="flex flex-wrap gap-1.5">
            {game.costumes.map((c, i) => (
              <div key={i} className="text-[10px] bg-white border border-stone-200 px-2 py-1 rounded-full">{c}</div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function PetView({ game, stage, typeInfo, expPct, expCap, atCap, onBattle }) {
  const stats = calcPetStats(game.petLevel, game.totalSteps);
  const oppLevels = [
    { label: '쉬운 던전', delta: -2, sub: '연습 상대' },
    { label: '평범한 던전', delta: 0, sub: '동레벨' },
    { label: '도전 던전', delta: +5, sub: '약자 보정' },
    { label: '할아버지 vs 손자', delta: +20, sub: '큰 격차' }
  ];

  return (
    <div className="flex-1 flex flex-col">
      <div className="px-5 pt-3 pb-2">
        <div className="flex items-end justify-between">
          <div>
            <div className="text-xs text-orange-700 font-medium">트랙 2 · 전투 펫</div>
            <div className="text-base font-semibold text-stone-800 mt-0.5">달리몬 ({stage.name})</div>
          </div>
          <div className="text-right">
            <div className="text-[10px] text-stone-500">전적</div>
            <div className="text-2xl font-bold tabular-nums text-stone-800">{game.petWins}<span className="text-sm text-stone-400">승</span></div>
          </div>
        </div>
        <div className="mt-3">
          <div className="flex items-center justify-between text-[10px] text-stone-500 mb-1">
            <span>
              펫 EXP · Lv.{game.petLevel}
              {atCap && <span className="ml-1 text-orange-500 font-semibold">(상한 도달)</span>}
            </span>
            <span className="tabular-nums">{atCap ? 'MAX' : `${Math.floor(game.petExp)} / ${expCap}`}</span>
          </div>
          <div className="h-2 bg-stone-100 rounded-full overflow-hidden">
            <div className={`h-full transition-all duration-300 ${atCap ? 'bg-orange-300' : 'bg-orange-500'}`} style={{ width: `${expPct}%` }} />
          </div>
          {atCap && (
            <div className="text-[10px] text-orange-600 mt-1">달리(Lv.{game.companionLevel})를 더 키워야 펫이 강해질 수 있어요</div>
          )}
        </div>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center px-6 py-2">
        <div className="w-44 h-44 rounded-full bg-orange-50 ring-4 ring-orange-300 ring-offset-4 ring-offset-transparent flex items-center justify-center" style={{ boxShadow: '0 0 40px rgba(251, 146, 60, 0.3)' }}>
          <div className="text-7xl select-none">{stage.emoji}</div>
        </div>
        <div className="mt-3 text-center">
          <div className={`inline-block text-[10px] px-2 py-0.5 rounded-full ${typeInfo.soft} ${typeInfo.text} font-medium`}>
            {typeInfo.emoji} {typeInfo.name}
          </div>
        </div>
        <div className="mt-3 grid grid-cols-3 gap-2 text-[11px] text-stone-600 w-full max-w-xs">
          <div className="bg-stone-50 rounded-lg py-1.5 text-center">
            <div className="text-stone-400">ATK</div>
            <div className="font-semibold tabular-nums">{stats.atk}</div>
          </div>
          <div className="bg-stone-50 rounded-lg py-1.5 text-center">
            <div className="text-stone-400">DEF</div>
            <div className="font-semibold tabular-nums">{stats.def}</div>
          </div>
          <div className="bg-stone-50 rounded-lg py-1.5 text-center">
            <div className="text-stone-400">HP</div>
            <div className="font-semibold tabular-nums">{stats.hp}</div>
          </div>
        </div>
      </div>

      <div className="px-5 pb-2">
        <div className="flex items-center justify-between text-[11px] text-stone-500 mb-1.5 px-1">
          <span>던전 / NFC 배틀</span>
          <span>입장권 🎫 {game.tickets}</span>
        </div>
        <div className="grid grid-cols-2 gap-2">
          {oppLevels.map(p => {
            const oppLvl = Math.max(1, game.petLevel + p.delta);
            return (
              <button
                key={p.label}
                onClick={() => onBattle(oppLvl)}
                disabled={game.tickets <= 0}
                className={`p-3 rounded-xl text-left bg-white border border-stone-200 active:scale-[0.97] transition-transform ${game.tickets <= 0 ? 'opacity-40' : ''}`}
              >
                <div className="text-sm font-semibold text-stone-800">{p.label}</div>
                <div className="text-[11px] text-stone-500 mt-0.5">Lv.{oppLvl} · {p.sub}</div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function BattleModal({ battle, setBattle, onEnd, onClose }) {
  const [phase, setPhase] = useState('intro');

  useEffect(() => {
    if (phase === 'intro') {
      const t = setTimeout(() => setPhase('fight'), 1300);
      return () => clearTimeout(t);
    }
    if (phase === 'fight') {
      const t = setTimeout(() => runTurn(), 600);
      return () => clearTimeout(t);
    }
  }, [phase]);

  function runTurn() {
    setBattle(prev => {
      if (prev.myHP <= 0 || prev.oppHP <= 0 || prev.turn >= 12) {
        setTimeout(() => {
          setPhase('end');
          onEnd(prev.myHP > prev.oppHP);
        }, 600);
        return prev;
      }
      const turn = prev.turn + 1;
      let myHP = prev.myHP;
      let oppHP = prev.oppHP;
      const newLog = [...prev.log];
      let kantooFired = prev.kantooFired;

      if (!kantooFired && prev.handicap.role === 'underdog' && prev.myHP / prev.myMaxHP < 0.3 && Math.random() < 0.6) {
        kantooFired = true;
        newLog.push('🛡️ 감투 발동! 다음 턴 +30%');
      }

      const kantooBoost = kantooFired ? 1.3 : 1;

      const myAtk = prev.myStats.atk * prev.handicap.mine * kantooBoost;
      const oppAtk = prev.oppStats.atk * prev.handicap.opp;
      const myDef = prev.myStats.def * prev.handicap.mine;
      const oppDef = prev.oppStats.def * prev.handicap.opp;

      const luckyMine = Math.random() < (prev.handicap.role === 'underdog' ? 0.12 : 0.07);
      const luckyOpp = Math.random() < 0.07;
      const critMine = Math.random() * 100 < (prev.myStats.crit + (prev.handicap.role === 'underdog' ? 8 : 0));
      const critOpp = Math.random() * 100 < prev.oppStats.crit;

      let myDmg = Math.max(8, Math.floor(myAtk - oppDef * 0.4));
      let oppDmg = Math.max(8, Math.floor(oppAtk - myDef * 0.4));
      if (critMine) myDmg = Math.floor(myDmg * 1.5);
      if (luckyMine) myDmg = Math.floor(myDmg * 1.5);
      if (critOpp) oppDmg = Math.floor(oppDmg * 1.5);
      if (luckyOpp) oppDmg = Math.floor(oppDmg * 1.5);

      oppHP = Math.max(0, oppHP - myDmg);
      let myLabel = `내 펫 → ${myDmg}`;
      if (critMine && luckyMine) myLabel = `✨ 크리티컬+행운! ${myDmg}`;
      else if (critMine) myLabel = `💥 크리티컬! ${myDmg}`;
      else if (luckyMine) myLabel = `🍀 행운의 일격! ${myDmg}`;
      newLog.push(myLabel);

      if (oppHP > 0) {
        myHP = Math.max(0, myHP - oppDmg);
        let oppLabel = `상대 → ${oppDmg}`;
        if (critOpp) oppLabel = `상대 크리티컬! ${oppDmg}`;
        else if (luckyOpp) oppLabel = `상대 행운의 일격! ${oppDmg}`;
        newLog.push(oppLabel);
      }

      const next = { ...prev, myHP, oppHP, turn, log: newLog.slice(-7), kantooFired };

      if (myHP <= 0 || oppHP <= 0 || turn >= 12) {
        setTimeout(() => {
          setPhase('end');
          onEnd(myHP > oppHP);
        }, 700);
      } else {
        setTimeout(() => runTurn(), 750);
      }
      return next;
    });
  }

  const myHPPct = (battle.myHP / battle.myMaxHP) * 100;
  const oppHPPct = (battle.oppHP / battle.oppMaxHP) * 100;
  const myTypeInfo = TYPES[battle.myType];
  const oppTypeInfo = TYPES[battle.oppType];

  return (
    <div className="absolute inset-0 z-50 bg-stone-900/80 backdrop-blur flex items-center justify-center p-4">
      <div className="w-full max-w-md bg-stone-50 rounded-2xl overflow-hidden shadow-2xl flex flex-col" style={{ maxHeight: '90vh' }}>
        <div className="px-4 py-3 bg-stone-100 border-b border-stone-200 flex items-center justify-between">
          <div className="text-xs font-medium text-stone-600">⚔️ 펫 배틀</div>
          {battle.handicap.role !== 'even' && (
            <div className={`text-[10px] px-2 py-0.5 rounded-full font-medium ${battle.handicap.role === 'underdog' ? 'bg-emerald-100 text-emerald-700' : 'bg-stone-200 text-stone-600'}`}>
              {battle.handicap.role === 'underdog' ? `✨ 핸디캡 +${Math.round(battle.handicap.bonus * 100)}%` : `핸디캡 -${Math.round(battle.handicap.bonus * 50)}%`}
            </div>
          )}
        </div>

        <div className="px-4 pt-4 pb-2 flex items-end justify-between gap-3 bg-gradient-to-b from-stone-50 to-white">
          <Combatant typeInfo={myTypeInfo} level={battle.myLevel} hp={battle.myHP} maxHP={battle.myMaxHP} hpPct={myHPPct} highlight={battle.kantooFired} />
          <div className="text-2xl font-bold text-stone-300 pb-8">VS</div>
          <Combatant typeInfo={oppTypeInfo} level={battle.oppLevel} hp={battle.oppHP} maxHP={battle.oppMaxHP} hpPct={oppHPPct} />
        </div>

        <div className="flex-1 px-4 pb-4 overflow-y-auto">
          {phase === 'intro' && (
            <div className="py-8 text-center">
              <div className="text-3xl mb-2 animate-pulse">⚡</div>
              <div className="text-sm text-stone-700 font-medium">배틀 시작!</div>
              <div className="text-xs text-stone-500 mt-1">레벨차 {Math.abs(battle.myLevel - battle.oppLevel)} · 자동 진행</div>
            </div>
          )}
          {(phase === 'fight' || phase === 'end') && (
            <div className="py-2">
              <div className="bg-white border border-stone-200 rounded-xl p-3 max-h-48 overflow-y-auto">
                <div className="text-[10px] text-stone-400 mb-2">배틀 로그</div>
                <div className="space-y-1">
                  {battle.log.map((line, i) => (
                    <div key={i} className={`text-xs ${line.includes('감투') ? 'text-emerald-600 font-medium' : line.includes('크리티컬') || line.includes('행운') ? 'text-amber-600 font-medium' : 'text-stone-600'}`}>
                      {line}
                    </div>
                  ))}
                  {battle.log.length === 0 && <div className="text-xs text-stone-400 italic">진행 중...</div>}
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="px-4 py-3 bg-stone-100 border-t border-stone-200">
          {phase === 'end' ? (
            <button onClick={onClose} className={`w-full py-3 rounded-xl text-sm font-semibold text-white ${battle.victory ? 'bg-emerald-500' : 'bg-stone-500'}`}>
              {battle.victory ? '🏆 승리! 보상 받기' : '아쉬워요. 닫기'}
            </button>
          ) : (
            <div className="text-center text-[10px] text-stone-400">자동 진행 · 턴 {battle.turn}</div>
          )}
        </div>
      </div>
    </div>
  );
}

function Combatant({ typeInfo, level, hp, maxHP, hpPct, highlight }) {
  return (
    <div className="flex flex-col items-center flex-1">
      <div className={`w-20 h-20 rounded-full ${typeInfo.soft} ring-2 ring-stone-200 flex items-center justify-center text-4xl ${highlight ? 'ring-4 ring-emerald-400' : ''}`}>
        {typeInfo.emoji}
      </div>
      <div className="text-[10px] font-medium text-stone-600 mt-1.5">Lv.{level} · {typeInfo.name}</div>
      <div className="w-full mt-1.5">
        <div className="h-1.5 bg-stone-200 rounded-full overflow-hidden">
          <div className={`h-full transition-all duration-300 ${hpPct < 30 ? 'bg-red-500' : hpPct < 60 ? 'bg-amber-500' : 'bg-emerald-500'}`} style={{ width: `${hpPct}%` }} />
        </div>
        <div className="text-[10px] text-stone-500 tabular-nums mt-0.5 text-center">{hp} / {maxHP}</div>
      </div>
    </div>
  );
}
