// lib/core/data/academy_curriculum_data.dart

import 'package:flutter/material.dart';
import '../../models/academy_models.dart';
import '../constants.dart';
import '../models/card.dart';

class AcademyCurriculumData {
  static List<AcademyTopic> getCurriculum() {
    return [
      // ── Topic 1: Getting Started ───────────────────────────────────────────
      AcademyTopic(
        id: 'getting_started',
        title: 'البداية والأساسيات',
        subtitle: 'قواعد اللعبة، هيكل الـ 4 لاعبين وتوزيع الـ 13 ورقة',
        icon: '🎴',
        accentColor: const Color(0xFF10B981),
        lessons: [
          AcademyLesson(
            id: 'getting_started_1',
            topicId: 'getting_started',
            title: 'هيكل لعبة الإستميشن',
            subtitle: 'الأدوار، الموزع، وتوزيع الورق',
            difficulty: AcademyDifficulty.beginner,
            estimatedDuration: '٢ دقيقة',
            concepts: [
              'تلعب الإستميشن بـ ٤ لاعبين، وكل لاعب يحصل على ١٣ ورقة من الـ ٥٢ ورقة الكاملة.',
              'تنقسم اللعبة في كل دور إلى: فحص الفويد (Void Check) -> الداش كول المسبق -> المزاد (Auction) -> إعلان الكول (Declaration) -> اللعب (Trick Play) -> حساب النقاط.',
              'البولة الرسمية تتكون من ١٨ جولة كاملة.',
            ],
            theoryExplanation:
                'الهدف الأساسي في الإستميشن ليس تجميع أكبر عدد من الأكلات، بل التنبؤ الدقيق (Estimation) بعدد الأكلات التي ستفوز بها وتنفيذ التوقع بالضبط دون زيادة أو نقصان.',
            proTip:
                'إذا حققت أكلات أكثر أو أقل من رقمك المعلن، ستخسر نقاطاً! الدقة هي سر الفوز.',
            scenario: AcademyScenario(
              id: 'scenario_gs_1',
              type: AcademyScenarioType.scoreDecision,
              hand: [
                const PlayingCard(suit: Suit.spade, rank: Rank.ace),
                const PlayingCard(suit: Suit.spade, rank: Rank.king),
                const PlayingCard(suit: Suit.heart, rank: Rank.ace),
                const PlayingCard(suit: Suit.heart, rank: Rank.queen),
                const PlayingCard(suit: Suit.diamond, rank: Rank.jack),
                const PlayingCard(suit: Suit.diamond, rank: Rank.ten),
                const PlayingCard(suit: Suit.diamond, rank: Rank.two),
                const PlayingCard(suit: Suit.club, rank: Rank.king),
                const PlayingCard(suit: Suit.club, rank: Rank.nine),
                const PlayingCard(suit: Suit.club, rank: Rank.six),
                const PlayingCard(suit: Suit.club, rank: Rank.five),
                const PlayingCard(suit: Suit.club, rank: Rank.four),
                const PlayingCard(suit: Suit.club, rank: Rank.three),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 1,
                playerPosition: 'اللاعب الأول بعد الموزع',
              ),
              prompt: 'ما هو المبدأ الذهبي لتحقيق الفوز في لعبة الإستميشن؟',
              options: [
                const AcademyScenarioOption(
                  id: 'gs_opt_1',
                  label: 'الفوز بأكبر عدد ممكن من الأكلات في كل دور',
                  quality: AnswerQuality.invalid,
                  feedback: 'خطأ! الفوز بأكلات زيادة عن المطلوب يجعلك تخسر نقاط الدور بالكامل (Overtrick penalty).',
                ),
                const AcademyScenarioOption(
                  id: 'gs_opt_2',
                  label: 'تحقيق الرقم المعلن (Call) بالتمام والكمال',
                  quality: AnswerQuality.optimal,
                  feedback: 'أحسنت! الفوز بالإستميشن يعتمد على الدقة المطلقة في تحقيق رقمك.',
                ),
                const AcademyScenarioOption(
                  id: 'gs_opt_3',
                  label: 'منع باقي اللاعبين من تحقيق أكلاتهم فقط',
                  quality: AnswerQuality.risky,
                  feedback: 'التخريب على الخصوم مفيد أحياناً ولكن أولويتك القصوى هي ضمان رقمك أنت أولاً.',
                ),
              ],
              optimalOptionId: 'gs_opt_2',
              tacticalRationale: 'في الإستميشن، الدقة التامة هي المعيار الوحيد للحصول على النقاط الإيجابية.',
            ),
          ),
          AcademyLesson(
            id: 'getting_started_2',
            topicId: 'getting_started',
            title: 'ترتيب قوة الورق والألوان',
            subtitle: 'ترتيب الرانك وقوة القطوع (Trump)',
            difficulty: AcademyDifficulty.beginner,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'ترتيب قوة الورق داخل كل لون: A (الآس) هو الأقوى، يليه K، Q، J، 10، وصولاً لـ 2.',
              'ترتيب ألوان المزاد: السانز (بدون أتوت) > السبيد ♠ > الهارت ♥ > الكارو ♦ > التريفل ♣.',
              'أي ورقة أتوت تتغلب على أعلى ورقة من اللون الأصلي للملعبة.',
            ],
            theoryExplanation:
                'الآس دائماً هو الأقوى، ولكن إذا لعب خصمك ورقة من لون القطوع (Trump) بعد نفاذ اللون الأصلي من يده، فإن ورقته تكسب اللمة فوراً ما لم يلعب لاعب آخر ورقة أتوت أعلى منها.',
            proTip:
                'احفظ ترتيب ألوان المزاد جيداً: ♠ ثم ♥ ثم ♦ ثم ♣ (سبيد، هارت، كارو، تريفل).',
            scenario: AcademyScenario(
              id: 'scenario_gs_2',
              type: AcademyScenarioType.playCard,
              hand: [
                const PlayingCard(suit: Suit.heart, rank: Rank.king),
                const PlayingCard(suit: Suit.diamond, rank: Rank.seven),
                const PlayingCard(suit: Suit.spade, rank: Rank.two),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 3,
                trump: Trump.spade,
                playerPosition: 'اللاعب الرابع (الأخير)',
                currentTrickCards: [
                  TrickCard(
                    playerId: 'p1',
                    card: PlayingCard(suit: Suit.heart, rank: Rank.ace),
                  ),
                  TrickCard(
                    playerId: 'p2',
                    card: PlayingCard(suit: Suit.heart, rank: Rank.queen),
                  ),
                  TrickCard(
                    playerId: 'p3',
                    card: PlayingCard(suit: Suit.heart, rank: Rank.jack),
                  ),
                ],
              ),
              prompt: 'اللون الملعوب هو هارت ♥ واللاعب الأول نزل بآس الهارت A♥. القطوع هو سبيد ♠. معك K♥ في يدك. ما الذي يفرضه قانون اللعبة؟',
              options: [
                const AcademyScenarioOption(
                  id: 'gs2_opt_1',
                  label: 'النزول بـ 2♠ (أتوت) لكسب اللمة فوراً',
                  quality: AnswerQuality.invalid,
                  feedback: 'ممنوع! قانون اللعبة يلزمك بخدمة اللون الملعوب (هارت ♥) ما دمت تملك ورقة هارت في يدك.',
                ),
                const AcademyScenarioOption(
                  id: 'gs2_opt_2',
                  label: 'النزول بـ K♥ التزاماً بقانون خدمة اللون',
                  quality: AnswerQuality.optimal,
                  feedback: 'صحيح تماماً! خدمة اللون الملعوب إجبارية إذا كنت تملك منه ورقاً في يدك.',
                ),
              ],
              optimalOptionId: 'gs2_opt_2',
              tacticalRationale: 'قاعدة خدمة اللون (Following Suit) قاعدة قطعية: لا يجوز اللعب من لون آخر أو قطع بأتوت إلا إذا نفذ اللون الملعوب من يدك تماماً.',
            ),
          ),
        ],
      ),

      // ── Topic 2: Reading Your Hand ─────────────────────────────────────────
      AcademyTopic(
        id: 'reading_hand',
        title: 'قراءة الورق واليد',
        subtitle: 'حساب الأكلات المضمونة وقوة الورق الجانبي والتحكم',
        icon: '👁️',
        accentColor: const Color(0xFF3B82F6),
        lessons: [
          AcademyLesson(
            id: 'reading_hand_1',
            topicId: 'reading_hand',
            title: 'حساب الأكلات المؤكدة والمحتملة',
            subtitle: 'فصل الآسات المضمونة عن الصور المشروطة',
            difficulty: AcademyDifficulty.beginner,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'الآس المنفرد أو المحمي أكلة شبه مؤكدة في الأدوار الأولى.',
              'الشايب (King) يحتاج ورقة أو ورقتين حماية قبله (A أو صغار) لكي يكسب أكلة.',
              'البنت (Queen) تتطلب حمايتين على الأقل لتصبح أكلة محتملة.',
              'الورق الطويل (٥ كروت من نفس اللون) يمنحك أكلات إضافية بعد نفاذ اللون من أيدي الخصوم.',
            ],
            theoryExplanation:
                'عند قراءة يدك، قسم أكلاتك إلى: أكلات مؤكدة (Definite Winners) مثل A و A-K، وأكلات مشروطة (Conditional) مثل K-Q أو Q-J-10، وأكلات طول (Length Tricks).',
            proTip:
                'لا تحسب الشايب (K) كأكلة مضمونة إذا لم يكن معك الآس (A) من نفس اللون أو حماية كافية.',
            scenario: AcademyScenario(
              id: 'scenario_rh_1',
              type: AcademyScenarioType.declaration,
              hand: [
                const PlayingCard(suit: Suit.spade, rank: Rank.ace),
                const PlayingCard(suit: Suit.spade, rank: Rank.king),
                const PlayingCard(suit: Suit.spade, rank: Rank.queen),
                const PlayingCard(suit: Suit.spade, rank: Rank.jack),
                const PlayingCard(suit: Suit.heart, rank: Rank.ace),
                const PlayingCard(suit: Suit.heart, rank: Rank.two),
                const PlayingCard(suit: Suit.diamond, rank: Rank.king),
                const PlayingCard(suit: Suit.diamond, rank: Rank.nine),
                const PlayingCard(suit: Suit.diamond, rank: Rank.four),
                const PlayingCard(suit: Suit.club, rank: Rank.ten),
                const PlayingCard(suit: Suit.club, rank: Rank.seven),
                const PlayingCard(suit: Suit.club, rank: Rank.five),
                const PlayingCard(suit: Suit.club, rank: Rank.two),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 2,
                trump: Trump.spade,
                playerPosition: 'المزايد الفائز بالمزاد (The Bidder)',
                highBidInfo: 'أنت فزت بالمزاد بـ 6 سبيد ♠',
              ),
              prompt: 'يدك تحتوي على 4 كروت أتوت قوية (A-K-Q-J♠)، مع A♥ و K♦ محمي. كم أكلة مضمونة ومريحة في هذه اليد؟',
              options: [
                const AcademyScenarioOption(
                  id: 'rh1_opt_1',
                  label: 'طلب 4 أكلات فقط',
                  quality: AnswerQuality.risky,
                  feedback: 'قليل جداً! يدك قوية جداً وستأكل غصباً عنك أكلات إضافية وتخسر الدور.',
                ),
                const AcademyScenarioOption(
                  id: 'rh1_opt_2',
                  label: 'طلب 6 أكلات (مطابقة للمزاد)',
                  quality: AnswerQuality.optimal,
                  feedback: 'ممتاز! 4 أكلات سبيد + 1 هارت مؤكدة + 1 كارو محتملة = 6 أكلات متوازنة.',
                ),
                const AcademyScenarioOption(
                  id: 'rh1_opt_3',
                  label: 'طلب 9 أكلات',
                  quality: AnswerQuality.invalid,
                  feedback: 'مبالغة خطيرة جداً، ليس لديك ورق طويل كافي في التريفل أو الكارو لتحقيق 9.',
                ),
              ],
              optimalOptionId: 'rh1_opt_2',
              tacticalRationale: 'اليد تضمن 4 أكلات سبيد و 1 هارت، ومع K♦ المحمي وفرص القص، 6 أكلات هو التقدير النموذجي.',
              expectedTricksMin: 6,
              expectedTricksMax: 6,
            ),
          ),
        ],
      ),

      // ── Topic 3: Bidding ───────────────────────────────────────────────────
      AcademyTopic(
        id: 'bidding',
        title: 'المزايدة والمزاد',
        subtitle: 'قواعد المزاد، الحد الأدنى (4)، والأولويات والتنافس',
        icon: '⚖️',
        accentColor: const Color(0xFFF59E0B),
        lessons: [
          AcademyLesson(
            id: 'bidding_1',
            topicId: 'bidding',
            title: 'أساسيات المزاد وتحديد القطوع',
            subtitle: 'شروط المزايدة وكيفية التغلب على المزايدة السابقة',
            difficulty: AcademyDifficulty.beginner,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'يبدأ المزاد من ٤ أكلات كحد أدنى (Min Bid = 4).',
              'لكي تزايد، يجب أن تقدم عدداً أكبر من الأكلات، أو نفس العدد بلون أعلى في الأسبقية (سانز > سبيد > هارت > كارو > تريفل).',
              'الفائز بالمزاد يحدد لون القطوع للدور ويحصل على بونص +10 نقاط إذا حقق كوله.',
            ],
            theoryExplanation:
                'المزاد يمنحك حق اختيار لون القطوع الذي يناسب أقوى ألوان يدك. لكن تذكر أن الفائز بالمزاد ملزم بطلب عدد أكلات لا يقل عن رقم مزايدته أثناء مرحلة الإعلان (Declaration).',
            proTip:
                'لا تزايد إلا إذا كان لديك على الأقل ٤ أو ٥ كروت من لون القطوع مدعومة بآسات خارجية.',
            scenario: AcademyScenario(
              id: 'scenario_bid_1',
              type: AcademyScenarioType.bid,
              hand: [
                const PlayingCard(suit: Suit.heart, rank: Rank.ace),
                const PlayingCard(suit: Suit.heart, rank: Rank.king),
                const PlayingCard(suit: Suit.heart, rank: Rank.queen),
                const PlayingCard(suit: Suit.heart, rank: Rank.nine),
                const PlayingCard(suit: Suit.heart, rank: Rank.four),
                const PlayingCard(suit: Suit.spade, rank: Rank.king),
                const PlayingCard(suit: Suit.spade, rank: Rank.seven),
                const PlayingCard(suit: Suit.diamond, rank: Rank.ace),
                const PlayingCard(suit: Suit.diamond, rank: Rank.six),
                const PlayingCard(suit: Suit.club, rank: Rank.jack),
                const PlayingCard(suit: Suit.club, rank: Rank.eight),
                const PlayingCard(suit: Suit.club, rank: Rank.three),
                const PlayingCard(suit: Suit.club, rank: Rank.two),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 4,
                highBidInfo: 'أعلى مزايدة حالية: 4 كارو ♦',
                playerPosition: 'اللاعب الثاني',
              ),
              prompt: 'أعلى مزايدة على الطاولة هي 4 كارو ♦. معك 5 كروت هارت قوية (A-K-Q-9-4♥) مع A♦ و K♠. ما هي المزايدة القانونية الأفضل؟',
              options: [
                const AcademyScenarioOption(
                  id: 'bid1_opt_1',
                  label: '4 هارت ♥ (تتفوق بالأسبقية)',
                  quality: AnswerQuality.optimal,
                  feedback: 'ممتاز! الهارت أعلى أسبقية من الكارو بنفس الرقم (4)، وهي كافية لأخذ المزاد بأمان.',
                ),
                const AcademyScenarioOption(
                  id: 'bid1_opt_2',
                  label: '4 تريفل ♣',
                  quality: AnswerQuality.invalid,
                  feedback: 'غير قانوني! التريفل أقل أسبقية من الكارو، لا يمكنك المزايدة بـ 4 تريفل فوق 4 كارو.',
                ),
                const AcademyScenarioOption(
                  id: 'bid1_opt_3',
                  label: 'باص (PASS)',
                  quality: AnswerQuality.risky,
                  feedback: 'يدك ممتازة جداً (تتحمل 5-6 أكلات)، تمرير المزاد يفوت عليك فرصة اختيار الهارت كأتوت.',
                ),
              ],
              optimalOptionId: 'bid1_opt_1',
              tacticalRationale: '4 هارت مزايدة قانونية تكسر 4 كارو بفضل أسبقية الهارت، دون رفع سقف الالتزام بلا داع.',
              expectedTricksMin: 5,
              expectedTricksMax: 6,
            ),
          ),
        ],
      ),

      // ── Topic 4: Declaration ───────────────────────────────────────────────
      AcademyTopic(
        id: 'declaration',
        title: 'إعلان الرقم المطلوب (الكول)',
        subtitle: 'حساب هامش الأمان، الالتزام بالأرقام، وقراءة طاولة الكول',
        icon: '🎯',
        accentColor: const Color(0xFFEC4899),
        lessons: [
          AcademyLesson(
            id: 'declaration_1',
            topicId: 'declaration',
            title: 'حساب كول دقيق وهامش الأمان',
            subtitle: 'الموازنة بين أكلاتك وقوة أيدي الخصوم',
            difficulty: AcademyDifficulty.intermediate,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'في مرحلة الإعلان (Declaration)، يطلب كل لاعب رقماً يلتزم بتحقيقه بدقة.',
              'الفائز بالمزاد (The Bidder) لا يمكنه طلب رقم أقل من مزايدته التي فاز بها.',
              'احسب دائماً "أكلات الشك": إذا كان لديك كارت شايب وحيد غير محمي، لا تفترض أنه أكلة بنسبة 100%.',
            ],
            theoryExplanation:
                'الإعلان هو أهم قرار تكتيكي في الإستميشن. أي خطأ في زيادة أو نقصان الأكلات سيكلفك خسارة الدور. خذ في الحسبان موقعك في اللعب: إذا كنت تلعب بعد المزايد مباشرة فالضغط عليك أكبر.',
            proTip:
                'إذا ترددت بين رقمين (مثلاً 2 أو 3)، راجع عدد كروت القطوع في يدك وسهولة تسليم الليد للخصوم.',
            scenario: AcademyScenario(
              id: 'scenario_dec_1',
              type: AcademyScenarioType.declaration,
              hand: [
                const PlayingCard(suit: Suit.heart, rank: Rank.ace),
                const PlayingCard(suit: Suit.heart, rank: Rank.king),
                const PlayingCard(suit: Suit.heart, rank: Rank.five),
                const PlayingCard(suit: Suit.spade, rank: Rank.jack),
                const PlayingCard(suit: Suit.spade, rank: Rank.ten),
                const PlayingCard(suit: Suit.spade, rank: Rank.two),
                const PlayingCard(suit: Suit.diamond, rank: Rank.queen),
                const PlayingCard(suit: Suit.diamond, rank: Rank.four),
                const PlayingCard(suit: Suit.club, rank: Rank.eight),
                const PlayingCard(suit: Suit.club, rank: Rank.six),
                const PlayingCard(suit: Suit.club, rank: Rank.four),
                const PlayingCard(suit: Suit.club, rank: Rank.three),
                const PlayingCard(suit: Suit.club, rank: Rank.two),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 6,
                trump: Trump.heart,
                highBidInfo: 'المزايد فاز بـ 5 هارت ♥',
                otherBidsInfo: 'المزايد طلب 5، اللاعب الثاني طلب 3',
                playerPosition: 'اللاعب الثالث',
              ),
              prompt: 'القطوع هارت ♥ والمزايد طلب 5. معك A-K♥ و Q♦ وبنت وولد سبيد مع 5 كروت تريفل صغيرة. ما هو إعلانك الأنسب؟',
              options: [
                const AcademyScenarioOption(
                  id: 'dec1_opt_1',
                  label: 'طلب 2 أكلة',
                  quality: AnswerQuality.optimal,
                  feedback: 'دقيق ومتقن! A♥ و K♥ أكلتان مضمونتان، والورق الصغير يسمح لك بالتخلص بسهولة دون أكل إضافي.',
                ),
                const AcademyScenarioOption(
                  id: 'dec1_opt_2',
                  label: 'طلب 4 أكلات',
                  quality: AnswerQuality.risky,
                  feedback: 'مخاطرة شديدة! ليس لديك أي آس في الكارو أو السبيد، والتريفل كله ورق صغير ميت.',
                ),
                const AcademyScenarioOption(
                  id: 'dec1_opt_3',
                  label: 'طلب 0 (داش في مرحلة الكول)',
                  quality: AnswerQuality.invalid,
                  feedback: 'مستحيل! A-K في لون القطوع ستكسب بها أكلات إجبارياً أثناء سحب القطوع.',
                ),
              ],
              optimalOptionId: 'dec1_opt_1',
              tacticalRationale: 'A-K في القطوع أكلتان مضمونتان، والتحكم بالورق الصغير ممتاز لتفادي أكلات زائدة.',
              expectedTricksMin: 2,
              expectedTricksMax: 2,
            ),
          ),
        ],
      ),

      // ── Topic 5: Trump Strategy ────────────────────────────────────────────
      AcademyTopic(
        id: 'trump_strategy',
        title: 'استراتيجية القطوع وقص الورق',
        subtitle: 'سحب القطوع (Drawing Trumps)، قص ألوان الخصوم، والتحكم بالإيقاع',
        icon: '🛡️',
        accentColor: const Color(0xFF6366F1),
        lessons: [
          AcademyLesson(
            id: 'trump_strategy_1',
            topicId: 'trump_strategy',
            title: 'سحب القطوع وحماية الأكلات الخارجية',
            subtitle: 'متى تسحب أتوت الخصوم ومتى تحتفظ به للقص',
            difficulty: AcademyDifficulty.intermediate,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'إذا كنت المزايد ولديك ورق فائز خارجي (Side Suit Winners)، اسحب أتوت الخصوم فوراً لمنعهم من قصه بورقهم الصغير.',
              'إذا كان لديك نقص في لون معين (Short Suit / Void)، يمكنك استغلال القطوع الصغير لقص ولم أكلات الخصوم.',
              'احتساب عدد كروت القطوع الملعوبة يساعدك على معرفة متى أصبحت يدك تملك السيطرة الكاملة.',
            ],
            theoryExplanation:
                'الخطأ الشائع لدى المبتدئين هو الاحتفاظ بالقطوع واللعب بالآسات الجانبية، مما يسمح للخصوم بقص آساتك بأتوت صغير. المزايد المحترف يبادر بسحب القطوع أولاً.',
            proTip:
                'اسحب القطوع حتى تفرغ أيدي الخصوم منه، ثم انزل بآساتك وباقي أكلاتك بأمان تام.',
            scenario: AcademyScenario(
              id: 'scenario_ts_1',
              type: AcademyScenarioType.playCard,
              hand: [
                const PlayingCard(suit: Suit.spade, rank: Rank.ace),
                const PlayingCard(suit: Suit.spade, rank: Rank.king),
                const PlayingCard(suit: Suit.spade, rank: Rank.queen),
                const PlayingCard(suit: Suit.heart, rank: Rank.ace),
                const PlayingCard(suit: Suit.heart, rank: Rank.king),
                const PlayingCard(suit: Suit.diamond, rank: Rank.ace),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 7,
                trump: Trump.spade,
                highBidInfo: 'أنت المزايد (طلبت 6 سبيد ♠)',
                playerPosition: 'أنت تملك الليد (دورك في اللعب أولاً)',
              ),
              prompt: 'أنت المزايد ولديك 3 كروت سبيد كبيرة (A-K-Q♠) مع A-K♥ و A♦. الليد معك في أول أكلة. ما هي الضربة الافتتاحية الصحيحة؟',
              options: [
                const AcademyScenarioOption(
                  id: 'ts1_opt_1',
                  label: 'اللعب بـ A♠ لسحب أتوت الخصوم',
                  quality: AnswerQuality.optimal,
                  feedback: 'تكتيك محترف! سحب القطوع من الخصوم يحمي آسات الهارت والكارو من القص.',
                ),
                const AcademyScenarioOption(
                  id: 'ts1_opt_2',
                  label: 'اللعب بـ A♦ مباشرة',
                  quality: AnswerQuality.risky,
                  feedback: 'خطر! إذا كان أحد الخصوم لا يملك كارو (Void)، سيقص آس الكارو بأتوت صغير وتخسر أكلتك.',
                ),
              ],
              optimalOptionId: 'ts1_opt_1',
              tacticalRationale: 'سحب القطوع بالآس يطهر أيدي الخصوم من القطوع ويضمن مرور الآسات الخارجية بأمان.',
            ),
          ),
        ],
      ),

      // ── Topic 6: Sans Strategy ─────────────────────────────────────────────
      AcademyTopic(
        id: 'sans_strategy',
        title: 'استراتيجية الصانز (No Trump)',
        subtitle: 'قواعد اللعب بدون أتوت، استغلال الورق الطويل، وتأمين السدادات (Stoppers)',
        icon: '👑',
        accentColor: const Color(0xFFFBBF24),
        lessons: [
          AcademyLesson(
            id: 'sans_strategy_1',
            topicId: 'sans_strategy',
            title: 'قوة السدادات والورق الطويل في الصانز',
            subtitle: 'كيف تكسب في غياب القطوع وقص الورق',
            difficulty: AcademyDifficulty.advanced,
            estimatedDuration: '٤ دقائق',
            concepts: [
              'في الصانز (Sans)، لا يوجد أي لون أتوت، مما يعني أن الورقة الأعلى من نفس اللون الملعوب هي التي تفوز دائماً.',
              'السدادة (Stopper) هي وجود A أو K محمي يمنع الخصوم من سحب كل كروت ذلك اللون.',
              'اللون الطويل (٥ أو ٦ كروت) يتحول لخط إنتاج أكلات بمجرد نفاد الآسات العالية.',
            ],
            theoryExplanation:
                'الصانز يتطلب توزيعاً متزناً وسدادات في أغلب الألوان. الفائز بالمزاد في الصانز يعتمد على بناء اللون الطويل (Establishment) مع الاحتفاظ بآسات الألوان الأخرى كمدخل (Entry) للوصول للونه الطويل.',
            proTip:
                'في الصانز، احرص على عدم تفريغ ألوانك القوية مبكراً إذا لم تكن تملك مدخلاً للعودة إليها.',
            scenario: AcademyScenario(
              id: 'scenario_sans_1',
              type: AcademyScenarioType.bid,
              hand: [
                const PlayingCard(suit: Suit.spade, rank: Rank.ace),
                const PlayingCard(suit: Suit.spade, rank: Rank.king),
                const PlayingCard(suit: Suit.spade, rank: Rank.queen),
                const PlayingCard(suit: Suit.spade, rank: Rank.jack),
                const PlayingCard(suit: Suit.spade, rank: Rank.nine),
                const PlayingCard(suit: Suit.heart, rank: Rank.ace),
                const PlayingCard(suit: Suit.heart, rank: Rank.king),
                const PlayingCard(suit: Suit.diamond, rank: Rank.ace),
                const PlayingCard(suit: Suit.diamond, rank: Rank.seven),
                const PlayingCard(suit: Suit.club, rank: Rank.king),
                const PlayingCard(suit: Suit.club, rank: Rank.queen),
                const PlayingCard(suit: Suit.club, rank: Rank.ten),
                const PlayingCard(suit: Suit.club, rank: Rank.four),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 8,
                highBidInfo: 'أعلى مزايدة حالية: 6 سبيد ♠',
                playerPosition: 'الموزع (Dealer)',
              ),
              prompt: 'يدك تحتوي على سدادات في كل الألوان (A-K-Q-J-9♠، A-K♥، A♦، K-Q-10-4♣). أعلى مزايدة هي 6 سبيد ♠. ما هي المزايدة الحاسمة؟',
              options: [
                const AcademyScenarioOption(
                  id: 'sans1_opt_1',
                  label: '6 صانز (Sans / No Trump)',
                  quality: AnswerQuality.optimal,
                  feedback: 'عبقري! الصانز يعلو على 6 سبيد بنفس الرقم ولديك سدادات حديدية في جميع الألوان مع 5 سبيد.',
                ),
                const AcademyScenarioOption(
                  id: 'sans1_opt_2',
                  label: '7 سبيد ♠',
                  quality: AnswerQuality.strong,
                  feedback: 'قوي ولكن المزايدة بـ 6 صانز أضمن وتكسر 6 سبيد بدون رفع عدد الأكلات إلى 7.',
                ),
                const AcademyScenarioOption(
                  id: 'sans1_opt_3',
                  label: 'باص (PASS)',
                  quality: AnswerQuality.invalid,
                  feedback: 'يدك أسطورية نادرة، تفويت المزاد هنا خطأ استراتيجي فادح.',
                ),
              ],
              optimalOptionId: 'sans1_opt_1',
              tacticalRationale: '6 صانز تفوز بالمزاد بفضل أسبقية الصانز القصوى، واليد متكاملة بسدادات في كل الألوان.',
              expectedTricksMin: 7,
              expectedTricksMax: 8,
            ),
          ),
        ],
      ),

      // ── Topic 7: Dash Call ─────────────────────────────────────────────────
      AcademyTopic(
        id: 'dash_call',
        title: 'الداش كول والتصريح الجريء',
        subtitle: 'قواعد الداش (طلب 0 أكلات)، التخلص من الورق الخطر، واستغلال الفويد',
        icon: '⚡',
        accentColor: const Color(0xFF06B6D4),
        lessons: [
          AcademyLesson(
            id: 'dash_call_1',
            topicId: 'dash_call',
            title: 'شروط اليد المثالية للداش كول',
            subtitle: 'متى تقرر طلب 0 أكلات وتكسب بونص الداش',
            difficulty: AcademyDifficulty.intermediate,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'الداش كول (Dash Call) هو إعلان اللاعب عن تحقيق صفر (0) أكلات في الدور بالكامل.',
              'في الداش الناجح، يحصل اللاعب على نقاط مضاعفة (+33 في العادي أو +66 في الدبل).',
              'شروط الداش الآمن: خلو اليد من الآسات، وجود ورق صغير كثير (2، 3، 4، 5)، وعدم وجود شوايب (Kings) منفردة دون حماية.',
            ],
            theoryExplanation:
                'الداش كول مغامرة تكتيكية ذات عائد هائل. الخطر الأكبر يأتي من "الشوايب أو البنات العارية" (مثل K وحيد)، لأن الخصوم عندما يلعبون صغار ذلك اللون ستضطر لأكل اللمة بالشايب وتخسر الداش.',
            proTip:
                'إذا كان معك شايب وحيد أو محمي بورقة واحدة فقط، لا تطلب داش إلا إذا كان معك فويد في ألوان أخرى يتيح لك التخلص منه.',
            scenario: AcademyScenario(
              id: 'scenario_dc_1',
              type: AcademyScenarioType.dashCall,
              hand: [
                const PlayingCard(suit: Suit.spade, rank: Rank.six),
                const PlayingCard(suit: Suit.spade, rank: Rank.four),
                const PlayingCard(suit: Suit.spade, rank: Rank.two),
                const PlayingCard(suit: Suit.heart, rank: Rank.eight),
                const PlayingCard(suit: Suit.heart, rank: Rank.five),
                const PlayingCard(suit: Suit.heart, rank: Rank.three),
                const PlayingCard(suit: Suit.diamond, rank: Rank.seven),
                const PlayingCard(suit: Suit.diamond, rank: Rank.four),
                const PlayingCard(suit: Suit.diamond, rank: Rank.two),
                const PlayingCard(suit: Suit.club, rank: Rank.nine),
                const PlayingCard(suit: Suit.club, rank: Rank.five),
                const PlayingCard(suit: Suit.club, rank: Rank.three),
                const PlayingCard(suit: Suit.club, rank: Rank.two),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 9,
                playerPosition: 'اللاعب الأول في مرحلة الداش كول المسبق',
              ),
              prompt: 'يدك تحتوي على كروت صغيرة فقط (أعلى كارت 9♣ و 8♥) وبدون أي آسات أو صور (No Aces, No Kings, No Queens). هل تطلب داش كول؟',
              options: [
                const AcademyScenarioOption(
                  id: 'dc1_opt_1',
                  label: 'نعم! طلب داش كول بثقة (Dash Call)',
                  quality: AnswerQuality.optimal,
                  feedback: 'قرار ممتاز! هذه يد داش كلاسيكية مثالية خالية تماماً من الكروت الخطرة.',
                ),
                const AcademyScenarioOption(
                  id: 'dc1_opt_2',
                  label: 'لا، تمرير (Pass) واللعب برقم عادي',
                  quality: AnswerQuality.risky,
                  feedback: 'تفويت لبونص الداش السهل! يدك مستحيل أن تأكل أي أكلة إلا إذا أجبرك الحظ النادر.',
                ),
              ],
              optimalOptionId: 'dc1_opt_1',
              tacticalRationale: 'اليد لا تحتوي على أي كارت أعلى من 9، وموزعة بالتساوي بورق صغير جداً في كل الألوان، مما يجعل الداش آمناً للغاية.',
              expectedTricksMin: 0,
              expectedTricksMax: 0,
            ),
          ),
        ],
      ),

      // ── Topic 8: Risk ──────────────────────────────────────────────────────
      AcademyTopic(
        id: 'risk',
        title: 'المخاطرة وطلب الريسك',
        subtitle: 'قواعد مضاعفة النقاط بالريسك، تقييم الجدوى واللحظة المناسبة',
        icon: '🎲',
        accentColor: const Color(0xFFEF4444),
        lessons: [
          AcademyLesson(
            id: 'risk_1',
            topicId: 'risk',
            title: 'حساب جدوى الريسك ومتى تطلبه',
            subtitle: 'المكسب المضاعف مقابل العقوبة القاسية',
            difficulty: AcademyDifficulty.advanced,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'طلب الريسك (Risk) يضاعف نقاط الفوز إذا حققت رقمك بالضبط، لكنه يضاعف العقوبة السلبية إذا أخطأت.',
              'لا تطلب ريسك إذا كان رقمك يعتمد على حظ تخمين مكان الآس عند الخصوم.',
              'الريسك هو السلاح الأول للريمونتادا (Comeback) عندما تكون متأخراً في النتيجة في الجولات المتقدمة.',
            ],
            theoryExplanation:
                'الريسك سلاح ذو حدين. في الأدوار المبكرة، يُنصح باللعب المتحفظ وتجنب الريسك غير المضمون. لكن في الجولات الأخيرة (أدوار الفكسد دبل 14-18) ومع يد حديدية، يمكن للريسك أن يحسم البولة لصالحك.',
            proTip:
                'اطلب الريسك فقط عندما تكون متأكداً بنسبة 90%+ من التحكم في كل أكلة أو عندما تكون متأخراً وتلعب على كل شيء.',
            scenario: AcademyScenario(
              id: 'scenario_risk_1',
              type: AcademyScenarioType.risk,
              hand: [
                const PlayingCard(suit: Suit.spade, rank: Rank.ace),
                const PlayingCard(suit: Suit.spade, rank: Rank.king),
                const PlayingCard(suit: Suit.spade, rank: Rank.queen),
                const PlayingCard(suit: Suit.spade, rank: Rank.jack),
                const PlayingCard(suit: Suit.spade, rank: Rank.ten),
                const PlayingCard(suit: Suit.heart, rank: Rank.ace),
                const PlayingCard(suit: Suit.heart, rank: Rank.king),
                const PlayingCard(suit: Suit.diamond, rank: Rank.ace),
                const PlayingCard(suit: Suit.diamond, rank: Rank.king),
                const PlayingCard(suit: Suit.club, rank: Rank.ace),
                const PlayingCard(suit: Suit.club, rank: Rank.three),
                const PlayingCard(suit: Suit.club, rank: Rank.two),
                const PlayingCard(suit: Suit.heart, rank: Rank.two),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 15,
                trump: Trump.spade,
                highBidInfo: 'أنت المزايد بـ 8 سبيد ♠ في دور دبل',
                scoreSituation: 'أنت في المركز الثالث وبحاجة لقفزة نقاط',
              ),
              prompt: 'أنت المزايد بـ 8 سبيد في جولة متقدمة. يدك تحتوي على 5 سبيد كبيرة + 4 آسات في كل الألوان + شوايب محمية. هل تطلب ريسك (Risk)؟',
              options: [
                const AcademyScenarioOption(
                  id: 'risk1_opt_1',
                  label: 'نعم! طلب ريسك (Risk) لمضاعفة النقاط',
                  quality: AnswerQuality.optimal,
                  feedback: 'قرار بطل! يدك مغلقة تماماً (Locked Hand) والريسك سيمنحك قفزة هائلة نحو صدارة البولة.',
                ),
                const AcademyScenarioOption(
                  id: 'risk1_opt_2',
                  label: 'لا، اللعب بدون ريسك خوفاً من الخسارة',
                  quality: AnswerQuality.risky,
                  feedback: 'تحفظ زائد عن اللزوم! يدك تضمن 8-9 أكلات بسهولة، وتفويت الريسك هنا يضيع فرصة الفوز بالبولة.',
                ),
              ],
              optimalOptionId: 'risk1_opt_1',
              tacticalRationale: 'اليد تملك السيطرة المطلقة على القطوع وكل الألوان الجانبية، مما يجعل احتمالية الخطأ شبه منعدمة.',
              expectedTricksMin: 8,
              expectedTricksMax: 9,
            ),
          ),
        ],
      ),

      // ── Topic 9: Forbidden 13 ──────────────────────────────────────────────
      AcademyTopic(
        id: 'forbidden_13',
        title: 'قاعدة الـ 13 الممنوعة',
        subtitle: 'ورطة الموزع (Dealer)، منع مجموع 13، وتعديل الكول تكتيكياً',
        icon: '⛔',
        accentColor: const Color(0xFFDC2626),
        lessons: [
          AcademyLesson(
            id: 'forbidden_13_1',
            topicId: 'forbidden_13',
            title: 'فخ الـ 13 الممنوعة وكيفية النجاة منه',
            subtitle: 'عندما يُمنع الموزع من طلب الرقم الطبيعي ليده',
            difficulty: AcademyDifficulty.intermediate,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'قاعدة الـ 13 الممنوعة: لا يجوز أن يكون مجموع إعلانات اللاعبين الأربعة مساوياً لـ 13.',
              'آخر لاعب يعلن (وهو الموزع Dealer) يُمنع تلقائياً من اختيار الرقم الذي يكمل المجموع إلى 13.',
              'إذا كان رقمك الطبيعي هو الرقم الممنوع، يجب أن تختار بين المزايدة بـ +1 (Overcall) أو -1 (Undercall).',
            ],
            theoryExplanation:
                'الـ 13 الممنوعة تضمن دائماً أن هناك أكلات ناقصة (Under) أو أكلات زائدة (Over) في الدور، مما يجبر اللاعبين على الصراع التكتيكي. إذا أُجبرت كموزع على تغيير رقمك، اختر الاتجاه الذي تدعمه خريطة يدك: إذا كان لديك ورق فائز مشكوك فيه انزل -1، وإذا كان لديك ورق طويل قابل للبناء اصعد +1.',
            proTip:
                'احسب مجموع طلبات اللاعبين الثلاثة قبلك لتتوقع ما إذا كان رقمك سيُحظر قبل أن يصل الدور إليك.',
            scenario: AcademyScenario(
              id: 'scenario_f13_1',
              type: AcademyScenarioType.declaration,
              hand: [
                const PlayingCard(suit: Suit.diamond, rank: Rank.ace),
                const PlayingCard(suit: Suit.diamond, rank: Rank.king),
                const PlayingCard(suit: Suit.heart, rank: Rank.queen),
                const PlayingCard(suit: Suit.heart, rank: Rank.nine),
                const PlayingCard(suit: Suit.spade, rank: Rank.seven),
                const PlayingCard(suit: Suit.spade, rank: Rank.five),
                const PlayingCard(suit: Suit.spade, rank: Rank.two),
                const PlayingCard(suit: Suit.club, rank: Rank.jack),
                const PlayingCard(suit: Suit.club, rank: Rank.six),
                const PlayingCard(suit: Suit.club, rank: Rank.four),
                const PlayingCard(suit: Suit.club, rank: Rank.three),
                const PlayingCard(suit: Suit.club, rank: Rank.two),
                const PlayingCard(suit: Suit.diamond, rank: Rank.two),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 10,
                trump: Trump.diamond,
                highBidInfo: 'المزايد طلب 5 كارو ♦',
                otherBidsInfo: 'طلبات اللاعبين الثلاثة: 5، 3، 3 (المجموع الحالي = 11)',
                playerPosition: 'الموزع (آخر لاعب يعلن)',
              ),
              prompt: 'مجموع طلبات اللاعبين الثلاثة قبلك هو 11 (5+3+3). يدك تستحق 2 أكلة طبيعية (A-K♦). لكن الرقم 2 ممنوع لأن 11+2 = 13! ماذا تطلب؟',
              options: [
                const AcademyScenarioOption(
                  id: 'f13_opt_1',
                  label: 'طلب 1 (Undercall مع التخلص السريع من الليد)',
                  quality: AnswerQuality.optimal,
                  feedback: 'تكتيك ناضج! طلب 1 والحرص على نزول K♦ تحت آس الخصم أو تفادي أكل Q♥ أسهل بكثير من محاولة تصنيع 3 أكلات من يد ضعيفة.',
                ),
                const AcademyScenarioOption(
                  id: 'f13_opt_2',
                  label: 'طلب 3 (Overcall بمحاولة كسب أكلة ثالثة بالبنت)',
                  quality: AnswerQuality.risky,
                  feedback: 'مخاطرة عالية جداً، Q♥ غير محمية والتريفل والسبيد ضعيفان جداً.',
                ),
              ],
              optimalOptionId: 'f13_opt_1',
              tacticalRationale: 'النزول بـ 1 أكلة مع يد تحتوي على A-K محكومين أسهل تكتيكياً من اختراع أكلة إضافية غير موجودة.',
              expectedTricksMin: 1,
              expectedTricksMax: 2,
            ),
          ),
        ],
      ),

      // ── Topic 10: Trick Taking ─────────────────────────────────────────────
      AcademyTopic(
        id: 'trick_taking',
        title: 'إدارة اللمات والأكلات',
        subtitle: 'النزول تحت الفائز (Ducking)، التخلص من الورق الخطر، وتمرير الليد',
        icon: '🎴',
        accentColor: const Color(0xFF14B8A6),
        lessons: [
          AcademyLesson(
            id: 'trick_taking_1',
            topicId: 'trick_taking',
            title: 'تكتيك النزول تحت الفائز والتخلص من الورق الخطر',
            subtitle: 'كيف تتفادى أكل لمات غير مرغوب فيها',
            difficulty: AcademyDifficulty.intermediate,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'إذا حققت رقمك المعلن، يصبح هدفك تفادي كسب أي أكلة إضافية بأي ثمن.',
              'النزول تحت الفائز (Ducking): العب أصغر ورقة ممكنة تحت أعلى ورقة نزلت على الطاولة.',
              'التخلص (Discarding): عندما ينفذ منك اللون الملعوب، تخلص من الكروت العالية الخطرة في الألوان الأخرى (مثل K أو Q عارية).',
            ],
            theoryExplanation:
                'إتقان عدم الأكل (Anti-winning) فن لا يقل أهمية عن إتقان كسب الأكلات. عندما يلعب الخصم ورقة عالية، استغل الفرصة للتخلص من كروتك المتوسطة أو العالية التي قد تورطك لاحقاً.',
            proTip:
                'تخلص دائماً من الشوايب والبنات التي لا تملك معها ورقاً صغيراً لحمايتها في أول فرصة فويد.',
            scenario: AcademyScenario(
              id: 'scenario_tt_1',
              type: AcademyScenarioType.playCard,
              hand: [
                const PlayingCard(suit: Suit.spade, rank: Rank.king),
                const PlayingCard(suit: Suit.spade, rank: Rank.two),
                const PlayingCard(suit: Suit.heart, rank: Rank.three),
                const PlayingCard(suit: Suit.diamond, rank: Rank.four),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 11,
                trump: Trump.heart,
                playerPosition: 'اللاعب الثالث في اللمة',
                currentTrickCards: [
                  TrickCard(
                    playerId: 'p1',
                    card: PlayingCard(suit: Suit.spade, rank: Rank.ace),
                  ),
                  TrickCard(
                    playerId: 'p2',
                    card: PlayingCard(suit: Suit.spade, rank: Rank.ten),
                  ),
                ],
              ),
              prompt: 'حققت كولك بالكامل ولا تريد أي أكلة إضافية! اللاعب الأول نزل بـ A♠. في يدك K♠ و 2♠. أي ورقة تنزل بها؟',
              options: [
                const AcademyScenarioOption(
                  id: 'tt1_opt_1',
                  label: 'النزول بـ K♠ تحت الآس فوراً للتخلص منه',
                  quality: AnswerQuality.optimal,
                  feedback: 'حركة عبقرية! رمي الشايب تحت الآس يتخلص من كارت خطر كان سيأكل أكلة إجبارية لاحقاً.',
                ),
                const AcademyScenarioOption(
                  id: 'tt1_opt_2',
                  label: 'النزول بـ 2♠ والاحتفاظ بالشايب',
                  quality: AnswerQuality.risky,
                  feedback: 'خطأ قاتل! إذا احتفظت بالشايب، سيصبح أعلى ورقة متبقية في السبيد ويجبرك على أكل لمة قادمة وتخسر الدور.',
                ),
              ],
              optimalOptionId: 'tt1_opt_1',
              tacticalRationale: 'رمي الشايب تحت الآس ينقذك من تحوله لأعلى ورقة في الدور القادم.',
            ),
          ),
        ],
      ),

      // ── Topic 11: Score Management ─────────────────────────────────────────
      AcademyTopic(
        id: 'score_management',
        title: 'إدارة النقاط والترتيب',
        subtitle: 'استراتيجية البولة (18 دور)، ألقاب الكينج والكوز، وحماية الصدارة',
        icon: '🏆',
        accentColor: const Color(0xFFEAB308),
        lessons: [
          AcademyLesson(
            id: 'score_management_1',
            topicId: 'score_management',
            title: 'قراءة جدول النتائج وترتيب البولة',
            subtitle: 'الفارق بين الكينج 👑 والصب كينج 🥈 والصب كوز 🥉 والكوز 🤡',
            difficulty: AcademyDifficulty.intermediate,
            estimatedDuration: '٣ دقائق',
            concepts: [
              'البولة الكاملة 18 دوراً: الأدوار 1-13 أدوار فردية عادية، والأدوار 14-18 أدوار دبل (مضاعفة النقاط) بأتوت ثابت (Fixed Trump).',
              'في الأدوار الأخيرة، المتصدر يلعب بحذر لحماية فارق النقاط، بينما المتأخر يخاطر بالمزاد والريسك للريمونتادا.',
              'الفائز يحصل على لقب "كينج 👑"، بينما صاحب المركز الأخير يحصل على لقب "كوز 🤡".',
            ],
            theoryExplanation:
                'إدارة النتيجة تتطلب معرفة متى تهاجم ومتى تدافع. إذا كنت متصدراً بفارق 40 نقطة في الدور 16، لا داعي للدخول في مزادات انتحارية. التزم باللعب الدفاعي والتركيز على تحقيق رقمك.',
            proTip:
                'في أدوار الدبل (14-18)، النقاط تتضاعف، لذا يمكن تعويض فارق كبير في دورين فقط إذا أحسنت استغلال الداش أو المزاد.',
            scenario: AcademyScenario(
              id: 'scenario_sm_1',
              type: AcademyScenarioType.scoreDecision,
              hand: [
                const PlayingCard(suit: Suit.heart, rank: Rank.ace),
                const PlayingCard(suit: Suit.heart, rank: Rank.nine),
                const PlayingCard(suit: Suit.spade, rank: Rank.jack),
                const PlayingCard(suit: Suit.spade, rank: Rank.four),
                const PlayingCard(suit: Suit.diamond, rank: Rank.eight),
                const PlayingCard(suit: Suit.diamond, rank: Rank.three),
                const PlayingCard(suit: Suit.club, rank: Rank.seven),
                const PlayingCard(suit: Suit.club, rank: Rank.two),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 17,
                totalRounds: 18,
                scoreSituation: 'أنت متصدر بفارق +55 نقطة عن المركز الثاني، ونحن في الدور 17 (دبل)',
              ),
              prompt: 'أنت في صدارة البولة بفارق مريح جداً (+55 نقطة) في الدور قبل الأخير. يدك متوسطة (تستحق 1-2 أكلة). أحد الخصوم زايد بـ 6. ما هي الاستراتيجية الصحيحة؟',
              options: [
                const AcademyScenarioOption(
                  id: 'sm1_opt_1',
                  label: 'تمرير المزاد (Pass)، وطلب 1-2 بهدوء لحماية الفارق',
                  quality: AnswerQuality.optimal,
                  feedback: 'تفكير بطل واحترافي! لا داعي للمقامرة عندما تكون الصدارة في جيبك، ركز على حماية الفوز.',
                ),
                const AcademyScenarioOption(
                  id: 'sm1_opt_2',
                  label: 'المزايدة بـ 7 لمحاولة سحق الخصوم بضربة قاضية',
                  quality: AnswerQuality.invalid,
                  feedback: 'تهور غير مبرر! يدك ضعيفة والمزايدة بـ 7 قد تكلفك خسارة 70+ نقطة وضياع لقب الكينج في آخر لحظة.',
                ),
              ],
              optimalOptionId: 'sm1_opt_1',
              tacticalRationale: 'حماية الصدارة تتطلب تقليل التباين (Variance Reduction) وتجنب القرارات الانتحارية.',
            ),
          ),
        ],
      ),

      // ── Topic 12: Advanced Strategy ────────────────────────────────────────
      AcademyTopic(
        id: 'advanced_strategy',
        title: 'قراءة الخصوم والاستراتيجيات المتقدمة',
        subtitle: 'تتبع فويد الخصوم، قراءة إشارات الرمي (Signaling)، وإنهاءات الإندجيم',
        icon: '🧠',
        accentColor: const Color(0xFF8B5CF6),
        lessons: [
          AcademyLesson(
            id: 'advanced_strategy_1',
            topicId: 'advanced_strategy',
            title: 'تتبع الفويدات والتوقيع وتضييق الخناق',
            subtitle: 'كيف تقرأ ما تبقى في أيدي الخصوم من كروت ملعوبة',
            difficulty: AcademyDifficulty.expert,
            estimatedDuration: '٤ دقائق',
            concepts: [
              'عندما يرمي الخصم ورقة من غير اللون الملعوب، فإنه يعلن رسمياً خلو يده من ذلك اللون (Void). احفظ هذه المعلومة فوراً!',
              'إذا كان الخصم بحاجة لأكلة، سيلعب بلونه الطويل أو يقص بأتوت. وإذا كان يريد تفادي الأكل سيلعب كروته الصعبة.',
              'الإندجيم (آخر 3 كروت في الدور) يُحسم بالحساب الدقيق لمن يملك كارت الخروج (Exit Card).',
            ],
            theoryExplanation:
                'اللاعب المتقدم يلعب بعيون مفتوحة على الطاولة كلها. بمجرد أن يظهر فويد عند خصم، يمكنك إجباره على القص وتدمير كوله أو إجباره على أكل لمة غير مرغوبة عبر اللعب في لونه المنتهي.',
            proTip:
                'استخدم كارت الليد بذكاء: انزل في لون نفذ من زميلك ليقص، أو انزل في لون يملك فيه خصمك كارت عالي وحيد لتعطيله.',
            scenario: AcademyScenario(
              id: 'scenario_adv_1',
              type: AcademyScenarioType.playCard,
              hand: [
                const PlayingCard(suit: Suit.diamond, rank: Rank.two),
                const PlayingCard(suit: Suit.heart, rank: Rank.four),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 12,
                trump: Trump.spade,
                playerPosition: 'أنت تملك الليد في اللمة رقم 12 (باقي لمتان)',
                otherBidsInfo: 'الخصم الأيسر طلب 3 وحقق 3 بالضبط، والخصم الأيمن طلب 4 ومعه 3 أكلات وبحاجة لأكلة أخيرة',
              ),
              prompt: 'الخصم الأيسر حقق كوله (3 من 3) ولا يريد أي أكلة، وهو فويد في الكارو ♦! الخصم الأيمن يحتاج أكلة وما زال يملك أتوت ♠. الليد معك ومعك 2♦ و 4♥ (الأخير ليس فويد). ماذا تلعب؟',
              options: [
                const AcademyScenarioOption(
                  id: 'adv1_opt_1',
                  label: 'اللعب بـ 2♦ (كارو) فوراً',
                  quality: AnswerQuality.optimal,
                  feedback: 'ضربة معلم! رمي الكارو يجبر الأيسر على التخلص بأمان، ويمنح الأيمن فرصة القص بأتوته لتحقيق كوله أو توريط الآخرين.',
                ),
                const AcademyScenarioOption(
                  id: 'adv1_opt_2',
                  label: 'اللعب بـ 4♥',
                  quality: AnswerQuality.risky,
                  feedback: 'خيار غير مدروس، قد يورط اللاعبين الذين حققوا أرقامهم دون استغلال الفويد المعروف.',
                ),
              ],
              optimalOptionId: 'adv1_opt_1',
              tacticalRationale: 'استغلال فويد الكارو المعروف يمنحك السيطرة على مسار اللمة قبل الأخيرة.',
            ),
          ),
        ],
      ),

      // ── Topic 13: Master Challenges ────────────────────────────────────────
      AcademyTopic(
        id: 'master_challenges',
        title: 'تحديات الأستاذية (Mastery)',
        subtitle: 'سيناريوهات معقدة تجمع كل المهارات لاختبار جاهزيتك للبطولات',
        icon: '⚔️',
        accentColor: const Color(0xFFF43F5E),
        lessons: [
          AcademyLesson(
            id: 'master_challenge_1',
            topicId: 'master_challenges',
            title: 'تحدي اللحظة الحاسمة في الدور 18',
            subtitle: 'المزاد الحاسم، قراءة الورق، وحسم بولة الإستميشن',
            difficulty: AcademyDifficulty.master,
            estimatedDuration: '٥ دقائق',
            concepts: [
              'الدور 18 هو دور التريفل ♣ الثابت دبل.',
              'تغيير القطوع الثابت يتطلب المزايدة بـ 8 أكلات أو أكثر.',
              'القرار الصحيح في هذا الدور يحدد الفائز بالبولة الكاملة.',
            ],
            theoryExplanation:
                'في الدور الأخير، تتقاطع جميع قوانين الإستميشن: القطوع الثابت، مضاعفة الدبل، فخ الـ 13 الممنوعة، وإدارة فارق النقاط. هذا التحدي يختبر قدرتك على اتخاذ القرار الاستراتيجي المثالي تحت أقصى درجات الضغط.',
            proTip:
                'احسب كل سيناريو ممكن قبل تثبيت مزايدتك: المزايدة بـ 8 تغير القطوع لكنها تضع عليك مسؤولية تحقيق 8 أكلات دبل.',
            scenario: AcademyScenario(
              id: 'scenario_mc_1',
              type: AcademyScenarioType.bid,
              hand: [
                const PlayingCard(suit: Suit.spade, rank: Rank.ace),
                const PlayingCard(suit: Suit.spade, rank: Rank.king),
                const PlayingCard(suit: Suit.spade, rank: Rank.queen),
                const PlayingCard(suit: Suit.spade, rank: Rank.jack),
                const PlayingCard(suit: Suit.spade, rank: Rank.ten),
                const PlayingCard(suit: Suit.spade, rank: Rank.nine),
                const PlayingCard(suit: Suit.heart, rank: Rank.ace),
                const PlayingCard(suit: Suit.heart, rank: Rank.king),
                const PlayingCard(suit: Suit.diamond, rank: Rank.ace),
                const PlayingCard(suit: Suit.diamond, rank: Rank.king),
                const PlayingCard(suit: Suit.diamond, rank: Rank.queen),
                const PlayingCard(suit: Suit.club, rank: Rank.two),
                const PlayingCard(suit: Suit.club, rank: Rank.three),
              ],
              context: const AcademyScenarioContext(
                roundNumber: 18,
                totalRounds: 18,
                highBidInfo: 'القطوع الثابت للدور هو تريفل ♣ دبل، والمزايدة الحالية 5 تريفل',
                scoreSituation: 'أنت متأخر بـ 35 نقطة عن المتصدر وعليك الفوز بهذا الدور بامتياز',
              ),
              prompt: 'أنت في الدور 18 (تريفل ثابت دبل). يدك تحتوي على 6 سبيد خارقة (A-K-Q-J-10-9♠) مع A-K♥ و A-K-Q♦ ولكن تملك كارتين تريفل فقط (2، 3♣). لتغيير القطوع إلى سبيد تحتاج مزايدة 8+. ماذا تفعل؟',
              options: [
                const AcademyScenarioOption(
                  id: 'mc1_opt_1',
                  label: 'المزايدة بـ 8 سبيد ♠ (لتغيير القطوع واكتساح الدور)',
                  quality: AnswerQuality.optimal,
                  feedback: 'أسطوري! يدك تضمن 6 سبيد + 2 هارت + 3 كارو = 11 أكلة! المزايدة بـ 8 قانونية وتغير القطوع وتحسم البولة فوراً.',
                ),
                const AcademyScenarioOption(
                  id: 'mc1_opt_2',
                  label: 'المزايدة بـ 6 تريفل ♣ (تحت القطوع الثابت الضعيف)',
                  quality: AnswerQuality.invalid,
                  feedback: 'انتحار! معك كارتان صغيران فقط في التريفل، وسيقص الخصوم ألوانك وتخسر الدور.',
                ),
                const AcademyScenarioOption(
                  id: 'mc1_opt_3',
                  label: 'باص (Pass)',
                  quality: AnswerQuality.risky,
                  feedback: 'استسلام! تفويت فرصة المزايدة بـ 8 بيدك الخارقة يضيع عليك الريمونتادا والبطولة.',
                ),
              ],
              optimalOptionId: 'mc1_opt_1',
              tacticalRationale: 'قاعدة كسر القطوع الثابت بـ 8 أكلات صُممت خصيصاً لهذه الأيدي الأسطورية، لتحويل التأخر لفوز تاريخي.',
              expectedTricksMin: 8,
              expectedTricksMax: 11,
            ),
          ),
        ],
      ),
    ];
  }
}
