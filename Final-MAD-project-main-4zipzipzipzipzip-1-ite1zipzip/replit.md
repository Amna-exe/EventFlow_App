# EventFlow – Flutter App

## Overview
Multi-role event and venue management system built with Flutter (web). State is backed by **Firebase Realtime Database (RTDB)** with real-time streams across all dashboards, plus an in-memory singleton layer for fast local access.

## Running the App
- Build: `flutter build web --release`
- Serve: `node serve.js` (serves `build/web/` on port 5000)
- The workflow "Start application" runs `node serve.js` automatically

## Roles
- **Super Admin** (`admin@eventflow.com` / `admin123`) — system-wide oversight, user management, platform analytics
- **Organizer** — create events, book venues, view attendees, analytics
- **Venue Owner** (role: `staff`) — manage buildings, rooms, availability, pricing, map locations
- **Attendee** — browse and register for events

## Architecture

### Entry Point
- `lib/main.dart` — MaterialApp with Material 3 theme; initialises Firebase, seeds RTDB on first run

### Screens
- `lib/screens/landing_screen.dart` — role selection
- `lib/screens/login_screen.dart`, `register_screen.dart` — auth
- `lib/screens/dashboards/` — role-specific dashboards:
  - `staff_dashboard.dart` — Venue Owner (hierarchical system + map view)
  - `organizer_dashboard.dart` — Organizer
  - `attendee_dashboard.dart` — Attendee
  - `super_admin_dashboard.dart` — Super Admin (Overview / Users / Analytics / Activity tabs)

### Venue Owner Module
- `lib/screens/dashboards/venue/` — all venue owner UI
  - `rooms_screen.dart` — rooms list for a selected building
  - `widgets/building_card.dart` — building card with location, directions button
  - `widgets/room_card.dart` — room card with pricing/availability summary
  - `widgets/map_view.dart` — OpenStreetMap map showing all buildings as markers
  - `widgets/location_picker.dart` — full-screen map for picking building location
  - `sheets/add_building_sheet.dart` — add/edit building with "Pick Location on Map"
  - `sheets/add_room_sheet.dart` — add/edit room bottom sheet
  - `sheets/pricing_sheet.dart` — room pricing configuration
  - `sheets/availability_sheet.dart` — working hours, recurring days, blackout dates

### AI Chatbot
- `lib/widgets/ai_chatbot_widget.dart` — floating FAB overlay present on all 4 dashboards; animated slide-up panel with typing dots and message bubbles
- `lib/services/chatbot_service.dart` — rule-based assistant; role-aware responses (events, bookings, venues, registration); persists chat history to RTDB

### Models
- `lib/models/user_model.dart` — UserModel, UserRole enum
- `lib/models/building_model.dart` — BuildingModel (includes latitude, longitude)
- `lib/models/room_model.dart` — RoomModel, RoomType enum
- `lib/models/pricing_model.dart` — PricingModel (hourly/daily rates, multipliers, add-ons)
- `lib/models/availability_model.dart` — AvailabilityModel

### Services
- `lib/services/firebase_database_service.dart` — **RTDB wrapper**; streams for users, events, buildings, rooms, bookings, registrations, payments, notifications, messages, chatbot sessions, analytics; seed-guard; bulk-write helpers
- `lib/services/firebase_seed_service.dart` — idempotent RTDB seeder (runs once on first launch via `seedIfNeeded`)
- `lib/services/auth_service.dart` — singleton, manages users/events/bookings/legacy buildings+rooms
- `lib/services/venue_service.dart` — singleton, manages typed buildings/rooms/pricing/availability; includes proximity search via Haversine formula
- `lib/services/map_service.dart` — reverse geocoding (Nominatim/OSM), distance calculation, directions URL builder
- `lib/services/seed_service.dart` — singleton, seeds rich in-memory data at app startup
- `lib/services/booking_management_service.dart` — booking approval/rejection/modification for venue owners
- `lib/services/chat_service.dart` — per-booking message threads
- `lib/services/payment_service.dart` — payment records per booking (pending/paid/refunded)
- `lib/services/notification_service.dart` — venue owner notifications (newBooking, cancellation, reminder, bookingModified)
- `lib/services/document_service.dart` — venue owner documents (license, permit, certificate)
- `lib/services/registration_service.dart` — attendee event registrations (register, unregister, isRegistered, markAttended, countForEvent, seedRegistrations)

### Firebase
- **Project**: `finalmad-d8a9f`
- **RTDB URL**: `https://finalmad-d8a9f-default-rtdb.asia-southeast1.firebasedatabase.app/`
- All 4 dashboards subscribe to RTDB streams (`streamEvents`, `streamBookings`, `streamUsers`, `streamAnalyticsEvents`) via `StreamSubscription` with proper `dispose()` cancellation
- Dates stored as `millisecondsSinceEpoch` ints, converted to `DateTime` on read

### Seeded Test Accounts (password: `password123`)
- **Venue Owners**: `margaret@thorntonvenues.co.uk`, `james@hollowayhalls.com`, `priya@nairspaces.com`
- **Organizers**: `daniel@webbevents.com`, `sophie@lawsoncreative.co.uk`, `ahmed@karimiconsulting.com`
- **Attendees**: `laura.simmons@email.com`, `nathan.brooks@email.com`, `chloe.martinez@email.com`, `ravi.sharma@email.com`
- **Super Admin**: `admin@eventflow.com` / `admin123`

### Seeded Data Summary
- 5 buildings across London, Manchester, Bristol
- 19 rooms covering all RoomType variants (hall, conference, outdoor, classroom, boardroom, studio)
- 12 primary organizer events (8 published, 4 draft; mix of past and future dates) + 4 historical events
- 10 bookings (5 confirmed+approved, 3 pending, 2 cancelled)
- 10 payments (6 paid, 2 pending, 2 refunded)
- Chat threads for 6 bookings with 3–5 messages each (35 messages total)
- 5–7 notifications per venue owner covering all NotificationType variants
- 4–5 documents per venue owner covering all DocumentType variants
- 16 attendee registrations across 4 attendees (Laura, Nathan, Chloe, Ravi) for 7 events; some marked attended for past events

### Attendee Module (Enhanced)
- `lib/screens/dashboards/tabs/attendee_tickets_tab.dart` — Live ticket tab (StatefulWidget with 1s timer): LIVE NOW badge, h:m:s countdown for active events, separate Live/Upcoming/Past sections, star-rating display for past events, stats row, QR placeholder, dashed perforated divider
- `lib/screens/dashboards/tabs/attendee_wishlist_tab.dart` — "Saved Events" tab: bookmarked events with one-tap register/remove, category accent strip
- `lib/screens/dashboards/tabs/attendee_notifications_tab.dart` — Alert notifications with indigo theme, unread badge, mark-all-read
- `lib/screens/dashboards/tabs/attendee_analytics_tab.dart` — Personal analytics: Firebase RTDB live activity log, gamification badges showcase with level + XP progress, participation/attendance rate stats, category pie + bar charts, organizer leaderboard, 6-month timeline bar chart
- `lib/screens/dashboards/tabs/attendee_history_tab.dart` — Full event history timeline grouped as Live Now / Upcoming / Past Years with summary header, status badges, countdown
- `lib/screens/dashboards/tabs/attendee_map_tab.dart` — OpenStreetMap venues + Nearby Events mode: city picker (London/Manchester/Bristol/Birmingham/Leeds), adjustable radius slider (5–50km), Haversine distance badges on markers and list tiles, user location marker
- `lib/services/wishlist_service.dart` — In-memory per-user saved events set (toggle/save/remove/count/savedFor)
- `lib/services/firebase_analytics_service.dart` — Firebase Analytics + RTDB dual-write wrapper
- `lib/services/event_rating_service.dart` — Firebase-backed 5-star ratings + text reviews: submitRating, getAverageRating, getUserRating, getUserRatingCount, hasRated, getReviewsForEvent
- `lib/services/gamification_service.dart` — 8 badge types (firstTimer, eventExplorer, enthusiast, superFan, loyalAttendee, reviewer, wishlistKeeper, earlyBird), Firebase persistence, totalPoints, levelTitle, checkAndAward, loadFromFirebase

### Attendee Dashboard — 8 Tabs
0. **Events** — AI-weighted Recommendations carousel (category/organizer/recency scoring, wishlist boost, max 2 per category), hero stats, My Schedule, search+filter
1. **Tickets** — Live countdown (seconds), LIVE NOW pulse badge, separate sections, star ratings for past events
2. **Saved** — Wishlist with quick register/remove
3. **Calendar** — Monthly calendar view
4. **Map** — OpenStreetMap + Nearby Events mode with city picker, radius slider, distance badges
5. **Alerts** — Notification cards with unread dot indicator
6. **Analytics** — Gamification badges + XP level, participation rate, attendance rate, review count, Firebase charts
7. **History** — Full attendance timeline grouped by year

### Firebase RTDB Extra Refs (New)
- `ratings/{eventId}/{userId}` — star ratings and review text
- `badges/{userId}/{badgeType}` — earned gamification badges with timestamps
- `wishlists/{userId}` — Firebase-synced wishlist event IDs

### Conflict Dialog (Enhanced)
- Shows conflicting event with amber highlight
- Suggests up to 3 alternative events in the same category that have no scheduling conflict

### Event Detail Sheet (Enhanced)
- Shows 5-star rating picker + text review field for past registered events
- Submitting a review also triggers gamification badge check (Critic badge at 3+ reviews)

### Theme (Updated — Professional Indigo)
- Primary: `Color(0xFF4F46E5)` (Indigo 600)
- Primary Dark: `Color(0xFF3730A3)` (Indigo 800)
- Primary Light: `Color(0xFFEEF2FF)` (Indigo 50)
- Background: `Color(0xFFF5F6FF)` (very light indigo wash)
- Text: `Color(0xFF1E1B4B)` / `Color(0xFF64748B)` / `Color(0xFF94A3B8)`
- Success: `Color(0xFF059669)`, Warning: `Color(0xFFD97706)`, Error: `Color(0xFFDC2626)`
- Font: system sans-serif (removed Georgia)

## Key Dependencies
- `firebase_database: ^11.3.5` — Firebase Realtime Database (RTDB) with real-time streams
- `fl_chart: ^0.69.0` — bar, pie, and line charts in all dashboards
- `flutter_map: ^7.0.2` — OpenStreetMap rendering (no API key required)
- `latlong2: ^0.9.0` — coordinate types for flutter_map
- `url_launcher: ^6.2.6` — open Google Maps directions in browser
- `http: ^1.2.2` — Nominatim reverse geocoding API

## Map Features
- Building markers on OpenStreetMap (tap to see info popup)
- Info popup: name, address, room count, coordinates, View Rooms + Directions buttons
- Location picker: tap anywhere on map to place a pin, auto reverse-geocodes address
- Building card shows coordinates badge + Directions button when location is set
- Collapsible map section in dashboard header
- Proximity search: `VenueService().nearbyBuildings(lat, lng, radiusKm)` using Haversine formula

## Running
```
flutter run -d web-server --web-port=5000 --web-hostname=0.0.0.0
```

## Flutter Version
3.32.0 (installed via Nix `pkgs.flutter`)
