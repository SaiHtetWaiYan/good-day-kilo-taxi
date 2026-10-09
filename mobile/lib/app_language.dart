import 'package:flutter/material.dart';

class AppLanguage extends InheritedWidget {
  const AppLanguage({
    super.key,
    required this.code,
    required this.onChange,
    required super.child,
  });

  final String code;
  final ValueChanged<String> onChange;

  static AppLanguage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguage>();

  static bool isMyanmar(BuildContext context) => maybeOf(context)?.code == 'my';

  static String text(BuildContext context, String english) =>
      isMyanmar(context) ? (_myanmar[english] ?? english) : english;

  static String place(BuildContext context, String english) =>
      isMyanmar(context) ? (_places[english] ?? english) : english;

  @override
  bool updateShouldNotify(AppLanguage oldWidget) => code != oldWidget.code;
}

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final language = AppLanguage.maybeOf(context);
    return PopupMenuButton<String>(
      tooltip: AppLanguage.text(context, 'Change language'),
      icon: const Icon(Icons.language_rounded),
      onSelected: language?.onChange,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'en',
          checked: language?.code != 'my',
          child: const Text('English'),
        ),
        CheckedPopupMenuItem(
          value: 'my',
          checked: language?.code == 'my',
          child: const Text('မြန်မာ'),
        ),
      ],
    );
  }
}

const _places = <String, String>{
  'Yangon': 'ရန်ကုန်',
  'Sule Pagoda': 'ဆူးလေဘုရား',
  'Yangon Central Railway Station': 'ရန်ကုန်ဘူတာကြီး',
  'Bogyoke Aung San Market': 'ဗိုလ်ချုပ်အောင်ဆန်းဈေး',
  'Junction City': 'ဂျန်းရှင်းစီးတီး',
  'Shwedagon Pagoda': 'ရွှေတိဂုံဘုရား',
  'Kandawgyi Park': 'ကန်တော်ကြီးပန်းခြံ',
  'Myanmar Plaza': 'မြန်မာပလာဇာ',
  'Inya Lake': 'အင်းလျားကန်',
  'Yangon International Airport': 'ရန်ကုန်အပြည်ပြည်ဆိုင်ရာလေဆိပ်',
  'Downtown': 'မြို့လယ်',
  'Mingala Taungnyunt': 'မင်္ဂလာတောင်ညွန့်',
  'Pabedan': 'ပန်းဘဲတန်း',
  'Dagon': 'ဒဂုံ',
  'Bahan': 'ဗဟန်း',
  'Kamayut': 'ကမာရွတ်',
  'Mingaladon': 'မင်္ဂလာဒုံ',
  'My current location': 'ကျွန်ုပ်၏ လက်ရှိတည်နေရာ',
  'Current location': 'လက်ရှိတည်နေရာ',
  'Pinned map location': 'မြေပုံပေါ် ရွေးထားသောနေရာ',
};

const _myanmar = <String, String>{
  'Good day!': 'မင်္ဂလာပါ!',
  'Change language': 'ဘာသာစကား ပြောင်းရန်',
  'How will you use the app today?': 'ဒီအက်ပ်ကို ဘယ်လို အသုံးပြုမလဲ။',
  'I am a passenger': 'ခရီးသည်အဖြစ် အသုံးပြုမည်',
  'I am a driver': 'ယာဉ်မောင်းအဖြစ် အသုံးပြုမည်',
  'Find a ride and see the fare before booking':
      'ကားမခေါ်မီ ခန့်မှန်းခကို ကြည့်ပါ',
  'Go online and accept nearby requests':
      'အွန်လိုင်းဝင်ပြီး အနီးအနားမှ ခရီးစဉ်များကို လက်ခံပါ',
  'Yangon pilot · Cash rides in Myanmar kyats':
      'ရန်ကုန် စမ်းသပ်ဝန်ဆောင်မှု · ကျပ်ငွေသားဖြင့် ပေးချေပါ',
  'Change role': 'အမျိုးအစား ပြောင်းရန်',
  'Sign in as a passenger.': 'ခရီးသည်အဖြစ် ဝင်ရောက်ပါ။',
  'Sign in as a driver.': 'ယာဉ်မောင်းအဖြစ် ဝင်ရောက်ပါ။',
  'Create your passenger account.': 'ခရီးသည်အကောင့် ဖန်တီးပါ။',
  'Create your driver account.': 'ယာဉ်မောင်းအကောင့် ဖန်တီးပါ။',
  'Full name': 'အမည်အပြည့်အစုံ',
  'Email': 'အီးမေးလ်',
  'Phone number': 'ဖုန်းနံပါတ်',
  'Password': 'စကားဝှက်',
  'Vehicle plate': 'ယာဉ်နံပါတ်',
  'Create account': 'အကောင့်ဖန်တီးရန်',
  'Sign in': 'ဝင်ရောက်ရန်',
  'Already have an account? Sign in': 'အကောင့်ရှိပြီးသားလား။ ဝင်ရောက်ပါ',
  'New here? Create an account': 'အကောင့်အသစ် ဖန်တီးရန်',
  'This account is a driver. Choose that role to sign in.':
      'ဤအကောင့်သည် ယာဉ်မောင်းအကောင့်ဖြစ်သည်။ ယာဉ်မောင်းကို ရွေးပြီး ဝင်ရောက်ပါ။',
  'This account is a passenger. Choose that role to sign in.':
      'ဤအကောင့်သည် ခရီးသည်အကောင့်ဖြစ်သည်။ ခရီးသည်ကို ရွေးပြီး ဝင်ရောက်ပါ။',
  'Turn on location services to use your current location.':
      'လက်ရှိတည်နေရာကို အသုံးပြုရန် တည်နေရာဝန်ဆောင်မှုကို ဖွင့်ပါ။',
  'Allow location access to use your current location.':
      'လက်ရှိတည်နေရာကို အသုံးပြုရန် တည်နေရာခွင့်ပြုချက် ပေးပါ။',
  'Location services are off': 'တည်နေရာဝန်ဆောင်မှု ပိတ်ထားပါသည်',
  'Turn on Android location services so the app can use GPS.':
      'GPS အသုံးပြုနိုင်ရန် Android တည်နေရာဝန်ဆောင်မှုကို ဖွင့်ပါ။',
  'Open location settings': 'တည်နေရာဆက်တင် ဖွင့်ရန်',
  'Location access needed': 'တည်နေရာခွင့်ပြုချက် လိုအပ်ပါသည်',
  'Allow location access in Android settings to use GPS and go online.':
      'GPS အသုံးပြုပြီး အွန်လိုင်းဝင်ရန် Android ဆက်တင်တွင် တည်နေရာခွင့်ပြုပါ။',
  'Open app settings': 'အက်ပ်ဆက်တင် ဖွင့်ရန်',
  'Connection timed out. Please try again.':
      'ချိတ်ဆက်ချိန် ကျော်လွန်သွားပါသည်။ ထပ်မံကြိုးစားပါ။',
  'Connection problem. Check your internet and try again.':
      'အင်တာနက်ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်မံကြိုးစားပါ။',
  'The server returned an invalid response. Please try again.':
      'ဆာဗာတုံ့ပြန်မှု မမှန်ကန်ပါ။ ထပ်မံကြိုးစားပါ။',
  '● Live': '● တိုက်ရိုက်',
  '○ Connecting': '○ ချိတ်ဆက်နေသည်',
  'Sign out': 'ထွက်ရန်',
  'My account': 'ကျွန်ုပ်၏ အကောင့်',
  'Passenger account': 'ခရီးသည်အကောင့်',
  'Driver account': 'ယာဉ်မောင်းအကောင့်',
  'Change password': 'စကားဝှက် ပြောင်းရန်',
  'Leave these fields empty to keep your current password.':
      'လက်ရှိစကားဝှက်ကို ဆက်သုံးရန် ဤနေရာများကို မဖြည့်ဘဲထားပါ။',
  'Current password': 'လက်ရှိ စကားဝှက်',
  'New password': 'စကားဝှက်အသစ်',
  'Confirm new password': 'စကားဝှက်အသစ် အတည်ပြုပါ',
  'New passwords do not match.': 'စကားဝှက်အသစ်များ မကိုက်ညီပါ။',
  'The current password is incorrect.': 'လက်ရှိစကားဝှက် မမှန်ပါ။',
  'Save account': 'အကောင့် သိမ်းရန်',
  'How was your driver?': 'ယာဉ်မောင်း ဝန်ဆောင်မှု ဘယ်လိုရှိပါသလဲ။',
  'Your feedback helps improve Good Day Kilo Taxi.':
      'သင့်အကြံပြုချက်က Good Day Kilo Taxi ကို ပိုကောင်းအောင် ကူညီပေးပါသည်။',
  'Optional feedback': 'အကြံပြုချက် (မဖြည့်လည်းရသည်)',
  'Submit rating': 'အဆင့်သတ်မှတ်ချက် ပို့ရန်',
  'Choose a star rating first.': 'ကြယ်အဆင့်ကို အရင်ရွေးပါ။',
  'Your driver rating': 'သင့်ယာဉ်မောင်း အဆင့်သတ်မှတ်ချက်',
  'My rides': 'ကျွန်ုပ်၏ ခရီးစဉ်များ',
  'No rides yet': 'ခရီးစဉ် မရှိသေးပါ',
  'Try again': 'ထပ်မံ ကြိုးစားပါ',
  'Completed': 'ပြီးဆုံးပါပြီ',
  'Cancelled': 'ပယ်ဖျက်ပြီးပါပြီ',
  'Ride completed': 'ခရီးစဉ် ပြီးဆုံးပါပြီ',
  'No driver found': 'ယာဉ်မောင်း မတွေ့ပါ',
  'Ride cancelled': 'ခရီးစဉ် ပယ်ဖျက်ပြီးပါပြီ',
  'Ready to travel again?': 'နောက်တစ်ကြိမ် သွားရန် အဆင်သင့်ဖြစ်ပြီလား။',
  'Plan another ride': 'နောက်ခရီးစဉ် စီစဉ်ရန်',
  'Where to today?': 'ဒီနေ့ ဘယ်ကို သွားမလဲ။',
  'Choose a pickup and destination in {city}.':
      '{city}တွင် စတင်မည့်နေရာနှင့် သွားမည့်နေရာကို ရွေးပါ။',
  'PICKUP': 'စတင်မည့်နေရာ',
  'DESTINATION': 'သွားမည့်နေရာ',
  'Choose a location': 'နေရာ ရွေးပါ',
  'Use my location': 'ကျွန်ုပ်၏ တည်နေရာကို သုံးရန်',
  'Choose pickup on map': 'မြေပုံပေါ်တွင် စတင်မည့်နေရာ ရွေးပါ',
  'Choose destination on map': 'မြေပုံပေါ်တွင် သွားမည့်နေရာ ရွေးပါ',
  'Search Yangon landmarks': 'ရန်ကုန်ရှိ နေရာများကို ရှာပါ',
  'Set pickup location': 'စတင်မည့်နေရာ သတ်မှတ်ပါ',
  'Set destination location': 'သွားမည့်နေရာ သတ်မှတ်ပါ',
  'Move the map to position the pin': 'ပင်အမှတ်ကို နေရာချရန် မြေပုံကို ရွှေ့ပါ',
  'Pickup point': 'စတင်မည့်နေရာ',
  'Destination point': 'သွားမည့်နေရာ',
  'Finding this location…': 'ဤနေရာကို ရှာဖွေနေသည်…',
  'Confirm pickup': 'စတင်မည့်နေရာ အတည်ပြုပါ',
  'Confirm destination': 'သွားမည့်နေရာ အတည်ပြုပါ',
  'Tap the map or search for a place.':
      'မြေပုံပေါ်တွင် နှိပ်ပါ သို့မဟုတ် နေရာတစ်ခု ရှာပါ။',
  'Use this pickup': 'ဤနေရာမှ စတင်မည်',
  'Use this destination': 'ဤနေရာသို့ သွားမည်',
  'Choose a point inside the Yangon service area.':
      'ရန်ကုန်ဝန်ဆောင်မှုဧရိယာအတွင်း နေရာရွေးပါ။',
  'Pinned map location': 'မြေပုံပေါ် ရွေးထားသောနေရာ',
  'Your current location is outside Greater Yangon. Choose a pickup on the map.':
      'သင့်လက်ရှိတည်နေရာသည် ရန်ကုန်ဝန်ဆောင်မှုဧရိယာပြင်ပတွင် ရှိပါသည်။ မြေပုံပေါ်တွင် စတင်မည့်နေရာ ရွေးပါ။',
  'Outside the Yangon service area': 'ရန်ကုန်ဝန်ဆောင်မှုဧရိယာ ပြင်ပ',
  'Your GPS location is outside Greater Yangon. Use a Yangon demo location to test driver bookings.':
      'သင့် GPS တည်နေရာသည် ရန်ကုန်ပြင်ပတွင် ရှိပါသည်။ ယာဉ်မောင်းစမ်းသပ်ရန် ရန်ကုန် demo တည်နေရာကို သုံးနိုင်ပါသည်။',
  'Use demo location': 'Demo တည်နေရာ သုံးရန်',
  'Demo location active near Sule Pagoda.':
      'ဆူးလေဘုရားအနီး Demo တည်နေရာ အသုံးပြုနေသည်။',
  'Cancel': 'မလုပ်တော့ပါ',
  'Choose from the Yangon pilot locations. Road distance is calculated automatically.':
      'ရန်ကုန် စမ်းသပ်ဝန်ဆောင်မှုရှိ နေရာများမှ ရွေးပါ။ လမ်းကြောင်းအကွာအဝေးကို အလိုအလျောက် တွက်ချက်ပါမည်။',
  'Search a landmark or tap anywhere inside the Yangon service area. Road distance is calculated automatically.':
      'ရန်ကုန်ဝန်ဆောင်မှုဧရိယာအတွင်း နေရာရှာပါ သို့မဟုတ် မြေပုံပေါ်တွင် နှိပ်ပါ။ လမ်းကြောင်းအကွာအဝေးကို အလိုအလျောက် တွက်ချက်ပါမည်။',
  'Book a taxi': 'တက္ကစီ ခေါ်ရန်',
  'Calculate fare': 'ခရီးစရိတ် တွက်ချက်ရန်',
  'YOUR RIDE': 'သင့်ခရီးစဉ်',
  'Finding your driver': 'ယာဉ်မောင်း ရှာနေသည်',
  'Driver on the way': 'ယာဉ်မောင်း လာနေပါပြီ',
  'Ride in progress': 'ခရီးစဉ် လုပ်ဆောင်နေသည်',
  'Nearby drivers can accept this request.':
      'အနီးအနားရှိ ယာဉ်မောင်းများက ဤခရီးစဉ်ကို လက်ခံနိုင်သည်။',
  'Call driver': 'ယာဉ်မောင်းကို ဖုန်းခေါ်ရန်',
  'Call passenger': 'ခရီးသည်ကို ဖုန်းခေါ်ရန်',
  'Phone number is not available.': 'ဖုန်းနံပါတ် မရှိသေးပါ။',
  'Could not open the phone app.': 'ဖုန်းအက်ပ်ကို ဖွင့်၍ မရပါ။',
  'Live driver location': 'ယာဉ်မောင်း၏ လက်ရှိတည်နေရာ',
  'Driver is {distance} km from pickup':
      'ယာဉ်မောင်းသည် စတင်မည့်နေရာမှ {distance} ကီလိုမီတာအကွာတွင် ရှိသည်',
  'Cancel ride': 'ခရီးစဉ် ပယ်ဖျက်ရန်',
  'DRIVER MODE': 'ယာဉ်မောင်း',
  'Head to pickup': 'ခရီးသည်ရှိရာသို့ သွားပါ',
  'You are online': 'အွန်လိုင်း ဖြစ်နေပါပြီ',
  'You are offline': 'အော့ဖ်လိုင်း ဖြစ်နေပါသည်',
  'Start ride': 'ခရီးစဉ် စတင်ရန်',
  'Complete ride': 'ခရီးစဉ် ပြီးဆုံးရန်',
  'Receiving requests': 'ခရီးစဉ်တောင်းဆိုမှုများ လက်ခံနေသည်',
  'Go online to receive rides': 'ခရီးစဉ်များ လက်ခံရန် အွန်လိုင်းဝင်ပါ',
  'Your location helps us find nearby passengers.':
      'သင့်တည်နေရာဖြင့် အနီးအနားရှိ ခရီးသည်များကို ရှာနိုင်သည်။',
  'Allow driver tracking in background':
      'နောက်ခံတွင် ယာဉ်မောင်းတည်နေရာ ခြေရာခံခွင့်ပြုပါ',
  'Choose Allow all the time so passengers can see the taxi when this app is minimized or the screen is locked.':
      'အက်ပ်ကို ချုံ့ထားချိန် သို့မဟုတ် ဖုန်းမျက်နှာပြင် ပိတ်ထားချိန်တွင် ခရီးသည်က တက္ကစီတည်နေရာကို မြင်နိုင်ရန် အမြဲတမ်း ခွင့်ပြုရန်ကို ရွေးပါ။',
  'Not now': 'ယခု မလုပ်သေးပါ',
  'Continue': 'ဆက်လုပ်ရန်',
  'Background location needed': 'နောက်ခံတည်နေရာ လိုအပ်ပါသည်',
  'Open Permissions, choose Location, then select Allow all the time.':
      'ခွင့်ပြုချက်များကို ဖွင့်ပြီး တည်နေရာကို ရွေးကာ အမြဲတမ်း ခွင့်ပြုရန်ကို ရွေးပါ။',
  'Driver location sharing is active': 'ယာဉ်မောင်းတည်နေရာ မျှဝေနေပါသည်',
  'Background driver tracking is active':
      'နောက်ခံ ယာဉ်မောင်းတည်နေရာ ခြေရာခံနေပါသည်',
  'Passengers can see your taxi while you are online or on a ride.':
      'အွန်လိုင်းဖြစ်နေချိန် သို့မဟုတ် ခရီးစဉ်အတွင်း ခရီးသည်များက သင့်တက္ကစီတည်နေရာကို မြင်နိုင်သည်။',
  'NEW REQUESTS': 'တောင်းဆိုမှုအသစ်များ',
  'Accept ride': 'ခရီးစဉ် လက်ခံရန်',
  'APPROXIMATE CASH FARE': 'ခန့်မှန်း ငွေသားခ',
  'Pay the driver in kyats': 'ယာဉ်မောင်းအား ကျပ်ငွေဖြင့် ပေးချေပါ',
  'Choose a place in {city}': '{city}တွင် နေရာရွေးပါ',
  'Search listed places': 'စာရင်းရှိ နေရာများကို ရှာရန်',
  'No listed place matches. Try another name.':
      'ကိုက်ညီသော နေရာ မရှိပါ။ အခြားအမည်ဖြင့် ရှာပါ။',
  'Pilot locations are editable in the backend.':
      'စမ်းသပ်ဝန်ဆောင်မှု နေရာများကို ပြင်ဆင်နိုင်သည်။',
  'GO ANYWHERE\nHAVE A GOOD DAY': 'သွားလိုရာ သွားပါ\nကောင်းသောနေ့လေး ဖြစ်ပါစေ',
  '{city} PILOT · CASH RIDES': '{city} · ငွေသားခရီးစဉ်',
  'My current location': 'ကျွန်ုပ်၏ လက်ရှိတည်နေရာ',
  'Account review pending': 'အကောင့် စစ်ဆေးမှု စောင့်ဆိုင်းနေသည်',
  'Driver account not approved': 'ယာဉ်မောင်းအကောင့်ကို အတည်မပြုပါ',
  'Your driver account is waiting for admin approval.':
      'သင့်ယာဉ်မောင်းအကောင့်သည် အက်ဒမင်အတည်ပြုမှုကို စောင့်ဆိုင်းနေသည်။',
  'An admin must approve your driver account before you can go online.':
      'အွန်လိုင်းမဝင်မီ အက်ဒမင်က သင့်ယာဉ်မောင်းအကောင့်ကို အတည်ပြုရပါမည်။',
  'Please contact Good Day Kilo Taxi support.':
      'Good Day Kilo Taxi အကူအညီဌာနသို့ ဆက်သွယ်ပါ။',
  'Pull down or reopen the app after approval.':
      'အတည်ပြုပြီးနောက် အက်ပ်ကို ပြန်ဖွင့်ပါ။',
};
