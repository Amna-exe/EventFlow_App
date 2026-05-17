import 'firebase_database_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id']?.toString() ?? '',
        text: m['text']?.toString() ?? '',
        isUser: m['isUser'] as bool? ?? false,
        timestamp: m['timestamp'] is int
            ? DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int)
            : DateTime.now(),
      );
}

class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  final _db = FirebaseDatabaseService();
  final _auth = AuthService();

  final List<ChatMessage> _localHistory = [];
  List<ChatMessage> get localHistory => List.unmodifiable(_localHistory);

  Stream<List<Map<String, dynamic>>> streamHistory() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _db.streamChatHistory(user.id);
  }

  Future<void> loadHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _localHistory.clear();
    final raw = await _db.getChatHistory(user.id);
    _localHistory.addAll(raw.map(ChatMessage.fromMap).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp)));
  }

  Future<ChatMessage> sendMessage(String text) async {
    final user = _auth.currentUser;
    final userMsg = ChatMessage(
      id: 'cm_${DateTime.now().millisecondsSinceEpoch}_u',
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    _localHistory.add(userMsg);
    if (user != null) {
      await _db.writeChatMessage(user.id, userMsg.toMap());
      await _db.logAnalyticsEvent(
        eventName: 'chatbot_message_sent',
        userId: user.id,
        userRole: user.role.name,
        params: {'message_length': text.length},
      );
    }

    final reply = _generateReply(text.trim(), user);
    final botMsg = ChatMessage(
      id: 'cm_${DateTime.now().millisecondsSinceEpoch}_b',
      text: reply,
      isUser: false,
      timestamp: DateTime.now().add(const Duration(milliseconds: 600)),
    );
    _localHistory.add(botMsg);
    if (user != null) {
      await _db.writeChatMessage(user.id, botMsg.toMap());
    }
    return botMsg;
  }

  String _generateReply(String input, UserModel? user) {
    final lower = input.toLowerCase();
    final role = user?.role;

    // Greetings
    if (_matches(lower, ['hello', 'hi', 'hey', 'good morning', 'good afternoon', 'greetings'])) {
      final name = user?.fullName.split(' ').first ?? 'there';
      return 'Hello $name! 👋 I\'m the EventFlow AI Assistant. How can I help you today?';
    }

    // Help
    if (_matches(lower, ['help', 'what can you do', 'what do you know', 'assist', 'support'])) {
      return _helpMessage(role);
    }

    // Events
    if (_matches(lower, ['create event', 'new event', 'add event', 'how to create', 'make event'])) {
      if (role == UserRole.organizer) {
        return 'To create an event:\n1. Go to the **Events** tab in your dashboard\n2. Tap the **+** button in the top right\n3. Fill in the event title, description, date/time, and expected attendees\n4. Choose "Draft" to save privately or "Published" to make it live\n\nNeed help booking a venue room for your event? Just ask!';
      }
      return 'Event creation is available to **Organizers**. If you\'d like to organise events, please register as an organiser.';
    }

    if (_matches(lower, ['publish event', 'publish my event', 'make event live', 'go live'])) {
      return 'To publish an event, open the event in your **Events** tab and tap **Edit**. Change the status from "Draft" to "Published" and save. Your event will then be visible to all attendees!';
    }

    if (_matches(lower, ['delete event', 'remove event', 'cancel event'])) {
      return 'To delete an event, tap the event card, then tap the **delete** icon. Note: events with active bookings must have the booking cancelled first.';
    }

    // Bookings
    if (_matches(lower, ['book', 'booking', 'reserve', 'reservation', 'book a room', 'book venue'])) {
      if (role == UserRole.organizer) {
        return 'To book a venue:\n1. Go to the **Venues** tab\n2. Search for available rooms by date, capacity, and location\n3. Select a room and choose your booking time\n4. Confirm the booking\n\nYour booking will be sent to the venue owner for approval. You\'ll receive a notification once it\'s confirmed!';
      }
      if (role == UserRole.staff) {
        return 'As a venue owner, you can manage incoming booking requests in the **Bookings** tab. You can approve, reject, or modify booking requests there.';
      }
      return 'Bookings are made by **Organizers** when they reserve a room for their events. If you\'re looking to attend an event, check the **Events** tab to register!';
    }

    if (_matches(lower, ['approve booking', 'accept booking', 'reject booking', 'decline booking'])) {
      if (role == UserRole.staff) {
        return 'To manage bookings:\n1. Open the **Bookings** tab in your dashboard\n2. Find the pending booking request\n3. Tap **Approve** to confirm or **Reject** to decline\n\nOrganisers are notified instantly when you respond to their request.';
      }
      return 'Booking approvals are managed by **Venue Owners** in their Bookings tab.';
    }

    // Registration
    if (_matches(lower, ['register', 'registration', 'sign up for event', 'attend event', 'join event'])) {
      if (role == UserRole.attendee || role == null) {
        return 'To register for an event:\n1. Browse events in the **Events** tab\n2. Tap on an event you\'re interested in\n3. Tap the **Register** button\n\nYour registered events appear in your **Calendar** tab. You\'ll get notifications for updates!';
      }
      return 'Event registration is for **Attendees**. Your role allows you to manage events and venues instead.';
    }

    if (_matches(lower, ['unregister', 'cancel registration', 'leave event', 'remove registration'])) {
      return 'To cancel your registration, go to the **Calendar** tab, find the event, and tap **Unregister**. You can also do this from the event details in the Events tab.';
    }

    // Venues & Rooms
    if (_matches(lower, ['add building', 'create building', 'new building', 'add venue'])) {
      if (role == UserRole.staff) {
        return 'To add a new building:\n1. Go to the **Overview** tab\n2. Tap the **+** button\n3. Enter the building name, address, and description\n4. Optionally pick a location on the map\n\nOnce added, you can add rooms to it!';
      }
      return 'Building management is available to **Venue Owners**.';
    }

    if (_matches(lower, ['add room', 'create room', 'new room'])) {
      if (role == UserRole.staff) {
        return 'To add a room:\n1. Tap on a building in the **Overview** tab\n2. Tap **View Rooms** then the **+** button\n3. Fill in room name, capacity, type, and amenities\n4. Set pricing and availability in the room settings\n\nRooms become available for organiser bookings once you configure their availability!';
      }
      return 'Room management is available to **Venue Owners**.';
    }

    if (_matches(lower, ['pricing', 'price', 'hourly rate', 'daily rate', 'cost'])) {
      if (role == UserRole.staff) {
        return 'To set room pricing:\n1. Open a room from the **Overview** tab\n2. Tap the **Pricing** button\n3. Set your hourly and daily rates\n4. Optionally add weekend and peak hour multipliers\n\n💡 Tip: Competitive pricing increases your booking rate! Check your analytics to see trends.';
      }
      return 'Pricing information varies by room. You can see room pricing when browsing available venues in the Venues tab.';
    }

    if (_matches(lower, ['availability', 'available', 'open hours', 'working hours'])) {
      if (role == UserRole.staff) {
        return 'To set room availability:\n1. Open a room, then tap **Availability**\n2. Set your working hours (start/end time)\n3. Choose recurring days (e.g. Mon–Fri)\n4. Add blackout dates for holidays or maintenance\n\nOrganisers can only book during your set availability windows.';
      }
      return 'Room availability is set by venue owners. When searching for rooms, only rooms available in your chosen time window will appear.';
    }

    // Analytics
    if (_matches(lower, ['analytics', 'statistics', 'stats', 'revenue', 'performance', 'insights'])) {
      if (role == UserRole.organizer) {
        return 'Your **Analytics** tab shows:\n• Event registration trends\n• Attendee counts per event\n• Publishing rate (draft vs published)\n• Top performing events\n\nUse these insights to plan better events and maximise attendance!';
      }
      if (role == UserRole.staff) {
        return 'Your **Analytics** tab shows:\n• Revenue trends over time\n• Room occupancy rates\n• Booking approval rates\n• Most popular rooms\n\n💡 Tip: Higher occupancy rooms could benefit from a small price increase!';
      }
      if (role == UserRole.superAdmin) {
        return 'The Super Admin analytics shows:\n• Platform-wide user counts by role\n• Total events and booking statistics\n• Revenue across all venues\n• System activity trends\n\nUse the admin dashboard for full oversight of the platform.';
      }
      return 'Analytics data is available in your dashboard\'s Analytics tab once you log in.';
    }

    // Notifications
    if (_matches(lower, ['notification', 'alert', 'remind', 'updates'])) {
      return 'Notifications keep you updated on:\n• Booking approvals and rejections\n• New booking requests (venue owners)\n• Event updates and cancellations\n• Registration confirmations\n\nCheck the **Alerts/Comms** tab in your dashboard for all notifications.';
    }

    // Payments
    if (_matches(lower, ['payment', 'pay', 'invoice', 'receipt', 'charge', 'refund'])) {
      return 'Payment records are linked to your bookings. You can view payment status (pending, paid, refunded) in the booking details. Invoices are generated automatically for confirmed bookings.';
    }

    // Map / Location
    if (_matches(lower, ['map', 'location', 'where', 'directions', 'address', 'find venue'])) {
      if (role == UserRole.attendee || role == null) {
        return 'The **Map** tab shows events happening near you on an interactive map. Tap any pin to see event details. You can also use the map to find venue locations and get directions!';
      }
      if (role == UserRole.staff) {
        return 'The map in your **Overview** tab shows all your buildings. Tap a building marker for quick access to rooms. You can set exact building coordinates using the "Pick Location" feature when adding/editing a building.';
      }
      return 'The Map tab provides a visual overview of events and venues. Use it to explore what\'s nearby!';
    }

    // Calendar
    if (_matches(lower, ['calendar', 'schedule', 'agenda', 'upcoming'])) {
      if (role == UserRole.attendee) {
        return 'Your **Calendar** tab shows all events you\'ve registered for, organised by date. It checks for time conflicts so you never double-book yourself. Tap any event to see full details or unregister.';
      }
      if (role == UserRole.staff) {
        return 'The **Calendar** tab shows all confirmed bookings across your rooms, giving you a visual schedule. Use it to plan maintenance or identify gaps in your booking schedule.';
      }
      return 'The Calendar helps you keep track of events and bookings. Check the Calendar tab in your dashboard!';
    }

    // Profile
    if (_matches(lower, ['profile', 'account', 'settings', 'change password', 'update profile'])) {
      return 'To update your profile:\n1. Tap the **profile icon** in the top right of any dashboard\n2. Edit your name, email, bio, or contact details\n3. Tap **Save**\n\nTo change your password, use the "Change Password" section on the profile page.';
    }

    // Logout
    if (_matches(lower, ['logout', 'log out', 'sign out', 'exit'])) {
      return 'To log out, tap the **logout icon** in the top right corner of your dashboard. Your data is safely stored and will be there when you log back in!';
    }

    // Admin
    if (_matches(lower, ['admin', 'super admin', 'manage users', 'user management'])) {
      if (role == UserRole.superAdmin) {
        return 'As Super Admin, you can:\n• View all users across all roles\n• Monitor system-wide events and bookings\n• See platform analytics\n• Track user activity\n\nYour dashboard gives you full visibility of the entire EventFlow platform.';
      }
      return 'Super Admin features are restricted to system administrators.';
    }

    // Firebase / Real-time
    if (_matches(lower, ['real time', 'realtime', 'live update', 'sync', 'refresh'])) {
      return 'EventFlow uses **Firebase Realtime Database** for live synchronisation! All changes — new events, booking approvals, registrations — update instantly across all dashboards without needing to refresh. 🔥';
    }

    // EventFlow info
    if (_matches(lower, ['what is eventflow', 'about eventflow', 'about this app', 'what does this do'])) {
      return 'EventFlow is a **Multi-Role Event & Venue Management System**. It connects:\n• 🎯 **Organisers** who create and manage events\n• 🛠️ **Venue Owners** who list and manage spaces\n• 🎟️ **Attendees** who discover and register for events\n• 👑 **Super Admins** who oversee the platform\n\nAll powered by Firebase for real-time updates!';
    }

    // Thanks
    if (_matches(lower, ['thank', 'thanks', 'cheers', 'great', 'awesome', 'perfect'])) {
      return 'You\'re welcome! 😊 Is there anything else I can help you with?';
    }

    // Bye
    if (_matches(lower, ['bye', 'goodbye', 'see you', 'later', 'done', 'that\'s all'])) {
      return 'Goodbye! 👋 Come back anytime if you have questions. Have a great day!';
    }

    // Default fallback with role-aware suggestions
    return _defaultReply(role, input);
  }

  bool _matches(String input, List<String> keywords) =>
      keywords.any((k) => input.contains(k));

  String _helpMessage(UserRole? role) {
    switch (role) {
      case UserRole.organizer:
        return 'As an **Organiser**, I can help you with:\n• Creating and publishing events\n• Booking venue rooms\n• Understanding your analytics\n• Managing attendees\n• Event lifecycle tips\n\nJust ask me anything! e.g. "How do I create an event?"';
      case UserRole.staff:
        return 'As a **Venue Owner**, I can help you with:\n• Adding buildings and rooms\n• Setting pricing and availability\n• Managing booking requests\n• Understanding your revenue analytics\n• Map and location features\n\nJust ask me anything! e.g. "How do I approve a booking?"';
      case UserRole.attendee:
        return 'As an **Attendee**, I can help you with:\n• Registering for events\n• Using the calendar and map\n• Managing your registrations\n• Understanding notifications\n• Finding events by category\n\nJust ask me anything! e.g. "How do I register for an event?"';
      case UserRole.superAdmin:
        return 'As **Super Admin**, I can help you with:\n• Platform analytics overview\n• User management\n• System monitoring\n• Understanding all role features\n\nJust ask me anything about the platform!';
      default:
        return 'I\'m the EventFlow AI Assistant! I can help you with:\n• 🎯 Creating and managing events\n• 🏢 Booking venue rooms\n• 🎟️ Registering for events\n• 📊 Understanding analytics\n• 🗺️ Finding venues on the map\n\nJust ask me a question to get started!';
    }
  }

  String _defaultReply(UserRole? role, String input) {
    final suggestions = <String>[];
    switch (role) {
      case UserRole.organizer:
        suggestions.addAll(['create an event', 'book a venue room', 'view my analytics', 'publish my event']);
        break;
      case UserRole.staff:
        suggestions.addAll(['add a building', 'approve a booking', 'set room pricing', 'view revenue analytics']);
        break;
      case UserRole.attendee:
        suggestions.addAll(['register for an event', 'view my calendar', 'find events on the map', 'cancel registration']);
        break;
      default:
        suggestions.addAll(['what is EventFlow', 'help', 'create an event', 'register for an event']);
    }
    final list = suggestions.map((s) => '• "$s"').join('\n');
    return 'I\'m not sure I understood that. Here are some things you can ask me:\n$list\n\nOr type **"help"** for a full list of what I can do!';
  }
}
