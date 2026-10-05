import 'game_rules.dart';

class QuestionContent {
  const QuestionContent({required this.id, required this.rarity, required this.categoryEn, required this.categoryAr, required this.questionEn, required this.questionAr, required this.answersEn, required this.answersAr, required this.correctIndex, required this.passExtraEn, required this.passExtraAr});
  final String id; final CardRarity rarity; final String categoryEn; final String categoryAr;
  final String questionEn; final String questionAr; final List<String> answersEn; final List<String> answersAr;
  final int correctIndex; final String passExtraEn; final String passExtraAr;
  List<String> answers({required bool arabic, required bool weeklyPass}) {
    final values = List<String>.unmodifiable(arabic ? answersAr : answersEn);
    if (!weeklyPass) return values;
    return List<String>.unmodifiable([...values, arabic ? passExtraAr : passExtraEn]);
  }
}

class QuestionBank {
  QuestionBank._();
  static final List<QuestionContent> all = _build();
  static final Map<String, QuestionContent> _byId = {for (final item in all) item.id: item};
  static QuestionContent byId(String id) { final value = _byId[id]; if (value == null) throw ArgumentError('Unknown question card: ' + id); return value; }
  static Iterable<QuestionContent> get normal => all.where((q) => q.rarity != CardRarity.legendary);
  static void validate() {
    if (all.length != kTotalCards) throw StateError('Question bank must contain exactly $kTotalCards cards.');
    if (_byId.length != all.length) throw StateError('Question card IDs must be unique.');
    for (final q in all) {
      if (q.answersEn.length != 3 || q.answersAr.length != 3 || q.correctIndex < 0 || q.correctIndex > 2 || q.passExtraEn.isEmpty || q.passExtraAr.isEmpty) throw StateError('Invalid question content for ' + q.id);
    }
  }
  static List<QuestionContent> _build() {
    const categoryPairs = <List<String>>[['Geography','جغرافيا'],['Science','علوم'],['Math','رياضيات'],['Technology','تقنية'],['Culture','ثقافة'],['Language','لغة']];
    final facts = <_Fact>[
      _Fact("France", "Paris", "Geography", "فرنسا", "باريس", "جغرافيا"),
      _Fact("Italy", "Rome", "Geography", "إيطاليا", "روما", "جغرافيا"),
      _Fact("Spain", "Madrid", "Geography", "إسبانيا", "مدريد", "جغرافيا"),
      _Fact("Japan", "Tokyo", "Geography", "اليابان", "طوكيو", "جغرافيا"),
      _Fact("Egypt", "Cairo", "Geography", "مصر", "القاهرة", "جغرافيا"),
      _Fact("Saudi Arabia", "Riyadh", "Geography", "السعودية", "الرياض", "جغرافيا"),
      _Fact("United Kingdom", "London", "Geography", "المملكة المتحدة", "لندن", "جغرافيا"),
      _Fact("Germany", "Berlin", "Geography", "ألمانيا", "برلين", "جغرافيا"),
      _Fact("Turkey", "Ankara", "Geography", "تركيا", "أنقرة", "جغرافيا"),
      _Fact("Australia", "Canberra", "Geography", "أستراليا", "كانبرا", "جغرافيا"),
      _Fact("Canada", "Ottawa", "Geography", "كندا", "أوتاوا", "جغرافيا"),
      _Fact("Brazil", "Brasília", "Geography", "البرازيل", "برازيليا", "جغرافيا"),
      _Fact("India", "New Delhi", "Geography", "الهند", "نيودلهي", "جغرافيا"),
      _Fact("China", "Beijing", "Geography", "الصين", "بكين", "جغرافيا"),
      _Fact("South Korea", "Seoul", "Geography", "كوريا الجنوبية", "سيول", "جغرافيا"),
      _Fact("Russia", "Moscow", "Geography", "روسيا", "موسكو", "جغرافيا"),
      _Fact("Greece", "Athens", "Geography", "اليونان", "أثينا", "جغرافيا"),
      _Fact("Mexico", "Mexico City", "Geography", "المكسيك", "مكسيكو سيتي", "جغرافيا"),
      _Fact("Argentina", "Buenos Aires", "Geography", "الأرجنتين", "بوينس آيرس", "جغرافيا"),
      _Fact("Kenya", "Nairobi", "Geography", "كينيا", "نيروبي", "جغرافيا"),
      _Fact("Moon", "Earth's natural satellite", "Science", "القمر", "القمر تابع طبيعي للأرض", "علوم"),
      _Fact("Mars", "the Red Planet", "Science", "المريخ", "الكوكب الأحمر", "علوم"),
      _Fact("Venus", "the hottest planet in the Solar System", "Science", "الزهرة", "أكثر كواكب النظام الشمسي حرارة", "علوم"),
      _Fact("Jupiter", "the largest planet in the Solar System", "Science", "المشتري", "أكبر كواكب النظام الشمسي", "علوم"),
      _Fact("Saturn", "the planet famous for its prominent rings", "Science", "زحل", "الكوكب الشهير بحلقاته الواضحة", "علوم"),
      _Fact("Earth", "the third planet from the Sun", "Science", "الأرض", "الكوكب الثالث من الشمس", "علوم"),
      _Fact("Mercury", "the closest planet to the Sun", "Science", "عطارد", "أقرب كوكب إلى الشمس", "علوم"),
      _Fact("Neptune", "the farthest planet from the Sun", "Science", "نبتون", "أبعد كوكب عن الشمس", "علوم"),
      _Fact("Water", "H2O", "Science", "الماء", "H2O", "علوم"),
      _Fact("Gold", "Au", "Science", "الذهب", "Au", "علوم"),
      _Fact("Oxygen", "O2", "Science", "الأكسجين", "O2", "علوم"),
      _Fact("Carbon dioxide", "CO2", "Science", "ثاني أكسيد الكربون", "CO2", "علوم"),
      _Fact("DNA", "the molecule that carries genetic information", "Science", "الحمض النووي DNA", "الجزيء الذي يحمل المعلومات الوراثية", "علوم"),
      _Fact("Heart", "the organ that pumps blood through the body", "Science", "القلب", "العضو الذي يضخ الدم في الجسم", "علوم"),
      _Fact("Lungs", "organs responsible for gas exchange", "Science", "الرئتان", "الأعضاء المسؤولة عن تبادل الغازات", "علوم"),
      _Fact("Photosynthesis", "the process plants use to make food using light", "Science", "البناء الضوئي", "العملية التي تصنع بها النباتات غذاءها باستخدام الضوء", "علوم"),
      _Fact("Gravity", "attraction between masses", "Science", "الجاذبية", "قوة التجاذب بين الكتل", "علوم"),
      _Fact("Sound", "a mechanical wave that needs a medium to travel", "Science", "الصوت", "موجة ميكانيكية تحتاج إلى وسط للانتقال", "علوم"),
      _Fact("Light", "electromagnetic radiation visible to the human eye", "Science", "الضوء", "إشعاع كهرومغناطيسي يمكن للعين البشرية رؤيته", "علوم"),
      _Fact("Water's sea-level boiling point", "100 °C", "Science", "درجة غليان الماء عند سطح البحر", "100 درجة مئوية", "علوم"),
      _Fact("Water's freezing point", "0 °C", "Science", "درجة تجمد الماء", "0 درجة مئوية", "علوم"),
      _Fact("Pi", "approximately 3.14159", "Math", "العدد باي π", "تقريبًا 3.14159", "رياضيات"),
      _Fact("Triangle", "a polygon with three sides", "Math", "المثلث", "مضلع له ثلاثة أضلاع", "رياضيات"),
      _Fact("Square", "a quadrilateral with four equal sides", "Math", "المربع", "شكل رباعي له أربعة أضلاع متساوية", "رياضيات"),
      _Fact("Right angle", "90 degrees", "Math", "الزاوية القائمة", "90 درجة", "رياضيات"),
      _Fact("Dozen", "12 items", "Math", "الدزينة", "12 قطعة", "رياضيات"),
      _Fact("Binary", "a base-2 number system", "Math", "النظام الثنائي", "نظام عد أساسه 2", "رياضيات"),
      _Fact("Newton", "the SI unit of force", "Science", "نيوتن", "وحدة القوة في النظام الدولي", "علوم"),
      _Fact("Joule", "the SI unit of energy", "Science", "جول", "وحدة الطاقة في النظام الدولي", "علوم"),
      _Fact("CPU", "Central Processing Unit", "Technology", "وحدة المعالجة المركزية CPU", "Central Processing Unit", "تقنية"),
      _Fact("RAM", "temporary working memory used by a computer", "Technology", "ذاكرة RAM", "ذاكرة العمل المؤقتة التي يستخدمها الحاسوب", "تقنية"),
      _Fact("HTTP", "Hypertext Transfer Protocol", "Technology", "HTTP", "Hypertext Transfer Protocol", "تقنية"),
      _Fact("URL", "the address of a resource on the web", "Technology", "URL", "عنوان مورد على الويب", "تقنية"),
      _Fact("HTML", "the markup language used to structure web pages", "Technology", "HTML", "لغة ترميز تُستخدم لبناء هيكل صفحات الويب", "تقنية"),
      _Fact("CSS", "the language used to style web pages", "Technology", "CSS", "اللغة المستخدمة لتنسيق صفحات الويب", "تقنية"),
      _Fact("Python", "a programming language", "Technology", "Python", "لغة برمجة", "تقنية"),
      _Fact("Git", "a distributed version control system", "Technology", "Git", "نظام تحكم بالإصدارات موزع", "تقنية"),
      _Fact("Keyboard", "an input device for entering text and commands", "Technology", "لوحة المفاتيح", "جهاز إدخال لكتابة النصوص والأوامر", "تقنية"),
      _Fact("Monitor", "an output device that displays visual information", "Technology", "الشاشة", "جهاز إخراج يعرض المعلومات المرئية", "تقنية"),
      _Fact("Algorithm", "a step-by-step procedure for solving a problem", "Technology", "الخوارزمية", "إجراء من خطوات لحل مشكلة", "تقنية"),
      _Fact("Hamlet", "a tragedy written by William Shakespeare", "Culture", "هاملت", "مأساة كتبها ويليام شكسبير", "ثقافة"),
      _Fact("Beethoven's Ninth Symphony", "a major work composed by Ludwig van Beethoven", "Culture", "السيمفونية التاسعة لبيتهوفن", "عمل موسيقي بارز ألّفه لودفيغ فان بيتهوفن", "ثقافة"),
      _Fact("Mona Lisa", "a painting by Leonardo da Vinci", "Culture", "الموناليزا", "لوحة رسمها ليوناردو دا فينشي", "ثقافة"),
      _Fact("Louvre Museum", "the Paris museum that houses the Mona Lisa", "Culture", "متحف اللوفر", "متحف باريس الذي يضم الموناليزا", "ثقافة"),
      _Fact("Olympic Games", "an international multi-sport event held every four years", "Culture", "الألعاب الأولمبية", "حدث رياضي دولي متعدد الرياضات يقام كل أربع سنوات", "ثقافة"),
      _Fact("FIFA World Cup", "an international football championship held every four years", "Culture", "كأس العالم لكرة القدم", "بطولة دولية لكرة القدم تقام كل أربع سنوات", "ثقافة"),
      _Fact("Arabic alphabet", "28 letters in its standard modern form", "Language", "الأبجدية العربية", "28 حرفًا في صورتها الحديثة القياسية", "لغة"),
      _Fact("English alphabet", "26 letters", "Language", "الأبجدية الإنجليزية", "26 حرفًا", "لغة"),
      _Fact("Quran", "114 surahs", "Culture", "القرآن الكريم", "114 سورة", "ثقافة"),
      _Fact("January", "the first month of the Gregorian calendar", "Language", "يناير", "الشهر الأول في التقويم الميلادي", "لغة"),
      _Fact("Pyramids of Giza", "an ancient monument complex in Egypt", "Culture", "أهرامات الجيزة", "مجمع آثار قديم في مصر", "ثقافة"),
      _Fact("Great Wall of China", "a vast defensive structure in China", "Geography", "سور الصين العظيم", "منشأة دفاعية ضخمة في الصين", "جغرافيا"),
      _Fact("Sahara Desert", "the world's largest hot desert", "Geography", "الصحراء الكبرى", "أكبر صحراء حارة في العالم", "جغرافيا"),
      _Fact("Pacific Ocean", "the largest ocean on Earth", "Geography", "المحيط الهادئ", "أكبر محيط على الأرض", "جغرافيا"),
    ];
    final valuePoolEn = facts.map((f) => f.valueEn).toList(growable: false);
    final valuePoolAr = facts.map((f) => f.valueAr).toList(growable: false);
    final labelPoolEn = facts.map((f) => f.labelEn).toList(growable: false);
    final labelPoolAr = facts.map((f) => f.labelAr).toList(growable: false);
    final categoryPoolEn = categoryPairs.map((e) => e[0]).toList(growable: false);
    final categoryPoolAr = categoryPairs.map((e) => e[1]).toList(growable: false);
    final result = <QuestionContent>[];
    for (int i = 0; i < facts.length; i++) {
      final f = facts[i];
      final id1 = 'Q' + (result.length + 1).toString().padLeft(3, '0');
      result.add(_make(id1, f, 'What is the key fact for “' + f.labelEn + '”?', 'ما المعلومة الصحيحة عن «' + f.labelAr + '»؟', _choices(valuePoolEn,valuePoolAr,f.valueEn,f.valueAr,i,0)));
      final id2 = 'Q' + (result.length + 1).toString().padLeft(3, '0');
      result.add(_make(id2, f, 'Which item is associated with “' + f.valueEn + '”?', 'ما العنصر المرتبط بـ«' + f.valueAr + '»؟', _choices(labelPoolEn,labelPoolAr,f.labelEn,f.labelAr,i,1)));
      final id3 = 'Q' + (result.length + 1).toString().padLeft(3, '0');
      result.add(_make(id3, f, 'Which category best fits “' + f.labelEn + '”?', 'ما الفئة الأنسب لـ«' + f.labelAr + '»؟', _choices(categoryPoolEn,categoryPoolAr,f.categoryEn,f.categoryAr,i,2)));
    }
    if (result.length != kTotalCards) throw StateError('Generated ' + result.length.toString() + ' questions, expected ' + kTotalCards.toString() + '.');
    return List<QuestionContent>.unmodifiable(result);
  }
  static QuestionContent _make(String id,_Fact f,String questionEn,String questionAr,_Choice choice) => QuestionContent(id:id,rarity:_rarityFor(id),categoryEn:f.categoryEn,categoryAr:f.categoryAr,questionEn:questionEn,questionAr:questionAr,answersEn:choice.en,answersAr:choice.ar,correctIndex:choice.correctIndex,passExtraEn:choice.extraEn,passExtraAr:choice.extraAr);
  static CardRarity _rarityFor(String id) { final n=int.parse(id.substring(1)); if(n<=150)return CardRarity.epic; if(n<=200)return CardRarity.gold; return CardRarity.legendary; }
  static _Choice _choices(List<String> poolEn,List<String> poolAr,String correctEn,String correctAr,int index,int variant) {
    final wrongEn=<String>[]; final wrongAr=<String>[]; int cursor=(index*17+variant*11)%poolEn.length;
    while(wrongEn.length<3){ final ce=poolEn[cursor%poolEn.length]; final ca=poolAr[cursor%poolAr.length]; cursor++; if(ce==correctEn||wrongEn.contains(ce))continue; wrongEn.add(ce); wrongAr.add(ca); }
    final cp=(index+variant)%3; final ae=<String>[]; final aa=<String>[]; int wi=0;
    for(int i=0;i<3;i++){ if(i==cp){ae.add(correctEn);aa.add(correctAr);}else{ae.add(wrongEn[wi]);aa.add(wrongAr[wi]);wi++;} }
    String extraEn=''; String extraAr='';
    for(int step=0;step<poolEn.length;step++){ final ce=poolEn[(cursor+step)%poolEn.length]; final ca=poolAr[(cursor+step)%poolAr.length]; if(ce!=correctEn&&!ae.contains(ce)){extraEn=ce;extraAr=ca;break;} }
    return _Choice(en:List.unmodifiable(ae),ar:List.unmodifiable(aa),correctIndex:cp,extraEn:extraEn,extraAr:extraAr);
  }
}
class _Fact { const _Fact(this.labelEn,this.valueEn,this.categoryEn,this.labelAr,this.valueAr,this.categoryAr); final String labelEn,valueEn,categoryEn,labelAr,valueAr,categoryAr; }
class _Choice { const _Choice({required this.en,required this.ar,required this.correctIndex,required this.extraEn,required this.extraAr}); final List<String> en,ar; final int correctIndex; final String extraEn,extraAr; }