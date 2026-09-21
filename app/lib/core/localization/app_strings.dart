import 'dart:math';

import 'package:flutter/material.dart';

enum AppLanguage {
  english(Locale('en', 'US'), TextDirection.ltr),
  arabic(Locale('ar', 'SA'), TextDirection.rtl);

  const AppLanguage(this.locale, this.direction);

  final Locale locale;
  final TextDirection direction;

  bool get isArabic => this == AppLanguage.arabic;
}

class AppStrings {
  const AppStrings(this.currentLanguage);

  final AppLanguage currentLanguage;

  bool get isArabic => currentLanguage.isArabic;

  String get appName => isArabic ? 'تلاوة' : 'Tilawa';
  String get dailyRevisionPath =>
      isArabic ? 'مسار المراجعة اليومي' : 'Daily revision path';
  String get streak => isArabic ? 'سلسلة' : 'streak';
  String get xp => isArabic ? 'نقاط' : 'xp';
  String get startWeakestSurah =>
      isArabic ? 'افتح أولوية المراجعة' : 'Open priority Surah';
  String get oneTapRevision =>
      isArabic ? 'قيّم حفظك بعد المراجعة' : 'Review, then self-rate';
  String get revisionPath => isArabic ? 'قائمة السور' : 'Surah Navigator';
  String get revisionPathSubtitle => isArabic
      ? 'اختر سورة، راجعها، ثم قيّم حفظك أو أضفها للخطة.'
      : 'Choose a Surah, revise it, then estimate recall or add it to your plan.';
  String get quranDataNotice => isArabic
      ? 'النص القرآني من مصدر موثّق مُضمّن في التطبيق، وصفحات المصحف من مصحف الجماهيرية برواية قالون.'
      : 'Quran text comes from a checksummed source bundled with the app; the '
          'scanned pages are the Libyan Qaloon Mushaf.';
  String get planRevision => isArabic ? 'خطة المراجعة' : 'Revision plan';
  String get todayPlan => isArabic ? 'خطة اليوم' : 'Today plan';
  String get noPlanYet =>
      isArabic ? 'لم تضف سوراً بعد' : 'No Surahs planned yet';
  String get reminder => isArabic ? 'تنبيه' : 'Reminder';
  String get reminderReady =>
      isArabic ? 'حان وقت المراجعة الآن' : 'It is time to revise now';
  String reminderAt(String time) =>
      isArabic ? 'موعد المراجعة: $time' : 'Revision time: $time';
  String selectedCount(int count) =>
      isArabic ? '$count سورة مختارة' : '$count Surahs selected';
  String get addToPlan => isArabic ? 'أضف للخطة' : 'Add to plan';
  String get removeFromPlan => isArabic ? 'إزالة من الخطة' : 'Remove from plan';
  String get estimateRecall => isArabic ? 'قيّم حفظك' : 'Estimate your recall';
  String get excellent => isArabic ? 'ممتاز' : 'Excellent';
  String get good => isArabic ? 'جيد' : 'Good';
  String get shaky => isArabic ? 'متردد' : 'Shaky';
  String get weak => isArabic ? 'ضعيف' : 'Weak';
  String get saveEstimate => isArabic ? 'حفظ التقييم' : 'Save estimate';
  String get startRevision => isArabic ? 'ابدأ المراجعة' : 'Start revision';

  /// Shown instead of a percentage until a surah has been revised once.
  /// Nothing is known before that, and 0% would be a claim, not a blank.
  String get masteryUnknown => isArabic ? 'لم تُراجع بعد' : 'Not revised yet';
  String get masteryUnknownShort => isArabic ? '—' : '—';
  String get hasanatTitle => isArabic ? 'الحسنات' : 'Hasanat';
  String hasanatEarned(String amount) => isArabic
      ? 'الحمد لله! كسبت نحو $amount حسنة'
      : 'Alhamdulillah! You earned ~$amount Hasanat';
  String hasanatLetters(String letters) =>
      isArabic ? '$letters حرف × ١٠' : '$letters letters x 10';
  String get hasanatNote => isArabic
      ? 'على حديث: «مَن قرأ حرفًا من كتاب الله فله به حسنة، والحسنة بعشر أمثالها».'
      : 'On the hadith that one letter of the Book is a good deed, and a good deed is tenfold.';
  String get mastery => isArabic ? 'الإتقان' : 'Mastery';
  String get mistakes => isArabic ? 'الأخطاء' : 'Mistakes';
  String get ayat => isArabic ? 'آيات' : 'ayat';
  String get aya => isArabic ? 'آية' : 'ayah';
  String get dueToday => isArabic ? 'مستحقة اليوم' : 'Due today';
  String get languageLabel => isArabic ? 'اللغة' : 'Language';
  String get theme => isArabic ? 'المظهر' : 'Theme';
  String get light => isArabic ? 'فاتح' : 'Light';
  String get dark => isArabic ? 'داكن' : 'Dark';
  String get planHint => isArabic
      ? 'اجمع السور التي تريد مراجعتها في مسار واضح، ثم افتح الخطة وابدأ سورة تلو الأخرى.'
      : 'Group the Surahs you want to revise into a clear path, then open the plan and work through it.';
  String get howPlansWork => isArabic ? 'كيف تعمل الخطة؟' : 'How a plan works';
  String get planStepChoose => isArabic ? 'اختر السور' : 'Choose Surahs';
  String get planStepRemind => isArabic ? 'حدد وقت التذكير' : 'Set a reminder';
  String get planStepRevise => isArabic
      ? 'افتح الخطة واضغط على السورة التالية'
      : 'Open the plan and tap the next Surah';
  String get createNewPlan =>
      isArabic ? 'إنشاء خطة جديدة' : 'Create a new plan';
  String get planDetails =>
      isArabic ? 'اسم الخطة وموعدها' : 'Name and reminder';
  String get choosePlanSurahs =>
      isArabic ? 'اختر سور الخطة' : 'Choose plan Surahs';
  String get planReadyToCreate => isArabic
      ? 'راجعت اختياراتك؟ خطتك جاهزة.'
      : 'Happy with your choices? Your plan is ready.';
  String get openPlan => isArabic ? 'فتح الخطة' : 'Open plan';
  String get continuePlan => isArabic ? 'متابعة الخطة' : 'Continue plan';
  String get planTodayExplanation => isArabic
      ? 'ابدأ بالسورة الأولى غير المكتملة. بعد المراجعة والتقييم تُحسب السورة ضمن إنجاز اليوم.'
      : 'Start with the first unfinished Surah. A Surah counts for today after you revise and rate it.';
  String get setReminder => isArabic ? 'تحديد التنبيه' : 'Set reminder';
  String get defaultPlanName => isArabic ? 'مراجعة المساء' : 'Evening Revision';
  String get pickAtLeastOneSurah =>
      isArabic ? 'اختر سورة واحدة على الأقل.' : 'Choose at least one surah.';
  String get planName => isArabic ? 'اسم الخطة' : 'Plan name';
  String get createPlan => isArabic ? 'إنشاء خطة' : 'Create plan';
  String get creatingPlan =>
      isArabic ? 'جارٍ إنشاء الخطة...' : 'Creating plan...';
  String get planCreateFailed => isArabic
      ? 'تعذر إنشاء الخطة. أعد المحاولة.'
      : 'Could not create the plan. Please retry.';
  String get activePlans => isArabic ? 'خطط المراجعة' : 'Revision plans';
  String heatmapTooltip(String date, int minutes, int surahs) => isArabic
      ? '$date: $minutes دقيقة، $surahs سورة'
      : '$date: $minutes mins, $surahs ${surahs == 1 ? 'Surah' : 'Surahs'}';
  String get heatmapLess => isArabic ? 'أقل' : 'Less';
  String get heatmapMore => isArabic ? 'أكثر' : 'More';
  String calendarSubtitle(int days, int active) => isArabic
      ? 'آخر $days يوماً — راجعت في $active منها'
      : 'Last $days days - revised on $active of them';
  String get activityCalendar =>
      isArabic ? 'تقويم النشاط' : 'Activity calendar';
  String get score => isArabic ? 'النتيجة' : 'Score';
  String get reviewedToday => isArabic ? 'روجع اليوم' : 'Reviewed today';
  String get apiStatus => isArabic ? 'حالة الخادم' : 'Backend status';
  String get online => isArabic ? 'متصل' : 'Online';
  String get offline => isArabic ? 'غير متصل' : 'Offline fallback';
  String get privacySafe => isArabic
      ? 'يخزّن التطبيق بيانات التقدم فقط.'
      : 'The app stores revision metadata only, not Quran verse text.';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get homeTab => isArabic ? 'الرئيسية' : 'Home';
  String get planTab => isArabic ? 'الخطة' : 'Plan';
  String get progressTab => isArabic ? 'التقدم' : 'Progress';
  String get settingsTab => isArabic ? 'الإعدادات' : 'Settings';
  String get arabic => 'العربية';

  // Filters & Search
  String get searchSurah => isArabic ? 'البحث عن سورة...' : 'Search Surah...';
  String get filterAll => isArabic ? 'الكل' : 'All';
  String get filterJuz30 => isArabic ? 'جزء 30' : 'Juz 30';
  String get filterWeakest => isArabic ? 'الأضعف' : 'Weakest';
  String get filterStrongest => isArabic ? 'الأقوى' : 'Strongest';
  String get filterUnrevised => isArabic ? 'غير مراجعة' : 'Unrevised';
  String get filterMeccan => isArabic ? 'مكية' : 'Meccan';
  String get filterMedinan => isArabic ? 'مدنية' : 'Medinan';
  String get filterSelected => isArabic ? 'المختارة' : 'Selected';
  String get showSurahList =>
      isArabic ? 'إظهار قائمة السور' : 'Show Surah List';
  String get hideSurahList =>
      isArabic ? 'إخفاء قائمة السور' : 'Hide Surah List';
  String get selectAll => isArabic ? 'تحديد الكل' : 'Select All';
  String get deselectAll => isArabic ? 'إلغاء التحديد' : 'Deselect All';
  String get selectWeakest => isArabic ? 'تحديد الضعيف' : 'Select Weak';

  // Home Screen
  String get continueLabel => isArabic ? 'متابعة' : 'Continue';
  String streakCelebrationTitle(int days) => isArabic
      ? 'سلسلة $days ${days == 1 ? 'يوم' : 'أيام'}!'
      : '$days-Day Streak!';
  String get streakCelebrationBody => isArabic
      ? 'أتممت هدف اليوم. عُد غداً لتُبقي السلسلة حيّة.'
      : "You've hit today's target. Come back tomorrow to keep it alive.";
  String percentCompleted(int percent) =>
      isArabic ? '$percent٪ مكتمل' : '$percent% Completed';
  String percentRemaining(int percent) =>
      isArabic ? '$percent٪ متبقٍ' : '$percent% Remaining';
  String exitReminder(int done, int left) => isArabic
      ? 'أتممت $done٪ من مراجعة اليوم — بقي $left٪ فقط لتبلغ هدفك!'
      : "You've completed $done% of today's revision — only $left% left to reach your goal!";
  String get quranCoverageTitle =>
      isArabic ? 'ما راجعته من القرآن' : 'How much of the Quran';
  String surahsRevisedOf(int done, int total) => isArabic
      ? 'راجعت $done من $total سورة'
      : '$done of $total surahs revised';
  String pagesRevisedOf(int done, int total, int percent) => isArabic
      ? 'أي $done صفحة من $total — $percent٪ من المصحف'
      : 'that is $done of $total pages - $percent% of the Mushaf';
  String get customAyahRange =>
      isArabic ? 'أو حدد الآيات' : 'Or choose the ayahs';
  String get fromAyah => isArabic ? 'من آية' : 'From ayah';
  String get toAyah => isArabic ? 'إلى آية' : 'To ayah';
  String get useThisRange => isArabic ? 'استخدم هذا المدى' : 'Use this range';
  String get clearSelection => isArabic ? 'بدون تحديد' : 'Not recorded';
  String get chooseSection => isArabic ? 'اختر المقطع' : 'Choose a section';
  String get ayahRangeIncomplete =>
      isArabic ? 'أدخل رقمي البداية والنهاية.' : 'Enter both ayah numbers.';
  String ayahRangeOutOfBounds(int ayahCount) => isArabic
      ? 'المدى يجب أن يقع بين ١ و $ayahCount.'
      : 'The range must fall between 1 and $ayahCount.';
  String get lastRevisedSection =>
      isArabic ? 'آخر مقطع راجعته' : 'Last section revised';
  String get revisedSectionOptional =>
      isArabic ? 'المقطع المراجع (اختياري)' : 'Revised section (optional)';
  String get assessmentUsageExplanation => isArabic
      ? 'نستخدم تقييمك لتحديث درجة الإتقان وترتيب السور التي تحتاج مراجعة. ونحفظ المقطع لتعرف أين توقفت آخر مرة.'
      : 'Your rating updates mastery and helps prioritize what needs revision. The section is saved so you can see where you stopped last time.';
  String get startReciting => isArabic ? 'ابدأ التسميع' : 'Start reciting';
  String get planDoneForToday => isArabic
      ? 'أتممت خطة اليوم. بارك الله فيك.'
      : "Today's plan is done. Well done.";
  String get planProgressTitle => isArabic ? 'خطة اليوم' : "Today's plan";
  String planProgress(int done, int total) => isArabic
      ? 'راجعت $done من $total سورة'
      : '$done of $total surahs revised';
  String get planProgressEmpty => isArabic
      ? 'أنشئ خطة ليظهر تقدمك هنا'
      : 'Create a plan to track progress here';
  String get dailyGoalSetting =>
      isArabic ? 'هدف المراجعة اليومي' : 'Daily Revision Goal';
  String get minutesLabel => isArabic ? 'دقيقة' : 'min';
  String get versesRevised => isArabic ? 'آيات مراجعة' : 'verses revised';
  String get dueTodayCount => isArabic ? 'المستحق اليوم' : 'Due today';
  String get dueSurahs => isArabic ? 'سور مستحقة المراجعة' : 'Due Surahs';
  String get noDueSurahs => isArabic
      ? 'لقد راجعت كل السور المستحقة اليوم! ما شاء الله'
      : 'No Surahs due today!';
  String get dailyMotivation => isArabic ? 'حكمة اليوم' : 'Daily Motivation';
  String get motivationIntro =>
      isArabic ? 'قال رسول الله ﷺ:' : 'Prophet Muhammad ﷺ said:';
  String get quranCompletion =>
      isArabic ? 'نسبة المراجعة من القرآن' : 'Quran Revision Coverage';
  String get ofQuran => isArabic ? 'من القرآن الكريم' : 'of the Holy Quran';
  String surahCount(int reviewed, int total) =>
      isArabic ? '$reviewed من $total سورة' : '$reviewed of $total surahs';

  // Settings
  String get lifecycleAlerts =>
      isArabic ? 'تنبيهات حالة التطبيق' : 'Lifecycle Alerts';
  String get lifecycleAlertsDesc => isArabic
      ? 'التنبيه عند إغلاق التطبيق أو فتحه أو تشغيله بالخلفية'
      : 'Notify on background, foreground, and exit';
  String get quranFontSizeSetting =>
      isArabic ? 'حجم خط القرآن' : 'Quran Font Size';
  String get defaultSurahListView =>
      isArabic ? 'إظهار قائمة السور دائماً' : 'Always Expand Surah List';
  String get defaultSurahListViewDesc => isArabic
      ? 'عرض القائمة المفتوحة بشكل افتراضي'
      : 'Show the Surah list expanded by default';
  String get exportDataSetting =>
      isArabic ? 'تصدير بيانات المراجعة' : 'Export Revision Data';
  String get exportSubtitle => isArabic
      ? 'نسخ احتياطي لسجل المراجعة والتقدم'
      : 'Backup revision logs and progress data';
  String get exportSuccess => isArabic
      ? 'تم تصدير بيانات المراجعة بنجاح!'
      : 'Revision data exported successfully!';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get quranDataSafety =>
      isArabic ? 'أمان بيانات القرآن' : 'Quran data safety';
  String get checking => isArabic ? 'جارٍ الفحص...' : 'Checking...';
  String get wisdomAutoRotate =>
      isArabic ? 'تبديل حكمة اليوم تلقائياً' : 'Rotate Daily Wisdom';
  String get wisdomAutoRotateDesc => isArabic
      ? 'الانتقال إلى الحكمة التالية تلقائياً، أو اتركها لك'
      : 'Advance on its own, or leave it entirely to you';
  String get wisdomNext => isArabic ? 'الحكمة التالية' : 'Next wisdom';

  // Live recitation reveal
  String get revealShow => isArabic ? 'إظهار النص' : 'Show the text';
  String get revealHide => isArabic ? 'إخفاء النص' : 'Hide the text';
  String get previousPage => isArabic ? 'الصفحة السابقة' : 'Previous page';
  String get nextPage => isArabic ? 'الصفحة التالية' : 'Next page';
  String pageOf(int mushafPage, int position, int total) => isArabic
      ? 'صفحة $mushafPage · $position من $total'
      : 'Page $mushafPage · $position of $total';
  String get tapWordToPeek => isArabic
      ? 'انقر أي كلمة لكشفها، أو رقم الآية لكشف الآية'
      : 'Tap a word to uncover it, or an ayah number for the whole ayah';
  String get reciteFromMemoryHint =>
      isArabic ? 'سَمِّعْ من حفظك...' : 'Recite from your memory...';
  String ayatThisSession(int count) => isArabic
      ? '$count آية في هذه الجلسة'
      : '$count ${count == 1 ? 'ayah' : 'ayat'} this session';
  String ayahPosition(int surah, int ayah) =>
      isArabic ? 'سورة $surah · آية $ayah' : 'Surah $surah · Ayah $ayah';
  String get surahTextUnavailable => isArabic
      ? 'لا يتوفر نص هذه السورة.'
      : 'The text for this surah is unavailable.';
  String get wisdomFromQuran => isArabic ? 'قرآن' : 'Quran';
  String get wisdomFromSunnah => isArabic ? 'سنة' : 'Sunnah';

  // Account
  String get changePhoto => isArabic ? 'تغيير الصورة' : 'Change photo';
  String get choosePhoto => isArabic ? 'اختيار صورة' : 'Choose a photo';
  String get removePhoto => isArabic ? 'إزالة الصورة' : 'Remove photo';
  String get photoFailed =>
      isArabic ? 'تعذّر فتح معرض الصور.' : 'Could not open the photo library.';
  // Getting to know the reciter
  String get profilingSkip => isArabic ? 'تخطّي' : 'Skip';
  String get profilingNext => isArabic ? 'التالي' : 'Next';
  String get profilingFinish => isArabic ? 'ابدأ' : 'Get started';
  String profilingStep(int step, int total) =>
      isArabic ? 'سؤال $step من $total' : 'Question $step of $total';

  String get profilingQ1 => isArabic
      ? 'كم تحفظ من القرآن؟'
      : 'How much of the Quran have you memorised?';
  String get profilingQ1Hint => isArabic
      ? 'يحدد هذا حجم خطتك الأولى.'
      : 'This sets the size of your first plan.';
  String get extentJustStarting => isArabic ? 'في البداية' : 'Just starting';
  String get extentFiveJuz => isArabic ? 'من ١ إلى ٥ أجزاء' : '1-5 Juz';
  String get extentHalf => isArabic ? 'نصف القرآن' : 'Half the Quran';
  String get extentWhole =>
      isArabic ? 'القرآن كاملاً — حافظ' : 'Entire Quran / Hafiz';

  String get profilingQ2 =>
      isArabic ? 'ما أكثر ما يصعب عليك؟' : 'What do you find most difficult?';
  String get profilingQ2Hint => isArabic
      ? 'سنقدّم ما يناسب ذلك في المراجعة.'
      : 'We will put what fits this first in your revision.';
  String get difficultyLongSurahs => isArabic ? 'السور الطويلة' : 'Long Surahs';
  String get difficultyMutashabihat =>
      isArabic ? 'المتشابهات' : 'Mutashabihat (similar verses)';
  String get difficultyConsistency =>
      isArabic ? 'الاستمرار' : 'Staying consistent';
  String get difficultyMotivation => isArabic ? 'الهمّة' : 'Motivation';

  String get profilingQ3 => isArabic
      ? 'أي السور تقرؤها أكثر؟'
      : 'Which Surahs do you recite the most?';
  String get profilingQ3Hint => isArabic
      ? 'اختر ما شئت. ما تكرره يبقى أطول، فنراجعه أقل.'
      : 'Pick any. What you repeat holds longer, so we revise it less.';
  String get recitedAlKahf => isArabic ? 'الكهف' : 'Al-Kahf';
  String get recitedYaseen => isArabic ? 'يس' : 'Yaseen';
  String get recitedAlMulk => isArabic ? 'الملك' : 'Al-Mulk';
  String get recitedJuzAmma => isArabic ? 'جزء عمّ' : 'Juz Amma';

  String get profilingQ4 =>
      isArabic ? 'ما هدفك الأول؟' : 'What is your primary goal?';
  String get profilingQ4Hint => isArabic
      ? 'يحدد هذا ما يدفعك إليه التطبيق كل يوم.'
      : 'This decides what the app pushes you toward each day.';
  String get goalHabit => isArabic ? 'بناء عادة يومية' : 'Build a daily habit';
  String get goalRetain =>
      isArabic ? 'تثبيت ما حفظت' : 'Retain what I have memorised';
  String get goalMemoriseNew =>
      isArabic ? 'حفظ مقاطع جديدة' : 'Memorise new portions';
  String get goalTests =>
      isArabic ? 'الاستعداد للاختبارات' : 'Prepare for tests';

  // Leaderboard
  String get leaderboardTitle => isArabic ? 'لوحة الصدارة' : 'Leaderboard';
  String get leaderboardGlobal => isArabic ? 'الكل' : 'Global';
  String get leaderboardFriends => isArabic ? 'الأصدقاء' : 'Friends';
  String get leaderboardEmpty => isArabic
      ? 'لا أحد هنا بعد. راجع اليوم لتظهر.'
      : 'Nobody here yet. Revise today to appear.';
  String get leaderboardFriendsEmpty => isArabic
      ? 'أضف صديقاً ببريده لتتابعا تقدّم بعضكما.'
      : 'Add a friend by their email to follow each other.';
  String get leaderboardOffline => isArabic
      ? 'تحتاج لوحة الصدارة إلى اتصال وحساب.'
      : 'The leaderboard needs a connection and an account.';
  String get leaderboardYou => isArabic ? 'أنت' : 'You';
  String get addFriend => isArabic ? 'إضافة صديق' : 'Add friend';
  String get friendEmail => isArabic ? 'بريد الصديق' : "Friend's email";
  String get friendAdded => isArabic ? 'تمت الإضافة' : 'Friend added';
  String get friendNotFound =>
      isArabic ? 'لا يوجد قارئ بهذا البريد.' : 'No reciter with that address.';

  String get accountTitle => isArabic ? 'حسابي' : 'My Account';
  String get accountSection => isArabic ? 'الحساب' : 'Account';
  String get preferencesSection => isArabic ? 'التفضيلات' : 'Preferences';
  String get syncSection => isArabic ? 'المزامنة' : 'Sync';
  String get statisticsSection => isArabic ? 'إحصائياتي' : 'Your Numbers';
  String get dataSection => isArabic ? 'البيانات' : 'Data';
  String get signedInWith => isArabic ? 'مسجّل الدخول عبر' : 'Signed in with';
  String get guestMode => isArabic ? 'بدون حساب' : 'No account';
  String get guestModeDesc => isArabic
      ? 'يبقى تقدمك على هذا الجهاز. سجّل الدخول للمزامنة.'
      : 'Your progress stays on this device. Sign in to sync it.';
  String get signInToSync =>
      isArabic ? 'تسجيل الدخول للمزامنة' : 'Sign in to sync';
  String get syncNow => isArabic ? 'مزامنة الآن' : 'Sync now';
  String get syncPending =>
      isArabic ? 'جلسات في انتظار الرفع' : 'Sessions waiting to upload';
  String syncUploaded(int count) => isArabic
      ? 'تمت مزامنة $count جلسة'
      : 'Synced $count ${count == 1 ? 'session' : 'sessions'}';
  String get syncFailed => isArabic
      ? 'تعذّرت المزامنة. سيُعاد المحاولة لاحقاً.'
      : 'Could not sync. It will retry later.';
  String get syncUnavailableOffline => isArabic
      ? 'المزامنة تحتاج إلى حساب واتصال بالخادم.'
      : 'Syncing needs an account and a reachable server.';
  String get totalXpLabel => isArabic ? 'مجموع النقاط' : 'Total XP';
  String get currentStreakLabel =>
      isArabic ? 'السلسلة الحالية' : 'Current streak';
  String get surahsStartedLabel => isArabic ? 'سور بدأتها' : 'Surahs started';
  String get revisionsLabel => isArabic ? 'مرات المراجعة' : 'Revisions logged';
  String dayCount(int days) => isArabic
      ? '$days ${days == 1 ? 'يوم' : 'أيام'}'
      : '$days ${days == 1 ? 'day' : 'days'}';
  String get deleteTooltip => isArabic ? 'حذف' : 'Delete';

  // Daily goal time options
  String goalMinutes(int mins) => isArabic ? '$mins دقيقة' : '$mins min';
  String goalProgress(int done, int total) => isArabic
      ? 'أكملت $done من $total دقيقة اليوم'
      : 'You completed $done of $total minutes today';

  // Celebration messages
  static final _random = Random();

  String get planCreatedTitle {
    final optionsAr = [
      'بسم الله، وُفِّقت!',
      'خطة مباركة!',
      'بداية موفقة!',
      'توكلنا على الله!'
    ];
    final optionsEn = [
      'Plan Created!',
      'Great Start!',
      'Ready, Set, Go!',
      'Bismillah, Let\'s go!'
    ];
    return isArabic
        ? optionsAr[_random.nextInt(optionsAr.length)]
        : optionsEn[_random.nextInt(optionsEn.length)];
  }

  String get planCreatedSubtitle {
    final optionsAr = [
      'خطتك جاهزة، ابدأ بثقة وتوكل على الله',
      'قليل دائم خير من كثير منقطع',
      'استعن بالله ولا تعجز',
      'كل خطوة تقربك من هدفك'
    ];
    final optionsEn = [
      'Your plan is ready. Start with confidence!',
      'Consistency is key to mastery.',
      'Trust in Allah and begin.',
      'Every step gets you closer!'
    ];
    return isArabic
        ? optionsAr[_random.nextInt(optionsAr.length)]
        : optionsEn[_random.nextInt(optionsEn.length)];
  }

  String get revisionSavedTitle {
    final optionsAr = [
      'بارك الله في حفظك',
      'أحسنت صنعاً!',
      'مراجعة ممتازة!',
      'ما شاء الله تبارك الله!'
    ];
    final optionsEn = [
      'Assessment Saved!',
      'Great Job!',
      'Excellent Revision!',
      'MashaAllah!'
    ];
    return isArabic
        ? optionsAr[_random.nextInt(optionsAr.length)]
        : optionsEn[_random.nextInt(optionsEn.length)];
  }

  String get revisionSavedSubtitle {
    final optionsAr = [
      'كل مراجعة تُقرّبك من الإتقان',
      'استمر على هذا المنوال',
      'المراجعة تثبت الحفظ في القلب',
      'خطوة إضافية نحو الضبط المتقن'
    ];
    final optionsEn = [
      'Every revision brings you closer to mastery',
      'Keep up the good work!',
      'Revision sets the Quran in the heart.',
      'One step closer to perfection.'
    ];
    return isArabic
        ? optionsAr[_random.nextInt(optionsAr.length)]
        : optionsEn[_random.nextInt(optionsEn.length)];
  }

  String get scoreDropTitle {
    final optionsAr = [
      'لا تيأس، فإن مع العسر يسرًا',
      'فرصة للتحسين',
      'المراجعة القادمة ستكون أفضل',
      'لا بأس، هذا جزء من التعلم'
    ];
    final optionsEn = [
      "Don't give up! Ease follows hardship.",
      'Room for Improvement',
      'You will do better next time.',
      'It\'s okay, learning is a process.'
    ];
    return isArabic
        ? optionsAr[_random.nextInt(optionsAr.length)]
        : optionsEn[_random.nextInt(optionsEn.length)];
  }

  String get scoreDropSubtitle {
    final optionsAr = [
      'المراجعة المتكررة هي سر الإتقان، واصل ولا تستسلم',
      'حدد أخطاءك وركز عليها في المرة القادمة',
      'النسيان طبيعي، والمراجعة دواءه',
      'استعن بالله وحاول مرة أخرى غداً'
    ];
    final optionsEn = [
      'Consistent revision is the key to mastery. Keep going!',
      'Identify mistakes and focus on them next time.',
      'Forgetting is normal, revision is the cure.',
      'Trust in Allah and try again tomorrow.'
    ];
    return isArabic
        ? optionsAr[_random.nextInt(optionsAr.length)]
        : optionsEn[_random.nextInt(optionsEn.length)];
  }

  // Assessment levels (10-level)
  String get level1 => isArabic ? 'نسيت تماماً' : 'Completely forgot';
  String get level2 => isArabic ? 'ضعيف جداً' : 'Very weak';
  String get level3 => isArabic ? 'ضعيف' : 'Weak';
  String get level4 => isArabic ? 'دون المتوسط' : 'Below average';
  String get level5 => isArabic ? 'متوسط' : 'Average';
  String get level6 => isArabic ? 'فوق المتوسط' : 'Above average';
  String get level7 => isArabic ? 'جيد' : 'Good';
  String get level8 => isArabic ? 'جيد جداً' : 'Very good';
  String get level9 => isArabic ? 'ممتاز' : 'Excellent';
  String get level10 => isArabic ? 'متقن' : 'Mastered';

  String assessmentLabel(int level) {
    switch (level) {
      case 1:
        return level1;
      case 2:
        return level2;
      case 3:
        return level3;
      case 4:
        return level4;
      case 5:
        return level5;
      case 6:
        return level6;
      case 7:
        return level7;
      case 8:
        return level8;
      case 9:
        return level9;
      case 10:
        return level10;
      default:
        return level5;
    }
  }

  /// The face for a confidence level, as a Material icon.
  ///
  /// Not an emoji. A colour emoji needs a font the app does not bundle, so on
  /// the web CanvasKit fetches one the first time one is drawn — which is why
  /// these appeared a moment late. Material icons are already in the bundle
  /// and paint immediately.
  IconData assessmentFace(int level) {
    const faces = [
      Icons.sentiment_very_dissatisfied_rounded,
      Icons.sentiment_very_dissatisfied_rounded,
      Icons.sentiment_dissatisfied_rounded,
      Icons.sentiment_dissatisfied_rounded,
      Icons.sentiment_neutral_rounded,
      Icons.sentiment_satisfied_rounded,
      Icons.sentiment_satisfied_alt_rounded,
      Icons.sentiment_very_satisfied_rounded,
      Icons.star_rounded,
      Icons.workspace_premium_rounded,
    ];
    return faces[(level - 1).clamp(0, 9)];
  }

  // Timer
  String get revisionTime => isArabic ? 'وقت المراجعة' : 'Revision time';
  String get sessionDuration => isArabic ? 'مدة الجلسة' : 'Session duration';
  String get revisionLog => isArabic ? 'سجل المراجعات' : 'Revision Log';
  String get totalTimeToday =>
      isArabic ? 'إجمالي وقت اليوم' : 'Total time today';
  String get noSessionsYet =>
      isArabic ? 'لا توجد جلسات مراجعة بعد' : 'No revision sessions yet';

  // Info Sheets
  String get xpDescription => isArabic
      ? 'كيف تحصل على نقاط إضافية؟\nتحصل على نقاط (XP) بناءً على مدى ثقتك وإجابتك. \n- مراجعة سورة مستحقة تعطيك نقاطاً مضاعفة.\n- التقييم العالي يزيد نقاطك بشكل أكبر.'
      : 'How to earn more XP?\nYou earn Experience Points (XP) based on your confidence rating and correctness.\n- Revising a due Surah grants bonus XP.\n- Higher confidence yields higher XP.';

  String get streakDescription => isArabic
      ? 'ما هي السلاسل (الأسابيع/الأيام)؟\nيشير رقم السلسلة إلى عدد الأيام المتتالية التي التزمت فيها بهدف المراجعة اليومي.\nحافظ على السلسلة ولا تدعها تنقطع!'
      : 'What are Streaks (Chains)?\nThe Streak number indicates how many consecutive days you have met your daily revision goal.\nKeep the streak alive!';

  // Surah detail localized
  String surahInfo(int number, int ayahs) =>
      isArabic ? 'سورة $number - $ayahs آية' : 'Surah $number - $ayahs ayahs';
  String masteryPercent(int percent) =>
      isArabic ? '$percent% إتقان' : '$percent% Mastery';

  // Additional reader & detail localization strings
  String get searchQuranHint =>
      isArabic ? 'ابحث في القرآن...' : 'Search in Quran...';
  String get loadPageError =>
      isArabic ? 'خطأ في تحميل الصفحة' : 'Error loading page';
  String get highlight => isArabic ? 'تظليل' : 'Highlight';
  String get bookmark => isArabic ? 'علامة مرجعية' : 'Bookmark';
  String get revisionMarker => isArabic ? 'علامة مراجعة' : 'Revision marker';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
  String get goToPage => isArabic ? 'انتقل إلى صفحة' : 'Go to page';
  String get pageLabel => isArabic ? 'صفحة' : 'Page';
  String get juzLabel => isArabic ? 'الجزء' : 'Juz';
  String juzNumbered(int juz) => isArabic ? 'الجزء $juz' : 'Juz $juz';
  String get ayahLabel => isArabic ? 'آية' : 'Ayah';
  String get noteLabel => isArabic ? 'ملاحظة' : 'Note';
  String get howWellDidYouDo =>
      isArabic ? 'كيف كان أداؤك؟' : 'How well did you do?';
  String get readFromMushaf => isArabic
      ? 'القراءة من مصحف الجماهيرية'
      : 'Read from Mushaf Al-Jamahiriya';
  String get quickRevision => isArabic ? 'مراجعة سريعة' : 'Quick Revision';

  String get beautifulImprovementTitle =>
      isArabic ? 'تحسن جميل!' : 'Beautiful improvement!';
  String beautifulImprovementSubtitle(int from, int to) => isArabic
      ? 'ارتفع تقييمك من $from إلى $to. ثبّت هذا المستوى بمراجعة قريبة.'
      : 'Your estimate rose from $from to $to. Lock it in with another review soon.';
  String get firstEstimateSavedTitle =>
      isArabic ? 'تم حفظ أول تقييم!' : 'First estimate saved!';
  String get firstEstimateSavedSubtitle => isArabic
      ? 'تم حفظ أول تقييم لهذه السورة. من هنا يبدأ قياس التحسن.'
      : 'First estimate saved for this Surah. Now your improvement has a baseline.';
  String get planCompletedTitle =>
      isArabic ? 'اكتملت الخطة!' : 'Plan Completed!';
  String get planCompletedSubtitle => isArabic
      ? 'ما شاء الله، لقد أتممت مراجعة جميع السور المخطط لها اليوم بنجاح.'
      : 'MashaAllah, you have successfully revised all planned Surahs for today.';
}
