// lib/core/data/puzzles_data.dart

import '../../models/puzzle_models.dart';
import '../constants.dart';
import '../models/card.dart';

class PuzzlesData {
  /// Returns the complete library of Estimation puzzles
  static List<EstimationPuzzle> getAllPuzzles() {
    return [
      // ═══════════════════════════════════════════════════════════════════════
      // 1. BID PUZZLES (مزايدات المزاد)
      // ═══════════════════════════════════════════════════════════════════════
      EstimationPuzzle(
        id: 'bid_puz_1',
        title: 'مزايدة السبيد القوية',
        category: PuzzleCategory.bid,
        difficulty: PuzzleDifficulty.beginner,
        scenarioText:
            'يدك تحتوي على 5 كروت سبيد قوية مع A-K-Q وتوزيع جيد في باقي الألوان. الخصم قبلك قال باس.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.king),
          PlayingCard(suit: Suit.spade, rank: Rank.queen),
          PlayingCard(suit: Suit.spade, rank: Rank.eight),
          PlayingCard(suit: Suit.spade, rank: Rank.four),
          PlayingCard(suit: Suit.heart, rank: Rank.ace),
          PlayingCard(suit: Suit.heart, rank: Rank.jack),
          PlayingCard(suit: Suit.diamond, rank: Rank.king),
          PlayingCard(suit: Suit.diamond, rank: Rank.ten),
          PlayingCard(suit: Suit.club, rank: Rank.queen),
          PlayingCard(suit: Suit.club, rank: Rank.seven),
          PlayingCard(suit: Suit.club, rank: Rank.five),
          PlayingCard(suit: Suit.club, rank: Rank.two),
        ],
        context: const PuzzleContext(
          roundNumber: 2,
          totalRounds: 18,
          playerPosition: 'اللاعب الثاني',
          highBidInfo: 'لا توجد مزايدات حتى الآن',
        ),
        prompt: 'ما هي المزايدة الافتتاحية المثالية بهذه اليد؟',
        options: const [
          PuzzleOption(
            id: 'bp1_opt_1',
            label: 'Pass (تمرير)',
            quality: PuzzleResultQuality.invalid,
            feedback: 'يدك قوية جداً (Control + 5 Trumps) وتمريرك يفرط في فرصة فوز سهلة بالجولة.',
          ),
          PuzzleOption(
            id: 'bp1_opt_2',
            label: '4 ♠ (أربعة سبيد)',
            quality: PuzzleResultQuality.weak,
            feedback: 'مزايدة ضعيفة جداً ومتحفظة زيادة عن اللزوم ليد تضمن 6-7 أكلات بسهولة.',
          ),
          PuzzleOption(
            id: 'bp1_opt_3',
            label: '6 ♠ (ستة سبيد)',
            quality: PuzzleResultQuality.optimal,
            feedback: 'مثالي! يدك تملك 4 أكلات سبيد مؤكدة + آص الهارت + كينج الكارو، مع قابلية للتطوير إلى 7.',
          ),
          PuzzleOption(
            id: 'bp1_opt_4',
            label: '8 ♠ (ثمانية سبيد)',
            quality: PuzzleResultQuality.weak,
            feedback: 'مبالغ فيها ومخاطرة غير مبررة في بداية المزاد مع وجود 4 كروت تريفل ضعيفة.',
          ),
        ],
        optimalOptionId: 'bp1_opt_3',
        acceptableOptionIds: const ['bp1_opt_3'],
        tacticalRationale:
            'الـ 6 سبيد تضمن السيطرة على المزاد برقم متزن ومضمون مع الحفاظ على مرونة إعلان الكول لاحقاً.',
      ),

      EstimationPuzzle(
        id: 'bid_puz_2',
        title: 'فخ السانز (No-Trump Trap)',
        category: PuzzleCategory.bid,
        difficulty: PuzzleDifficulty.intermediate,
        scenarioText:
            'معك ورق قوي في 3 ألوان، ولكنك خالٍ تماماً (Void) في لون التريفل ♣ بدون ولا ورقة!',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.king),
          PlayingCard(suit: Suit.spade, rank: Rank.jack),
          PlayingCard(suit: Suit.spade, rank: Rank.five),
          PlayingCard(suit: Suit.heart, rank: Rank.ace),
          PlayingCard(suit: Suit.heart, rank: Rank.king),
          PlayingCard(suit: Suit.heart, rank: Rank.ten),
          PlayingCard(suit: Suit.heart, rank: Rank.four),
          PlayingCard(suit: Suit.diamond, rank: Rank.ace),
          PlayingCard(suit: Suit.diamond, rank: Rank.king),
          PlayingCard(suit: Suit.diamond, rank: Rank.queen),
          PlayingCard(suit: Suit.diamond, rank: Rank.nine),
          PlayingCard(suit: Suit.diamond, rank: Rank.two),
        ],
        context: const PuzzleContext(
          roundNumber: 6,
          totalRounds: 18,
          playerPosition: 'اللاعب الثالث',
          highBidInfo: 'أعلى مزايدة حالية: 6 هارت ♥',
        ),
        prompt: 'الخصم قال 6 هارت. هل تزايد بـ 7 سانز (Sans) أم تزايد بلون آخر؟',
        options: const [
          PuzzleOption(
            id: 'bp2_opt_1',
            label: '7 سانز (Sans)',
            quality: PuzzleResultQuality.invalid,
            feedback: 'كارثة في السانز! الخصوم سيلعبون التريفل ويسحبون كل أكلاتهم دون أن تتمكن من القطوع لأن السانز بدون أتوت.',
          ),
          PuzzleOption(
            id: 'bp2_opt_2',
            label: '7 سبيد (7 ♠)',
            quality: PuzzleResultQuality.optimal,
            feedback: 'قرار عبقري! لون السبيد يحميك، وفراغ التريفل يتحول إلى قوة قطوع ساحقة بأتوت السبيد.',
          ),
          PuzzleOption(
            id: 'bp2_opt_3',
            label: 'Pass (تمرير)',
            quality: PuzzleResultQuality.weak,
            feedback: 'التمرير يترك الـ 6 هارت للخصم بينما يدك تملك قوة هائلة للفوز بـ 7 سبيد.',
          ),
        ],
        optimalOptionId: 'bp2_opt_2',
        acceptableOptionIds: const ['bp2_opt_2'],
        tacticalRationale:
            'في السانز، الفويد (الخلو من لون) نقطة ضعف قاتلة. بينما في ألوان القطوع (Trump) هو ميزة تكتيكية هائلة للقطوع.',
      ),

      EstimationPuzzle(
        id: 'bid_puz_3',
        title: 'المزايدة التنافسية بالموقع المتأخر',
        category: PuzzleCategory.bid,
        difficulty: PuzzleDifficulty.advanced,
        scenarioText:
            'أنت موزع الورق (Dealer). اللاعبون قالوا: 4 سبيد، 5 كارو، 6 هارت. معك يد متوازنة جداً.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.queen),
          PlayingCard(suit: Suit.spade, rank: Rank.six),
          PlayingCard(suit: Suit.heart, rank: Rank.king),
          PlayingCard(suit: Suit.heart, rank: Rank.jack),
          PlayingCard(suit: Suit.diamond, rank: Rank.ace),
          PlayingCard(suit: Suit.diamond, rank: Rank.ten),
          PlayingCard(suit: Suit.diamond, rank: Rank.five),
          PlayingCard(suit: Suit.club, rank: Rank.ace),
          PlayingCard(suit: Suit.club, rank: Rank.king),
          PlayingCard(suit: Suit.club, rank: Rank.queen),
          PlayingCard(suit: Suit.club, rank: Rank.eight),
          PlayingCard(suit: Suit.club, rank: Rank.three),
        ],
        context: const PuzzleContext(
          roundNumber: 10,
          totalRounds: 18,
          playerPosition: 'الموزع (Dealer)',
          highBidInfo: 'أعلى مزايدة: 6 هارت ♥',
          otherBidsInfo: 'P1: 4♠, P2: 5♦, P3: 6♥',
        ),
        prompt: 'المزاد وصل 6 هارت عند P3. ما هي خطوتك وأنت الموزع الأخير؟',
        options: const [
          PuzzleOption(
            id: 'bp3_opt_1',
            label: '7 تريفل (7 ♣)',
            quality: PuzzleResultQuality.optimal,
            feedback: 'ممتاز! تملك 5 كروت تريفل مع A-K-Q وآصات خارجية في كل الألوان، مما يجعل 7 ♣ عقداً قوياً ومربحاً.',
          ),
          PuzzleOption(
            id: 'bp3_opt_2',
            label: 'Pass (تمرير وإعطاء الجولة لـ P3)',
            quality: PuzzleResultQuality.weak,
            feedback: 'P3 سيحقق كوله بسهولة ولديك يد مسيطرة قادرة على سرقة الجولة.',
          ),
          PuzzleOption(
            id: 'bp3_opt_3',
            label: '8 تريفل (8 ♣)',
            quality: PuzzleResultQuality.weak,
            feedback: 'القفز لـ 8 غير ضروري ويزيد من احتمالية السقوط بينما 7 كافية للتفوق على 6 هارت.',
          ),
        ],
        optimalOptionId: 'bp3_opt_1',
        acceptableOptionIds: const ['bp3_opt_1'],
        tacticalRationale:
            'عندما تكون الموزع، استغل موقعك الأخير ويدك القوية في التريفل للسيطرة على العقد بأقل رقم ممكن فوق الخصم.',
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // 2. DECLARATION PUZZLES (إعلان الكول)
      // ═══════════════════════════════════════════════════════════════════════
      EstimationPuzzle(
        id: 'dec_puz_1',
        title: 'قاعدة الـ 13 المحرمة (Forbidden 13)',
        category: PuzzleCategory.declaration,
        difficulty: PuzzleDifficulty.beginner,
        scenarioText:
            'أنت آخر لاعب يعلن الكول. مجموع كولات اللاعبين الثلاثة قبلك = 9 أكلات (3 + 4 + 2). يدك تضمن 4 أكلات.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.king),
          PlayingCard(suit: Suit.heart, rank: Rank.ace),
          PlayingCard(suit: Suit.diamond, rank: Rank.ace),
          PlayingCard(suit: Suit.diamond, rank: Rank.nine),
          PlayingCard(suit: Suit.diamond, rank: Rank.six),
          PlayingCard(suit: Suit.club, rank: Rank.jack),
          PlayingCard(suit: Suit.club, rank: Rank.eight),
          PlayingCard(suit: Suit.club, rank: Rank.seven),
          PlayingCard(suit: Suit.club, rank: Rank.five),
          PlayingCard(suit: Suit.club, rank: Rank.four),
          PlayingCard(suit: Suit.club, rank: Rank.three),
          PlayingCard(suit: Suit.club, rank: Rank.two),
        ],
        context: const PuzzleContext(
          roundNumber: 4,
          totalRounds: 18,
          trump: Trump.spade,
          playerPosition: 'اللاعب الأخير في إعلان الكول',
          declaredCallsInfo: 'اللاعبون طلبوا: 3، 4، 2 (المجموع = 9)',
        ),
        prompt: 'هل يمكنك طلب 4 أكلات؟ وإذا كان ممنوعاً، ما هو قرارك الأمثل؟',
        options: const [
          PuzzleOption(
            id: 'dp1_opt_1',
            label: 'طلب 4 (Call 4)',
            quality: PuzzleResultQuality.invalid,
            feedback: 'غير قانوني! 9 + 4 = 13، وقاعدة الإستميشن تمنع أن يكون مجموع الكولات 13 للاعب الأخير.',
          ),
          PuzzleOption(
            id: 'dp1_opt_2',
            label: 'طلب 5 (Call 5)',
            quality: PuzzleResultQuality.strong,
            feedback: 'قانوني ولكن يحتاج مجهوداً وسرقة أكلة إضافية بورق التريفل الطويل.',
          ),
          PuzzleOption(
            id: 'dp1_opt_3',
            label: 'طلب 3 (Call 3)',
            quality: PuzzleResultQuality.optimal,
            feedback: 'ممتاز! قانوني (المجموع 12 Over) ويمكنك التخلص بسهولة من أكلة زائدة برمي الكروت الضعيفة.',
          ),
        ],
        optimalOptionId: 'dp1_opt_3',
        acceptableOptionIds: const ['dp1_opt_3', 'dp1_opt_2'],
        tacticalRationale:
            'في حالة المنع بالـ 13، إنزال الكول برقم (Under) مع التخلص من الأكلات الزائدة أسهل تكتيكياً من طلب زيادة.',
      ),

      EstimationPuzzle(
        id: 'dec_puz_2',
        title: 'إعلان الداون كول (Under Bidding)',
        category: PuzzleCategory.declaration,
        difficulty: PuzzleDifficulty.intermediate,
        scenarioText:
            'أنت فزت بالمزاد بـ 6 سبيد. بعد فحص يدك جيداً، اكتشفت أن أكلتين من الـ 6 مهددتان بالقطع الخارجي.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.king),
          PlayingCard(suit: Suit.spade, rank: Rank.jack),
          PlayingCard(suit: Suit.spade, rank: Rank.ten),
          PlayingCard(suit: Suit.spade, rank: Rank.two),
          PlayingCard(suit: Suit.heart, rank: Rank.queen),
          PlayingCard(suit: Suit.heart, rank: Rank.jack),
          PlayingCard(suit: Suit.diamond, rank: Rank.king),
          PlayingCard(suit: Suit.diamond, rank: Rank.four),
          PlayingCard(suit: Suit.club, rank: Rank.ten),
          PlayingCard(suit: Suit.club, rank: Rank.eight),
          PlayingCard(suit: Suit.club, rank: Rank.six),
          PlayingCard(suit: Suit.club, rank: Rank.three),
        ],
        context: const PuzzleContext(
          roundNumber: 8,
          totalRounds: 18,
          trump: Trump.spade,
          highBidInfo: 'أنت صاحب أعلى مزايدة (6 سبيد)',
        ),
        prompt: 'كم كول يجب أن تطلب كصاحب مزاد؟',
        options: const [
          PuzzleOption(
            id: 'dp2_opt_1',
            label: 'طلب 5 أكلات',
            quality: PuzzleResultQuality.invalid,
            feedback: 'غير قانوني! صاحب المزاد لا يمكنه إعلان كول أقل من مزايدته (الحد الأدنى 6).',
          ),
          PuzzleOption(
            id: 'dp2_opt_2',
            label: 'طلب 6 أكلات (الحد الأدنى القانوني)',
            quality: PuzzleResultQuality.optimal,
            feedback: 'صحيح! عليك طلب 6 واللعب بتركيز لسحب الأتوت وحماية كينج الكارو لتأمين الأكلات الست.',
          ),
          PuzzleOption(
            id: 'dp2_opt_3',
            label: 'طلب 7 أكلات للتعويض',
            quality: PuzzleResultQuality.invalid,
            feedback: 'انتحار تكتيكي! يدك بالكاد تحقق 6 فكيف تزيد إلى 7؟',
          ),
        ],
        optimalOptionId: 'dp2_opt_2',
        acceptableOptionIds: const ['dp2_opt_2'],
        tacticalRationale:
            'قواعد الإستميشن تلزم صاحب أعلى مزايدة بأن يكون كوله مساوياً لمزايدته على الأقل.',
      ),

      EstimationPuzzle(
        id: 'dec_puz_3',
        title: 'حساب الكول في جولات السانز المزدوجة',
        category: PuzzleCategory.declaration,
        difficulty: PuzzleDifficulty.expert,
        scenarioText:
            'جولة سانز مزدوجة (Sans Double). لديك سيطرة بطول السبيد ♠ ولكن تنقصك الآصات في لوني الهارت والكارو.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.king),
          PlayingCard(suit: Suit.spade, rank: Rank.queen),
          PlayingCard(suit: Suit.spade, rank: Rank.jack),
          PlayingCard(suit: Suit.spade, rank: Rank.nine),
          PlayingCard(suit: Suit.spade, rank: Rank.four),
          PlayingCard(suit: Suit.heart, rank: Rank.king),
          PlayingCard(suit: Suit.heart, rank: Rank.three),
          PlayingCard(suit: Suit.diamond, rank: Rank.queen),
          PlayingCard(suit: Suit.diamond, rank: Rank.jack),
          PlayingCard(suit: Suit.diamond, rank: Rank.five),
          PlayingCard(suit: Suit.club, rank: Rank.king),
          PlayingCard(suit: Suit.club, rank: Rank.two),
        ],
        context: const PuzzleContext(
          roundNumber: 15,
          totalRounds: 18,
          trump: Trump.sans,
          playerPosition: 'اللاعب الثاني',
          declaredCallsInfo: 'P1 طلب 3 أكلات',
        ),
        prompt: 'ما هو إعلان الكول الأدق لحماية نقاطك في الجولة المزدوجة؟',
        options: const [
          PuzzleOption(
            id: 'dp3_opt_1',
            label: 'طلب 7 أكلات',
            quality: PuzzleResultQuality.weak,
            feedback: 'تفاؤل خطير في السانز! بدون حماية الآصات في الهارت والكارو سيأخذ الخصوم 4-5 أكلات سريعة.',
          ),
          PuzzleOption(
            id: 'dp3_opt_2',
            label: 'طلب 5 أكلات',
            quality: PuzzleResultQuality.optimal,
            feedback: 'تكتيك أستاذ! 5 أكلات سبيد مؤكدة بمجرد فتح اللون، وتتفادى مخاطرة السقوط في جولة مضاعفة.',
          ),
          PuzzleOption(
            id: 'dp3_opt_3',
            label: 'طلب 3 أكلات',
            quality: PuzzleResultQuality.weak,
            feedback: 'متحفظ زيادة عن اللزوم، فالسبيد سيجبرك على أكل 5 على الأقل وستسقط بالأوفير (Overtricks).',
          ),
        ],
        optimalOptionId: 'dp3_opt_2',
        acceptableOptionIds: const ['dp3_opt_2'],
        tacticalRationale:
            'في السانز، ألوان السيطرة الطويلة تحقق كامل أوراقها بمجرد نفاذ اللون من الخصوم، فتحديد 5 يضمن عدم الوقوع في فخ الأوفير أو الأندر.',
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // 3. TRICK PUZZLES (لعب الورق التكتيكي)
      // ═══════════════════════════════════════════════════════════════════════
      EstimationPuzzle(
        id: 'trick_puz_1',
        title: 'الخروج بالورقة الآمنة',
        category: PuzzleCategory.trick,
        difficulty: PuzzleDifficulty.beginner,
        scenarioText:
            'أنت طلبت 2 وحققت الـ 2 بالفعل! الآن دورك لتلعب أول ورقة في اللمة. لا تريد أن تأكل أي أكلة إضافية.',
        playerHand: const [
          PlayingCard(suit: Suit.heart, rank: Rank.two),
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.king),
        ],
        context: const PuzzleContext(
          roundNumber: 5,
          totalRounds: 18,
          trump: Trump.diamond,
          playerPosition: 'دورك في اللعب (Leader)',
          currentTricksWon: 2,
          declaredCallsInfo: 'كولك: 2 (متحقق بالكامل)',
        ),
        prompt: 'معك آص سبيد، كينج سبيد، و 2 هارت. أي ورقة تنزل بها لتتجنب الأكل؟',
        options: const [
          PuzzleOption(
            id: 'tp1_opt_1',
            label: '2 هارت (2 ♥)',
            quality: PuzzleResultQuality.optimal,
            cardToPlay: PlayingCard(suit: Suit.heart, rank: Rank.two),
            feedback: 'ممتاز! أصغر ورقة هارت ستجبر الخصوم على الأكل فوقها وتنقذك من الأوفير.',
          ),
          PuzzleOption(
            id: 'tp1_opt_2',
            label: 'آص السبيد (A ♠)',
            quality: PuzzleResultQuality.invalid,
            cardToPlay: PlayingCard(suit: Suit.spade, rank: Rank.ace),
            feedback: 'خطأ فادح! الآص سيأكل اللمة حتماً ويعطيك أكلة ثالثة فتسقط في الجولة.',
          ),
          PuzzleOption(
            id: 'tp1_opt_3',
            label: 'كينج السبيد (K ♠)',
            quality: PuzzleResultQuality.invalid,
            cardToPlay: PlayingCard(suit: Suit.spade, rank: Rank.king),
            feedback: 'الكينج غالباً سيأكل ويزيد عدد أكلاتك عن المطلوب.',
          ),
        ],
        optimalOptionId: 'tp1_opt_1',
        acceptableOptionIds: const ['tp1_opt_1'],
        tacticalRationale:
            'عند استيفاء كولك بالكامل، القاعدة الذهبية هي تصريف أصغر الأوراق في يدك لإجبار المنافسين على الفوز باللمات.',
      ),

      EstimationPuzzle(
        id: 'trick_puz_2',
        title: 'القطوع الذكي (Under-Ruffing vs Discard)',
        category: PuzzleCategory.trick,
        difficulty: PuzzleDifficulty.intermediate,
        scenarioText:
            'اللاعب P1 لعب آص الهارت ♥، واللاعب P2 قطع بـ 10 سبيد ♠ (أتوت). أنت لا تملك هارت، ومعك 4 سبيد و K كارو. كولك باقي عليه أكلة واحدة.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.four),
          PlayingCard(suit: Suit.diamond, rank: Rank.king),
          PlayingCard(suit: Suit.diamond, rank: Rank.three),
          PlayingCard(suit: Suit.club, rank: Rank.eight),
        ],
        context: const PuzzleContext(
          roundNumber: 7,
          totalRounds: 18,
          trump: Trump.spade,
          playerPosition: 'اللاعب الثالث في اللمة',
          currentTrickCards: [
            TrickCard(card: PlayingCard(suit: Suit.heart, rank: Rank.ace), playerId: 'P1'),
            TrickCard(card: PlayingCard(suit: Suit.spade, rank: Rank.ten), playerId: 'P2'),
          ],
          currentTricksWon: 1,
          declaredCallsInfo: 'كولك: 2 (محقق 1)',
        ),
        prompt: 'بما أنك فويد في الهارت، ماذا تلعب؟',
        options: const [
          PuzzleOption(
            id: 'tp2_opt_1',
            label: '4 سبيد (4 ♠) - القطوع بأتوت أصغر',
            quality: PuzzleResultQuality.invalid,
            cardToPlay: PlayingCard(suit: Suit.spade, rank: Rank.four),
            feedback: 'إهدار للأتوت! الـ 4 سبيد أصغر من الـ 10 سبيد ولن تكسب اللمة فتخسر ورقة أتوت بلا أي فائدة.',
          ),
          PuzzleOption(
            id: 'tp2_opt_2',
            label: '3 كارو (3 ♦) - تصريف كارت صغير',
            quality: PuzzleResultQuality.strong,
            cardToPlay: PlayingCard(suit: Suit.diamond, rank: Rank.three),
            feedback: 'جيد، تتخلص من كارت ضعيف وتحتفظ بأتوتك.',
          ),
          PuzzleOption(
            id: 'tp2_opt_3',
            label: 'كينج الكارو (K ♦) أو تصريف كارت حر مع الاحتفاظ بالأوتوت',
            quality: PuzzleResultQuality.optimal,
            cardToPlay: PlayingCard(suit: Suit.diamond, rank: Rank.three),
            feedback: 'صحيح تماماً! الاحتفاظ بـ 4 ♠ للقطع بها لاحقاً في لون آخر وكسب أكلتك الأخيرة.',
          ),
        ],
        optimalOptionId: 'tp2_opt_3',
        acceptableOptionIds: const ['tp2_opt_3', 'tp2_opt_2'],
        tacticalRationale:
            'لا تقطع أبداً بأتوت أقل من الأتوت الموجود على الأرض (Under-ruffing) إلا إذا كنت مجبراً، بل صرف كارت غير مفيد واحتفظ بالأتوت لفرصة أكل قادمة.',
      ),

      EstimationPuzzle(
        id: 'trick_puz_3',
        title: 'استدراج الأتوت وحبس كينج الخصم',
        category: PuzzleCategory.trick,
        difficulty: PuzzleDifficulty.expert,
        scenarioText:
            'الأتوت هو الهارت ♥. معك A و Q هارت، وأنت تعلم أن كينج الهارت مع الخصم P3 على يمينك. أنت Leader.',
        playerHand: const [
          PlayingCard(suit: Suit.heart, rank: Rank.ace),
          PlayingCard(suit: Suit.heart, rank: Rank.queen),
          PlayingCard(suit: Suit.heart, rank: Rank.five),
          PlayingCard(suit: Suit.spade, rank: Rank.nine),
        ],
        context: const PuzzleContext(
          roundNumber: 11,
          totalRounds: 18,
          trump: Trump.heart,
          playerPosition: 'اللاعب الأول (Leader)',
          declaredCallsInfo: 'تحتاج أكلتين بالتمام',
        ),
        prompt: 'كيف تلعب الهارت لتضمن الفوز بـ A و Q معاً؟',
        options: const [
          PuzzleOption(
            id: 'tp3_opt_1',
            label: 'النزول بآص الهارت (A ♥) مباشرة',
            quality: PuzzleResultQuality.weak,
            cardToPlay: PlayingCard(suit: Suit.heart, rank: Rank.ace),
            feedback: 'إذا لعبت الآص، سيلعب الخصم ورقة صغيرة، ثم يأكل الكينج كوينك في اللمة التالية.',
          ),
          PuzzleOption(
            id: 'tp3_opt_2',
            label: 'النزول بـ 5 هارت (5 ♥) باتجاه الـ Queen (Finesse)',
            quality: PuzzleResultQuality.optimal,
            cardToPlay: PlayingCard(suit: Suit.heart, rank: Rank.five),
            feedback: 'حركة احترافية (Finesse)! تلعب ورقة صغيرة نحو Q، فإن وضع P3 الكينج يأكله الآص، وإن لم يضعه تفوز الـ Q.',
          ),
          PuzzleOption(
            id: 'tp3_opt_3',
            label: 'النزول بـ 9 سبيد',
            quality: PuzzleResultQuality.weak,
            cardToPlay: PlayingCard(suit: Suit.spade, rank: Rank.nine),
            feedback: 'تأجيل سحب الأتوت يمنح الخصوم فرصة قطع أوراقك الأخرى.',
          ),
        ],
        optimalOptionId: 'tp3_opt_2',
        acceptableOptionIds: const ['tp3_opt_2'],
        tacticalRationale:
            'تكتيك الفينيس (Finesse) هو حبس كينج الخصم بين الآص والكوين بإجباره على الاختيار بين النزول فيأكله الآص أو التراجع فتفوز الكوين.',
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // 4. RISK PUZZLES (قرارات الريسك)
      // ═══════════════════════════════════════════════════════════════════════
      EstimationPuzzle(
        id: 'risk_puz_1',
        title: 'ريسك المضمون vs المغامرة',
        category: PuzzleCategory.risk,
        difficulty: PuzzleDifficulty.beginner,
        scenarioText:
            'يدك تحتوي على A-K-Q-J في لون القطوع، مع آصات خارجية في كل الألوان الأخرى. كولك 6 أكلات مؤكدة 100%.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.king),
          PlayingCard(suit: Suit.spade, rank: Rank.queen),
          PlayingCard(suit: Suit.spade, rank: Rank.jack),
          PlayingCard(suit: Suit.spade, rank: Rank.ten),
          PlayingCard(suit: Suit.heart, rank: Rank.ace),
          PlayingCard(suit: Suit.diamond, rank: Rank.ace),
          PlayingCard(suit: Suit.club, rank: Rank.nine),
          PlayingCard(suit: Suit.club, rank: Rank.six),
          PlayingCard(suit: Suit.club, rank: Rank.four),
          PlayingCard(suit: Suit.club, rank: Rank.three),
          PlayingCard(suit: Suit.diamond, rank: Rank.seven),
          PlayingCard(suit: Suit.diamond, rank: Rank.two),
        ],
        context: const PuzzleContext(
          roundNumber: 3,
          totalRounds: 18,
          trump: Trump.spade,
          playerPosition: 'اللاعب الأول',
          declaredCallsInfo: 'كولك: 6 أكلات',
        ),
        prompt: 'هل تطلب ريسك (Risk) لمضاعفة نقاط الجولة؟',
        options: const [
          PuzzleOption(
            id: 'rp1_opt_1',
            label: 'نعم، طلب ريسك (Take Risk) 🔥',
            quality: PuzzleResultQuality.optimal,
            feedback: 'قرار ممتاز! يدك محكمة الإغلاق ولا توجد أوراق خطرة تجبرك على أكلات زائدة أو ناقصة.',
          ),
          PuzzleOption(
            id: 'rp1_opt_2',
            label: 'لا، تجنب الريسك (Safe Play)',
            quality: PuzzleResultQuality.strong,
            feedback: 'خيار آمن، لكنك تفرط في مضاعفة نقاط سهلة ومضمونة إحصائياً.',
          ),
        ],
        optimalOptionId: 'rp1_opt_1',
        acceptableOptionIds: const ['rp1_opt_1', 'rp1_opt_2'],
        tacticalRationale:
            'الريسك صُمم للأيدي المسيطرة تماماً (Lockdown Hands) لمضاعفة الفارق النقطي مبكراً.',
      ),

      EstimationPuzzle(
        id: 'risk_puz_2',
        title: 'فخ الريسك عند كول الـ 1 (Single Call Trap)',
        category: PuzzleCategory.risk,
        difficulty: PuzzleDifficulty.advanced,
        scenarioText:
            'كولك 1 أكلة فقط بآص الهارت، ومعك كروت متوسطة (J, 10, 9) في باقي الألوان بدون كروت صغيرة جداً.',
        playerHand: const [
          PlayingCard(suit: Suit.heart, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.jack),
          PlayingCard(suit: Suit.spade, rank: Rank.ten),
          PlayingCard(suit: Suit.diamond, rank: Rank.jack),
          PlayingCard(suit: Suit.diamond, rank: Rank.ten),
          PlayingCard(suit: Suit.diamond, rank: Rank.nine),
          PlayingCard(suit: Suit.club, rank: Rank.jack),
          PlayingCard(suit: Suit.club, rank: Rank.ten),
          PlayingCard(suit: Suit.club, rank: Rank.eight),
          PlayingCard(suit: Suit.club, rank: Rank.seven),
          PlayingCard(suit: Suit.heart, rank: Rank.eight),
          PlayingCard(suit: Suit.heart, rank: Rank.seven),
          PlayingCard(suit: Suit.spade, rank: Rank.eight),
        ],
        context: const PuzzleContext(
          roundNumber: 9,
          totalRounds: 18,
          trump: Trump.club,
          playerPosition: 'اللاعب الرابع',
          declaredCallsInfo: 'كولك: 1',
        ),
        prompt: 'هل تطلب ريسك على كول الـ 1 بهذه اليد؟',
        options: const [
          PuzzleOption(
            id: 'rp2_opt_1',
            label: 'طلب ريسك (Risk)',
            quality: PuzzleResultQuality.invalid,
            feedback: 'خطأ فادح! الكروت المتوسطة (J, 10) في غياب الكروت الصغيرة ستجبرك على أكل لِمّة ثانية بسهولة وتسقط بالريسك.',
          ),
          PuzzleOption(
            id: 'rp2_opt_2',
            label: 'الرفض واللعب بدون ريسك (No Risk)',
            quality: PuzzleResultQuality.optimal,
            feedback: 'قرار حكيم! كول 1 مع ورق متوسط بدون صغار هو أخطر كول في اللعبة وعرضة للأوفير بنسبة عالية.',
          ),
        ],
        optimalOptionId: 'rp2_opt_2',
        acceptableOptionIds: const ['rp2_opt_2'],
        tacticalRationale:
            'كول الـ 1 يحتاج كروت صغيرة جداً (2, 3, 4) للتصريف الآمن؛ وجود الميدل (Middle cards) يجعله عرضة للأكل الإجباري.',
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // 5. DASH CALL PUZZLES (قرارات الداش كول)
      // ═══════════════════════════════════════════════════════════════════════
      EstimationPuzzle(
        id: 'dash_puz_1',
        title: 'الداش كول النظيف (Clean Dash)',
        category: PuzzleCategory.dash,
        difficulty: PuzzleDifficulty.beginner,
        scenarioText:
            'يدك خالية من أي آص أو كينج أو كوين، وكل كروتك تتراوح بين 2 و 7 في جميع الألوان مع توازن ممتاز.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.two),
          PlayingCard(suit: Suit.spade, rank: Rank.three),
          PlayingCard(suit: Suit.spade, rank: Rank.six),
          PlayingCard(suit: Suit.heart, rank: Rank.two),
          PlayingCard(suit: Suit.heart, rank: Rank.four),
          PlayingCard(suit: Suit.heart, rank: Rank.five),
          PlayingCard(suit: Suit.diamond, rank: Rank.three),
          PlayingCard(suit: Suit.diamond, rank: Rank.four),
          PlayingCard(suit: Suit.diamond, rank: Rank.seven),
          PlayingCard(suit: Suit.club, rank: Rank.two),
          PlayingCard(suit: Suit.club, rank: Rank.three),
          PlayingCard(suit: Suit.club, rank: Rank.five),
          PlayingCard(suit: Suit.club, rank: Rank.six),
        ],
        context: const PuzzleContext(
          roundNumber: 2,
          totalRounds: 18,
          trump: Trump.spade,
          playerPosition: 'اللاعب الثاني',
        ),
        prompt: 'هل تطلب داش كول (Dash Call - صفر أكلات)؟',
        options: const [
          PuzzleOption(
            id: 'dp_opt_1',
            label: 'نعم، داش كول صريح (Dash Call) 🛡️',
            quality: PuzzleResultQuality.optimal,
            feedback: 'مثالي! جميع الأوراق صغيرة ومتوازنة في الألوان الأربعة ولا يوجد أي خطر للأكل الإجباري.',
          ),
          PuzzleOption(
            id: 'dp_opt_2',
            label: 'لا، طلب 1 أكلة لتفادي عقوبة الداش',
            quality: PuzzleResultQuality.invalid,
            feedback: 'يدك مستحيل أن تأكل أكلة واحدة بهذه الكروت الضعيفة وستسقط حتماً.',
          ),
        ],
        optimalOptionId: 'dp_opt_1',
        acceptableOptionIds: const ['dp_opt_1'],
        tacticalRationale:
            'اليد المثالية للداش كول تحتوي على توزيع متوازن وكروت منخفضة القيمة في كل الألوان.',
      ),

      EstimationPuzzle(
        id: 'dash_puz_2',
        title: 'لغم الداش: اللون الطويل المفرد (Single Long Suit Hazard)',
        category: PuzzleCategory.dash,
        difficulty: PuzzleDifficulty.advanced,
        scenarioText:
            'معك 7 كروت في لون الكارو ♦ أعلى كارت فيها هو الـ 9، بينما باقي يدك كروت صغيرة جداً (2 و 3).',
        playerHand: const [
          PlayingCard(suit: Suit.diamond, rank: Rank.nine),
          PlayingCard(suit: Suit.diamond, rank: Rank.eight),
          PlayingCard(suit: Suit.diamond, rank: Rank.seven),
          PlayingCard(suit: Suit.diamond, rank: Rank.six),
          PlayingCard(suit: Suit.diamond, rank: Rank.five),
          PlayingCard(suit: Suit.diamond, rank: Rank.four),
          PlayingCard(suit: Suit.diamond, rank: Rank.two),
          PlayingCard(suit: Suit.spade, rank: Rank.two),
          PlayingCard(suit: Suit.spade, rank: Rank.three),
          PlayingCard(suit: Suit.heart, rank: Rank.two),
          PlayingCard(suit: Suit.heart, rank: Rank.four),
          PlayingCard(suit: Suit.club, rank: Rank.two),
          PlayingCard(suit: Suit.club, rank: Rank.three),
        ],
        context: const PuzzleContext(
          roundNumber: 12,
          totalRounds: 18,
          trump: Trump.spade,
          playerPosition: 'اللاعب الثالث',
        ),
        prompt: 'هل الداش كول آمن بهذه اليد؟',
        options: const [
          PuzzleOption(
            id: 'dp2_dash_1',
            label: 'آمن، لأن أعلى كارت هو 9 وليس آص أو كينج',
            quality: PuzzleResultQuality.invalid,
            feedback: 'فخ مميت! امتلاك 7 كروت كارو يعني أن الكارو سينفذ من كل الخصوم، وسيضطرون للعب كارو فتأكل الـ 9 أو 8 إجبارياً!',
          ),
          PuzzleOption(
            id: 'dp2_dash_2',
            label: 'غير آمن، وطلب كول 1 في الكارو هو الأصح',
            quality: PuzzleResultQuality.optimal,
            feedback: 'عبقري! الطول في اللون الواحد يولد قوة أكل إجبارية حتى لو كانت الأوراق متوسطة (Length Promotion).',
          ),
        ],
        optimalOptionId: 'dp2_dash_2',
        acceptableOptionIds: const ['dp2_dash_2'],
        tacticalRationale:
            'امتلاك 6 أو 7 كروت في لون واحد يؤدي إلى أكل إجباري متأخر بعد نفاذ اللون من الخصوم، مما يدمر الداش كول.',
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // 6. SCORE STRATEGY PUZZLES (استراتيجية النقاط والترتيب)
      // ═══════════════════════════════════════════════════════════════════════
      EstimationPuzzle(
        id: 'score_puz_1',
        title: 'الريمونتادا في الجولة الأخيرة',
        category: PuzzleCategory.score,
        difficulty: PuzzleDifficulty.intermediate,
        scenarioText:
            'الجولة 18 (الأخيرة). أنت في المركز الثاني متأخر بـ 35 نقطة عن المتصدر P1. اللعب بدون ريسك يمنحك 20 نقطة كحد أقصى.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.king),
          PlayingCard(suit: Suit.spade, rank: Rank.queen),
          PlayingCard(suit: Suit.spade, rank: Rank.ten),
          PlayingCard(suit: Suit.spade, rank: Rank.three),
          PlayingCard(suit: Suit.heart, rank: Rank.ace),
          PlayingCard(suit: Suit.heart, rank: Rank.jack),
          PlayingCard(suit: Suit.diamond, rank: Rank.king),
          PlayingCard(suit: Suit.diamond, rank: Rank.seven),
          PlayingCard(suit: Suit.club, rank: Rank.queen),
          PlayingCard(suit: Suit.club, rank: Rank.nine),
          PlayingCard(suit: Suit.club, rank: Rank.four),
          PlayingCard(suit: Suit.club, rank: Rank.two),
        ],
        context: const PuzzleContext(
          roundNumber: 18,
          totalRounds: 18,
          trump: Trump.spade,
          playerPosition: 'اللاعب الأول',
          scoreSituation: 'الترتيب: P1 (160 نقطة)، أنت (125 نقطة)',
        ),
        prompt: 'يدك تضمن 6 أكلات. ما هي خطتك الوحيدة للفوز بالمركز الأول في المباراة؟',
        options: const [
          PuzzleOption(
            id: 'sp1_opt_1',
            label: 'طلب 6 عادي بدون ريسك للحفاظ على المركز الثاني',
            quality: PuzzleResultQuality.weak,
            feedback: 'ستنهي المباراة في المركز الثاني مؤكداً ولن تفوز بالبطولة.',
          ),
          PuzzleOption(
            id: 'sp1_opt_2',
            label: 'طلب 6 مع ريسك (Risk 6) للحصول على +52 نقطة وخطف الصدارة',
            quality: PuzzleResultQuality.optimal,
            feedback: 'قرار بطل! الريسك هو خيارك الرياضي الوحيد لتخطي فارق الـ 35 نقطة والتتويج بالمركز الأول.',
          ),
          PuzzleOption(
            id: 'sp1_opt_3',
            label: 'طلب داش كول مجنون',
            quality: PuzzleResultQuality.invalid,
            feedback: 'مستحيل مع يد تحتوي على 4 آصات وكينجات وستسقط وتتراجع للمركز الأخير.',
          ),
        ],
        optimalOptionId: 'sp1_opt_2',
        acceptableOptionIds: const ['sp1_opt_2'],
        tacticalRationale:
            'في الجولة الختامية، يجب قياس قرارات المخاطرة بفارق نقاط الصدارة؛ اللعب الآمن هنا هو خسارة مضمونة للمباراة.',
      ),

      EstimationPuzzle(
        id: 'score_puz_2',
        title: 'تأمين الصدارة وحماية الليدر',
        category: PuzzleCategory.score,
        difficulty: PuzzleDifficulty.expert,
        scenarioText:
            'الجولة 17. أنت المتصدر بفارق 45 نقطة كاملة عن أقرب ملاحقيك. يدك متوسطة القوة.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.king),
          PlayingCard(suit: Suit.spade, rank: Rank.jack),
          PlayingCard(suit: Suit.spade, rank: Rank.four),
          PlayingCard(suit: Suit.heart, rank: Rank.queen),
          PlayingCard(suit: Suit.heart, rank: Rank.nine),
          PlayingCard(suit: Suit.heart, rank: Rank.five),
          PlayingCard(suit: Suit.diamond, rank: Rank.ace),
          PlayingCard(suit: Suit.diamond, rank: Rank.ten),
          PlayingCard(suit: Suit.diamond, rank: Rank.three),
          PlayingCard(suit: Suit.club, rank: Rank.king),
          PlayingCard(suit: Suit.club, rank: Rank.eight),
          PlayingCard(suit: Suit.club, rank: Rank.six),
          PlayingCard(suit: Suit.club, rank: Rank.two),
        ],
        context: const PuzzleContext(
          roundNumber: 17,
          totalRounds: 18,
          trump: Trump.diamond,
          playerPosition: 'اللاعب الثاني',
          scoreSituation: 'أنت في الصدارة (180 نقطة)، المركز الثاني (135 نقطة)',
        ),
        prompt: 'المزاد مفتوح، ويدك يمكنها المنافسة على 5 أو التراجع. ما هي الاستراتيجية المثلى للمتصدر؟',
        options: const [
          PuzzleOption(
            id: 'sp2_opt_1',
            label: 'المزايدة بقوة وطلب ريسك لتوسيع الفارق',
            quality: PuzzleResultQuality.invalid,
            feedback: 'مخاطرة غير مبررة تعرض فارق الـ 45 نقطة للضياع التام في حالة السقوط.',
          ),
          PuzzleOption(
            id: 'sp2_opt_2',
            label: 'المزايدة بتحفظ أو التمرير (Pass) واللعب الدفاعي المحسوب لتثبيت الصدارة',
            quality: PuzzleResultQuality.optimal,
            feedback: 'عقلية بطل! عندما تكون متقدماً بفارق مريح، هدفك هو تقليل التذبذب وتجنب السقوط الكبير.',
          ),
        ],
        optimalOptionId: 'sp2_opt_2',
        acceptableOptionIds: const ['sp2_opt_2'],
        tacticalRationale:
            'حماية فارق الصدارة المريح تعتمد على تقليل المخاطر ولعب استراتيجية دفاعية تضمن بقاء الفارق النقطي لصالحك.',
      ),

      EstimationPuzzle(
        id: 'score_puz_3',
        title: 'تحدي الأستاذ: قراءة توزيع الأتوت الكامل',
        category: PuzzleCategory.score,
        difficulty: PuzzleDifficulty.master,
        scenarioText:
            'أنت في الجولة 16، الأتوت هو السبيد ♠. لعب P1 و P2 و P3 كروت سبيد في اللمات السابقة، وأنت تعلم بدقة أن كينج السبيد الوحيد المتبقي موجود عند P2 على يسارك. بقي 3 لمات.',
        playerHand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.queen),
          PlayingCard(suit: Suit.heart, rank: Rank.four),
        ],
        context: const PuzzleContext(
          roundNumber: 16,
          totalRounds: 18,
          trump: Trump.spade,
          playerPosition: 'اللاعب الأول (Leader)',
          declaredCallsInfo: 'تحتاج بالضبط أكلتين لتكسب الجولة وتحصد الفوز',
        ),
        prompt: 'أنت Leader وباقي 3 لمات. كيف تضمن تحقيق الأكلتين المطلوبتين بنسبة 100%؟',
        options: const [
          PuzzleOption(
            id: 'sp3_opt_1',
            label: 'النزول بآص السبيد (A ♠) أولاً ثم كوين السبيد (Q ♠)',
            quality: PuzzleResultQuality.invalid,
            cardToPlay: PlayingCard(suit: Suit.spade, rank: Rank.ace),
            feedback: 'خطأ! الآص سيأكل كارت صغير، ثم عندما تلعب Q سيأكلها كينج P2، ويتبقى معك 4 هارت ضعيفة فتأخذ أكلة واحدة فقط وتسقط.',
          ),
          PuzzleOption(
            id: 'sp3_opt_2',
            label: 'النزول بـ Q ♠ مباشرة لإجبار P2 على وضع الكينج أو التراجع',
            quality: PuzzleResultQuality.optimal,
            cardToPlay: PlayingCard(suit: Suit.spade, rank: Rank.queen),
            feedback: 'عبقرية مطلقة (Coup)! النزول بـ Q ♠ يضع P2 في كماشة؛ إن لعب K أكله آصك وضمنت Q أو الآص، ثم الآص يأكل اللمة الثانية.',
          ),
          PuzzleOption(
            id: 'sp3_opt_3',
            label: 'النزول بـ 4 هارت ♥ والتخلي عن قيادة اللمة',
            quality: PuzzleResultQuality.weak,
            cardToPlay: PlayingCard(suit: Suit.heart, rank: Rank.four),
            feedback: 'يترك المبادرة للخصم وقد يسمح له بقطع ورقك أو التلاعب بالترتيب.',
          ),
        ],
        optimalOptionId: 'sp3_opt_2',
        acceptableOptionIds: const ['sp3_opt_2'],
        tacticalRationale:
            'في نهايات الجولات (End-play)، المبادرة بالكوين المحمية بالآص تجبر الكينج المعزول على السقوط وتضمن أكلتين مؤكدتين.',
      ),
    ];
  }

  /// Returns the deterministic Daily Puzzle for a given date
  static EstimationPuzzle getDailyPuzzleForDate(DateTime date) {
    final all = getAllPuzzles().where((p) => p.isDailyEligible).toList();
    if (all.isEmpty) return getAllPuzzles().first;

    // Use calendar day since epoch to deterministically rotate puzzles
    final dayIndex = date.difference(DateTime(2026, 1, 1)).inDays;
    final selectedIndex = dayIndex.abs() % all.length;
    return all[selectedIndex];
  }

  /// Formats date to 'YYYY-MM-DD'
  static String dateToKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
