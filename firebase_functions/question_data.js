const categoryPairs = [
  ["Geography", "جغرافيا"],
  ["Science", "علوم"],
  ["Math", "رياضيات"],
  ["Technology", "تقنية"],
  ["Culture", "ثقافة"],
  ["Language", "لغة"]
];

const facts = [
  ["France","Paris","Geography","فرنسا","باريس","جغرافيا"],
  ["Italy","Rome","Geography","إيطاليا","روما","جغرافيا"],
  ["Spain","Madrid","Geography","إسبانيا","مدريد","جغرافيا"],
  ["Japan","Tokyo","Geography","اليابان","طوكيو","جغرافيا"],
  ["Egypt","Cairo","Geography","مصر","القاهرة","جغرافيا"],
  ["Saudi Arabia","Riyadh","Geography","السعودية","الرياض","جغرافيا"],
  ["United Kingdom","London","Geography","المملكة المتحدة","لندن","جغرافيا"],
  ["Germany","Berlin","Geography","ألمانيا","برلين","جغرافيا"],
  ["Turkey","Ankara","Geography","تركيا","أنقرة","جغرافيا"],
  ["Australia","Canberra","Geography","أستراليا","كانبرا","جغرافيا"],
  ["Canada","Ottawa","Geography","كندا","أوتاوا","جغرافيا"],
  ["Brazil","Brasília","Geography","البرازيل","برازيليا","جغرافيا"],
  ["India","New Delhi","Geography","الهند","نيودلهي","جغرافيا"],
  ["China","Beijing","Geography","الصين","بكين","جغرافيا"],
  ["South Korea","Seoul","Geography","كوريا الجنوبية","سيول","جغرافيا"],
  ["Russia","Moscow","Geography","روسيا","موسكو","جغرافيا"],
  ["Greece","Athens","Geography","اليونان","أثينا","جغرافيا"],
  ["Mexico","Mexico City","Geography","المكسيك","مكسيكو سيتي","جغرافيا"],
  ["Argentina","Buenos Aires","Geography","الأرجنتين","بوينس آيرس","جغرافيا"],
  ["Kenya","Nairobi","Geography","كينيا","نيروبي","جغرافيا"],
  ["Moon","Earth's natural satellite","Science","القمر","القمر تابع طبيعي للأرض","علوم"],
  ["Mars","the Red Planet","Science","المريخ","الكوكب الأحمر","علوم"],
  ["Venus","the hottest planet in the Solar System","Science","الزهرة","أكثر كواكب النظام الشمسي حرارة","علوم"],
  ["Jupiter","the largest planet in the Solar System","Science","المشتري","أكبر كواكب النظام الشمسي","علوم"],
  ["Saturn","the planet famous for its prominent rings","Science","زحل","الكوكب الشهير بحلقاته الواضحة","علوم"],
  ["Earth","the third planet from the Sun","Science","الأرض","الكوكب الثالث من الشمس","علوم"],
  ["Mercury","the closest planet to the Sun","Science","عطارد","أقرب كوكب إلى الشمس","علوم"],
  ["Neptune","the farthest planet from the Sun","Science","نبتون","أبعد كوكب عن الشمس","علوم"],
  ["Water","H2O","Science","الماء","H2O","علوم"],
  ["Gold","Au","Science","الذهب","Au","علوم"],
  ["Oxygen","O2","Science","الأكسجين","O2","علوم"],
  ["Carbon dioxide","CO2","Science","ثاني أكسيد الكربون","CO2","علوم"],
  ["DNA","the molecule that carries genetic information","Science","الحمض النووي DNA","الجزيء الذي يحمل المعلومات الوراثية","علوم"],
  ["Heart","the organ that pumps blood through the body","Science","القلب","العضو الذي يضخ الدم في الجسم","علوم"],
  ["Lungs","organs responsible for gas exchange","Science","الرئتان","الأعضاء المسؤولة عن تبادل الغازات","علوم"],
  ["Photosynthesis","the process plants use to make food using light","Science","البناء الضوئي","العملية التي تصنع بها النباتات غذاءها باستخدام الضوء","علوم"],
  ["Gravity","attraction between masses","Science","الجاذبية","قوة التجاذب بين الكتل","علوم"],
  ["Sound","a mechanical wave that needs a medium to travel","Science","الصوت","موجة ميكانيكية تحتاج إلى وسط للانتقال","علوم"],
  ["Light","electromagnetic radiation visible to the human eye","Science","الضوء","إشعاع كهرومغناطيسي يمكن للعين البشرية رؤيته","علوم"],
  ["Water's sea-level boiling point","100 °C","Science","درجة غليان الماء عند سطح البحر","100 درجة مئوية","علوم"],
  ["Water's freezing point","0 °C","Science","درجة تجمد الماء","0 درجة مئوية","علوم"],
  ["Pi","approximately 3.14159","Math","العدد باي π","تقريبًا 3.14159","رياضيات"],
  ["Triangle","a polygon with three sides","Math","المثلث","مضلع له ثلاثة أضلاع","رياضيات"],
  ["Square","a quadrilateral with four equal sides","Math","المربع","شكل رباعي له أربعة أضلاع متساوية","رياضيات"],
  ["Right angle","90 degrees","Math","الزاوية القائمة","90 درجة","رياضيات"],
  ["Dozen","12 items","Math","الدزينة","12 قطعة","رياضيات"],
  ["Binary","a base-2 number system","Math","النظام الثنائي","نظام عد أساسه 2","رياضيات"],
  ["Newton","the SI unit of force","Science","نيوتن","وحدة القوة في النظام الدولي","علوم"],
  ["Joule","the SI unit of energy","Science","جول","وحدة الطاقة في النظام الدولي","علوم"],
  ["CPU","Central Processing Unit","Technology","وحدة المعالجة المركزية CPU","Central Processing Unit","تقنية"],
  ["RAM","temporary working memory used by a computer","Technology","ذاكرة RAM","ذاكرة العمل المؤقتة التي يستخدمها الحاسوب","تقنية"],
  ["HTTP","Hypertext Transfer Protocol","Technology","HTTP","Hypertext Transfer Protocol","تقنية"],
  ["URL","the address of a resource on the web","Technology","URL","عنوان مورد على الويب","تقنية"],
  ["HTML","the markup language used to structure web pages","Technology","HTML","لغة ترميز تُستخدم لبناء هيكل صفحات الويب","تقنية"],
  ["CSS","the language used to style web pages","Technology","CSS","اللغة المستخدمة لتنسيق صفحات الويب","تقنية"],
  ["Python","a programming language","Technology","Python","لغة برمجة","تقنية"],
  ["Git","a distributed version control system","Technology","Git","نظام تحكم بالإصدارات موزع","تقنية"],
  ["Keyboard","an input device for entering text and commands","Technology","لوحة المفاتيح","جهاز إدخال لكتابة النصوص والأوامر","تقنية"],
  ["Monitor","an output device that displays visual information","Technology","الشاشة","جهاز إخراج يعرض المعلومات المرئية","تقنية"],
  ["Algorithm","a step-by-step procedure for solving a problem","Technology","الخوارزمية","إجراء من خطوات لحل مشكلة","تقنية"],
  ["Hamlet","a tragedy written by William Shakespeare","Culture","هاملت","مأساة كتبها ويليام شكسبير","ثقافة"],
  ["Beethoven's Ninth Symphony","a major work composed by Ludwig van Beethoven","Culture","السيمفونية التاسعة لبيتهوفن","عمل موسيقي بارز ألّفه لودفيغ فان بيتهوفن","ثقافة"],
  ["Mona Lisa","a painting by Leonardo da Vinci","Culture","الموناليزا","لوحة رسمها ليوناردو دا فينشي","ثقافة"],
  ["Louvre Museum","the Paris museum that houses the Mona Lisa","Culture","متحف اللوفر","متحف باريس الذي يضم الموناليزا","ثقافة"],
  ["Olympic Games","an international multi-sport event held every four years","Culture","الألعاب الأولمبية","حدث رياضي دولي متعدد الرياضات يقام كل أربع سنوات","ثقافة"],
  ["FIFA World Cup","an international football championship held every four years","Culture","كأس العالم لكرة القدم","بطولة دولية لكرة القدم تقام كل أربع سنوات","ثقافة"],
  ["Arabic alphabet","28 letters in its standard modern form","Language","الأبجدية العربية","28 حرفًا في صورتها الحديثة القياسية","لغة"],
  ["English alphabet","26 letters","Language","الأبجدية الإنجليزية","26 حرفًا","لغة"],
  ["Quran","114 surahs","Culture","القرآن الكريم","114 سورة","ثقافة"],
  ["January","the first month of the Gregorian calendar","Language","يناير","الشهر الأول في التقويم الميلادي","لغة"],
  ["Pyramids of Giza","an ancient monument complex in Egypt","Culture","أهرامات الجيزة","مجمع آثار قديم في مصر","ثقافة"],
  ["Great Wall of China","a vast defensive structure in China","Geography","سور الصين العظيم","منشأة دفاعية ضخمة في الصين","جغرافيا"],
  ["Sahara Desert","the world's largest hot desert","Geography","الصحراء الكبرى","أكبر صحراء حارة في العالم","جغرافيا"],
  ["Pacific Ocean","the largest ocean on Earth","Geography","المحيط الهادئ","أكبر محيط على الأرض","جغرافيا"]
];

function rarityFor(id) {
  const n = Number(id.slice(1));
  if (n <= 150) return 'epic';
  if (n <= 200) return 'gold';
  return 'legendary';
}

function choices(pool, correct, index, variant) {
  const wrong = [];
  let cursor = (index * 17 + variant * 11) % pool.length;
  while (wrong.length < 3) {
    const candidate = pool[cursor % pool.length];
    cursor += 1;
    if (candidate === correct || wrong.includes(candidate)) continue;
    wrong.push(candidate);
  }
  const correctPosition = (index + variant) % 3;
  const answers = [];
  let wrongCursor = 0;
  for (let i = 0; i < 3; i += 1) {
    answers.push(i === correctPosition ? correct : wrong[wrongCursor++]);
  }
  let extra = '';
  for (let step = 0; step < pool.length; step += 1) {
    const candidate = pool[(cursor + step) % pool.length];
    if (candidate !== correct && !answers.includes(candidate)) {
      extra = candidate;
      break;
    }
  }
  return {answers, correctIndex: correctPosition, extra};
}

const valuesEn = facts.map((f) => f[1]);
const valuesAr = facts.map((f) => f[4]);
const labelsEn = facts.map((f) => f[0]);
const labelsAr = facts.map((f) => f[3]);
const categoriesEn = categoryPairs.map((x) => x[0]);
const categoriesAr = categoryPairs.map((x) => x[1]);

const cards = [];
for (let i = 0; i < facts.length; i += 1) {
  const f = facts[i];
  const variants = [
    {
      qEn: 'What is the key fact for “' + f[0] + '”?',
      qAr: 'ما المعلومة الصحيحة عن «' + f[3] + '»؟',
      poolEn: valuesEn,
      poolAr: valuesAr,
      correctEn: f[1],
      correctAr: f[4],
      variant: 0
    },
    {
      qEn: 'Which item is associated with “' + f[1] + '”?',
      qAr: 'ما العنصر المرتبط بـ«' + f[4] + '»؟',
      poolEn: labelsEn,
      poolAr: labelsAr,
      correctEn: f[0],
      correctAr: f[3],
      variant: 1
    },
    {
      qEn: 'Which category best fits “' + f[0] + '”?',
      qAr: 'ما الفئة الأنسب لـ«' + f[3] + '»؟',
      poolEn: categoriesEn,
      poolAr: categoriesAr,
      correctEn: f[2],
      correctAr: f[5],
      variant: 2
    }
  ];
  for (const v of variants) {
    const id = 'Q' + String(cards.length + 1).padStart(3, '0');
    const en = choices(v.poolEn, v.correctEn, i, v.variant);
    const ar = choices(v.poolAr, v.correctAr, i, v.variant);
    cards.push({
      id,
      rarity: rarityFor(id),
      categoryEn: f[2],
      categoryAr: f[5],
      questionEn: v.qEn,
      questionAr: v.qAr,
      answersEn: en.answers,
      answersAr: ar.answers,
      correctIndex: en.correctIndex,
      fourthEn: en.extra,
      fourthAr: ar.extra
    });
  }
}

if (cards.length !== 222) throw new Error('Question catalog must contain 222 cards.');
for (const card of cards) {
  if (card.answersEn.length !== 3 || card.answersAr.length !== 3) {
    throw new Error('Every base question must contain exactly 3 answers: ' + card.id);
  }
}

function questionById(id) {
  const value = cards.find((card) => card.id === id);
  if (!value) throw new Error('Unknown question card: ' + id);
  return value;
}

function publicQuestion(id) {
  const q = questionById(id);
  return {
    questionId: q.id,
    rarity: q.rarity,
    categoryEn: q.categoryEn,
    categoryAr: q.categoryAr,
    questionEn: q.questionEn,
    questionAr: q.questionAr,
    answersEn: q.answersEn,
    answersAr: q.answersAr,
    fourthEn: q.fourthEn,
    fourthAr: q.fourthAr
  };
}

module.exports = { cards, questionById, publicQuestion };
