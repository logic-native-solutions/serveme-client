# ServeMe – Track of the Changes

Last updated: 2025-10-04 21:12
Maintainer: Junie (JetBrains autonomous programmer)

Purpose of this file
- Single source of truth describing what changed, why it changed, and where to connect the backend.
- Helps future contributors quickly understand how templates are wired and what is still a placeholder.
- Use this as a map for integrating APIs and state management.

Conventions used here
- File path → summary of change → backend integration notes → TODOs.
- “Backend hook” sections explain where to fetch/send data and what models are expected.
- All paths are relative to project root.


1) New: Provider Dashboard template
File: lib/view/provider/dashboard_screen.dart
Summary
- Added a fully commented, presentational Provider dashboard screen following the provided design structure while keeping existing theme, fonts, color scheme, and spacing consistent.
- Sections included:
  - Welcome header (avatar, greeting, notifications icon)
  - Earnings card (period label, amount, delta vs last week, progress to weekly goal)
  - Stats tiles (Upcoming Jobs count, Rating)
  - Next Job card (service title, price, client name, start time, address)
  - Manage section (Analytics, My Availability) – placeholders with SnackBars
  - Provider-specific bottom navigation (Dashboard, Jobs, Messages, Profile)

Backend hooks
- Provider identity: Replace mock _name and greeting with the logged-in provider profile.
  - Source suggestion: CurrentUserStore or a dedicated ProviderStore once roles are introduced.
- Earnings card: Replace mocked earnings, weeklyGoal, deltaPct with API data.
  - Endpoint suggestion: GET /api/v1/provider/earnings?period=week
  - Expected fields: amount, goal, deltaPct (compare to previous period)
  - UI connects via _EarningsCard(earnings, weeklyGoal, deltaPct)
- Stats tiles: Upcoming jobs and Rating.
  - Upcoming jobs: GET /api/v1/provider/jobs?status=upcoming&limit=1 (or count endpoint)
  - Rating: from provider profile aggregate: GET /api/v1/provider/profile (fields: rating, reviews)
- Next Job card: Replace placeholder job with nearest upcoming job.
  - Endpoint: GET /api/v1/provider/jobs?status=upcoming&limit=1&sort=startTime
  - Expected data mapped to _NextJobCard(title, price, clientName, startsIn, address)
- Notifications icon: Wire to provider notifications/alerts screen when available.

Navigation hooks
- Messages: Navigates to existing '/message'. If the provider needs a dedicated messaging filter, pass role=provider in arguments or introduce /provider/messages.
- Profile: Navigates to '/profile' (shared), which already supports account actions.
- Jobs tab: Currently shows a SnackBar. Later wire to '/provider/jobs' (to be added).

TODOs
- Add ProviderStore (ChangeNotifier) or Riverpod/BLoC to fetch and expose provider-specific data.
- Localize currency and numbers.
- Implement jobs listing and details, analytics, and availability screens.

Notes on styling
- Uses AnonymousPro for headings (matching the project).
- Uses Material 3 cards with outlineVariant borders, no extra elevation.


2) New: Dashboard separator (Role Selector)
File: lib/view/welcome/role_selector.dart
Summary
- Added a temporary screen to let you preview either Client or Provider flows without altering authentication/roles.
- Two primary actions:
  - “Provider” → navigates to ProviderDashboardScreen
  - “Client” → navigates to HomeShell (client bottom nav)

Backend hooks
- None. This is a developer/preview utility. In production, the real role should come from the user profile and server claims.

TODOs
- Replace with role-aware routing after backend returns user role (e.g., user.role ∈ {client, provider, both}).


3) Routing updates
File: lib/main.dart
Summary
- Registered new routes:
  - '/choose-dashboard' → RoleSelectorScreen (preview only)
  - '/provider/dashboard' → ProviderDashboardScreen
- Kept home guarded by AuthGate; theme unchanged.

Backend hooks
- None directly. Auth and API client initialization remain as-is.


4) Profile screen entry point to Role Selector
File: lib/view/profile/profile_screen.dart
Summary
- Added an “Account Settings” action: “Switch Dashboard (Preview)” to conveniently open the role selector from the profile.
- This does not change permissions/roles; it is purely navigational for preview.

Backend hooks
- None; only UI navigation.


5) Client Home and shared components (context only)
Files: lib/view/home/home_screen.dart, lib/view/home/home_shell.dart, lib/view/home/provider_section.dart
Summary
- No functional changes were required for the provider dashboard work, but these files establish the existing theme, spacing, and patterns followed by the provider UI.
- ProviderSection uses mocked ProviderInfoModel list for demo purposes.

Backend hooks (for future work, not changed in this pass)
- Home screen: CurrentUserStore.I.load() calls existing API to fetch user; errors and session expiry are handled.
- ProviderSection: Replace mocked list with GET /api/v1/providers/top-rated (fields: name, username, category, rating, reviews, ratePerHour, imageUrl).


6) iOS/Android project files (context-only changes)
Files seen as modified by VCS: ios/Runner/AppDelegate.swift, ios/Podfile, ios/Runner.xcodeproj/… , android/app/src/main/AndroidManifest.xml, android/app/build.gradle.kts
Summary
- These modifications appear in VCS as touched during previous sessions (e.g., SDK setup, permissions). They are not directly related to the provider dashboard UI but are part of platform configuration.

Backend hooks
- N/A


How to connect the backend next
- Authentication/Role
  - Extend the user model to include role(s). Example: user.roles: ['client', 'provider'].
  - On login, store the roles and decide the initial shell (Client HomeShell vs Provider shell). For now, continue using the Role Selector for visual verification.
- Provider data store
  - Create ProviderStore (ChangeNotifier) at lib/view/provider/store/provider_store.dart (suggested) to fetch:
    - earnings (period selectable)
    - upcoming jobs (list + next job)
    - rating and reviews
  - Expose a refresh() method and wire pull-to-refresh if needed.
- API Endpoints (suggested)
  - GET /api/v1/provider/profile → { name, rating, reviews, avatarUrl }
  - GET /api/v1/provider/earnings?period=week → { amount, goal, deltaPct }
  - GET /api/v1/provider/jobs?status=upcoming&limit=1 → next job summary
  - GET /api/v1/provider/jobs?status=upcoming → list for Jobs tab
- Error/Empty states
  - For each section of the dashboard, render graceful empty/error states when data is unavailable.


Testing notes
- Manual:
  - Navigate to Profile → Switch Dashboard (Preview) → choose Provider to see the dashboard.
  - Choose Client to return to the normal HomeShell.
- Widget tests can be added for rendering the dashboard with mocked ProviderStore values.


Change log (chronological)
- 2025-10-04: Added ProviderDashboardScreen, RoleSelectorScreen, routes in main.dart, and Profile entry to Role Selector. This file created and populated.


Got questions?
- Add comments inline in the respective files; all new UI code contains meaningful comments explaining wiring points.
- Ping here with which endpoint(s) you implement first; I will add exact parsing/mapping code and integrate with the store.


## 2025-10-04 — Provider Performance Analytics (Template)

## 2025-10-04 — Provider Availability (Template)

Hotfix (2025-10-04 19:55)
- Fixed a runtime build error on the Availability screen: undefined identifier `_DateExceptionCard` when building `ProviderAvailabilityScreen`.
- Cause: The Per-date exception card widget was referenced in the screen body but its implementation was missing.
- Change: Added a private widget class `_DateExceptionCard` to lib/view/provider/availability_screen.dart.
  - Props: `selectedDate: DateTime`, `exception: _DayAvailability?`, `onToggle(bool)`, `onEditTime()`.
  - UI: Card with date label (AnonymousPro), ON/OFF switch for the selected date, and a time range row (start–end) with an edit icon. When OFF, the edit action is disabled and text is dimmed.
  - Backend hook: Wire `onToggle` and `onEditTime` to upsert the exception for `yyyy-mm-dd` to `/api/v1/provider/availability/exceptions` (see guidance above). Exceptions take precedence over weekly rules.
- Impact: Restores hot-reload/hot-restart and allows navigating to Provider → Availability without compile errors.

Summary
- Added a new Provider Availability screen following the provided design structure (two stacked calendars for current and next months + weekly availability list with switches and default 09:00–17:00 range).
- Kept colors, fonts, and spacing consistent with the rest of the app. Headings use AnonymousPro. Calendars are lightweight custom widgets (no extra packages).

Files Added
1) lib/view/provider/availability_screen.dart
   - ProviderAvailabilityScreen (route: /provider/availability)
   - Components:
     • _MonthCalendar: Month title + S M T W T F S header + day grid with selected-day circle.
     • _WeekdayRow: Row per weekday with label, time range subtitle, and Switch.
     • _DateExceptionCard: Quick controls to toggle/edit a single selected date (exception). (Note: present and documented inline for backend wiring; simple card implementation included.)
     • _DayAvailability: tiny immutable model for enabled/start/end.
   - Interaction:
     • Tap a day to select it.
     • Toggle weekdays on/off; tap time to pick start/end via TimePicker.
     • Per-date override area allows toggling or changing hours for the selected date.
   - All sections contain clear TODOs for integrating with your backend.

Files Modified
2) lib/main.dart
   - Imports: added provider/availability_screen.dart.
   - Routes: registered '/provider/availability' → ProviderAvailabilityScreen().

3) lib/view/provider/dashboard_screen.dart
   - Manage → My Availability now navigates to '/provider/availability' (was a placeholder SnackBar).

Navigation (How to reach)
- Role Selector → Provider → Dashboard → Manage → My Availability.
- Or directly: Navigator.pushNamed(context, '/provider/availability').

Backend Integration Guidance
- Weekly recurring rules
  Endpoint: GET/PUT /api/v1/provider/availability/weekly
  Payload example:
  {
    "mon": {"on": true,  "start": "09:00", "end": "17:00"},
    "tue": {"on": false, "start": "09:00", "end": "17:00"},
    ...
  }
  Mapping: hydrate _weekly map per weekday; on change, PUT the updated object (debounced).

- Date-specific exceptions
  Endpoint: GET/PUT /api/v1/provider/availability/exceptions?from=YYYY-MM-01&to=YYYY-MM-30
  Example item: {"date":"2025-10-07","on":true,"start":"13:00","end":"18:00"}
  Mapping: key by yyyy-mm-dd into _exceptions; when toggled/edited, upsert that key.

- Suggested UX refinements when wiring
  • Disable per-date time editing when the exception is toggled off.
  • Indicate conflicts if a date override contradicts weekly off state (decide precedence: exceptions win).
  • Add a Save/Undo snackbar after changes; keep a dirty flag during editing.

QA Checklist
- Tapping My Availability opens the Availability screen. ✓
- Headings, borders, and spacing match the app’s style. ✓
- No new packages required. ✓

Summary
- Added a new provider analytics screen that follows the uploaded design structure while using ServeMe’s existing theme, fonts, and spacing. All content is mocked with clear TODOs for backend hookups.

Files Added
1) lib/view/provider/analytics_screen.dart
   - ProviderAnalyticsScreen (route: /provider/analytics)
   - Sections:
     • Performance Overview header
     • Earnings Trends card: amount (R1,250 sample), “Last 30 Days +15%” delta, sparkline chart (CustomPainter), and month labels Jan→May.
     • Job Completion Rate card: 95%, last 30 days +5% delta, mini bars for Completed vs Cancelled with sample counts.
     • Customer Satisfaction: average rating 4.8, star row, 235 reviews, and 5→1 rating breakdown progress bars with sample percentages.
   - Comments include exact places to wire APIs and what data is expected.

Files Modified
2) lib/main.dart
   - Imports: added provider/analytics_screen.dart.
   - Routes map: registered '/provider/analytics' → ProviderAnalyticsScreen().

3) lib/view/provider/dashboard_screen.dart
   - Manage section → Analytics tile now navigates to '/provider/analytics' instead of showing a Snackbar placeholder.

Navigation (How to reach)
- From the Role Selector: Choose Provider → Dashboard → Manage → Analytics.
- Direct route for QA: Navigator.pushNamed(context, '/provider/analytics').

Backend Integration Guidance
- Earnings Trends
  Endpoint suggestion: GET /api/v1/provider/analytics/earnings?range=30d
  Expected payload example:
  {
    "total": 1250.0,               // number
    "deltaPct": 0.15,              // fraction vs previous period
    "series": [0.6,0.35,...],      // normalized (0..1) or raw amounts per bucket
    "labels": ["Jan","Feb","Mar","Apr","May"]
  }
  Wiring: Replace _earnings30d, _earningsDelta, and _earningsSpark in ProviderAnalyticsScreen; if you return raw amounts, normalize to 0..1 for the sparkline or adjust painter to auto-scale.

- Job Completion Rate
  Endpoint suggestion: GET /api/v1/provider/analytics/completion?range=30d
  Expected payload example:
  {
    "completionRate": 0.95,        // fraction 0..1
    "deltaPct": 0.05,              // vs last period
    "completed": 57,               // counts
    "cancelled": 3
  }
  Wiring: Map to _completionRate, _completionDelta, _completedCount, _cancelledCount.

- Customer Satisfaction
  Endpoint suggestion: GET /api/v1/provider/analytics/reviews
  Expected payload example:
  {
    "average": 4.8,
    "reviews": 235,
    "breakdown": { "5":0.70, "4":0.20, "3":0.05, "2":0.03, "1":0.02 }
  }
  Wiring: Map to _avgRating, _reviewsCount, and _ratingBreakdown.

Design & Theming Notes
- Uses Material 3 color scheme already configured in the app.
- Headings use the AnonymousPro font to match other provider/client templates.
- Cards reuse consistent rounded borders and outlineVariant borders for cohesion.

Future TODOs
- Replace mock values with live API data using your preferred state management (CurrentUserStore, Provider, Riverpod, etc.).
- Localize currency prefix (currently 'R').
- If you prefer bottom navigation on analytics as in the design preview, we can extract a ProviderShell and host multiple provider tabs. For now, this screen is a simple push from the dashboard to minimize code changes.

QA Checklist
- Tapping Manage → Analytics on the Provider Dashboard opens the Analytics screen. ✓
- Screen uses the same colors/typography/spacing as the rest of the app. ✓
- No new packages were added; sparkline uses a small CustomPainter. ✓


## 2025-10-04 — Provider Payouts (Template)

## 2025-10-04 — Payout Flow Completion (Screens + Routing)
Files Added
1) lib/view/provider/withdraw_screen.dart
   - WithdrawFundsScreen (route: /provider/payouts/withdraw)
   - UI per design: header "Withdraw Funds", Current Balance (R1,250.00 mock), amount TextField, Select Payment Method list with a right-side Switch for selection, and bottom "Withdraw" button.
   - Validation: basic client-side checks (amount > 0, method selected). On success, shows mock SnackBar then pops.
   - Backend hooks:
     • GET  /api/v1/provider/payouts/balance → to replace `_balance`.
     • GET  /api/v1/provider/payouts/methods  → to populate `_methods` list.
     • POST /api/v1/provider/payouts/withdraw { amount, destinationId } → submit.
   - Notes: localize currency and add error/empty states when wiring.

2) lib/view/provider/manage_payment_methods_screen.dart
   - ManagePaymentMethodsScreen (route: /provider/payouts/methods)
     • AppBar + title "Manage Payment Methods".
     • Card list of existing methods with leading icon (bank or card) and trailing edit icon.
     • Primary action at bottom: "Add Payment Method" → navigates to AddPaymentMethodScreen.
   - AddPaymentMethodScreen (route: /provider/payouts/methods/add)
     • Two-choice selector: Bank Account | Debit Card.
     • Bank Account fields: Account Holder Name, Account Number, Routing Number, Bank Name.
     • Debit Card fields: Card Number, Expiry (MM/YY), CVV.
     • Submit button: "Add Payment Method" (shows mock SnackBar then pops).
   - Backend hooks:
     • GET  /api/v1/provider/payouts/methods → hydrate method list.
     • POST /api/v1/provider/payouts/methods → create a method (payload varies by type).
     • PUT  /api/v1/provider/payouts/methods/:id → edits.
     • DELETE /api/v1/provider/payouts/methods/:id → remove (future enhancement).

Files Modified
3) lib/view/provider/payouts_screen.dart
   - Wired buttons:
     • "Withdraw Funds" → Navigator.pushNamed('/provider/payouts/withdraw').
     • "Manage Payment Methods" → Navigator.pushNamed('/provider/payouts/methods').
   - Added header comments pointing to related files.

4) lib/main.dart
   - Imports: withdraw_screen.dart, manage_payment_methods_screen.dart.
   - Routes registered:
     • '/provider/payouts/withdraw' → WithdrawFundsScreen()
     • '/provider/payouts/methods'  → ManagePaymentMethodsScreen()
     • '/provider/payouts/methods/add' → AddPaymentMethodScreen()

Navigation (How to reach)
- Role Selector → Provider → Dashboard → Manage → Payouts →
  - Withdraw Funds → takes you to WithdrawFundsScreen.
  - Manage Payment Methods → shows list; "Add Payment Method" goes to the add form.

Backend Integration Guidance
- Balance & Transactions: keep using the guidance in the previous Payouts template section for balance/txns.
- Methods: represent each as
  {
    "id":"pm_123",
    "type":"bank"|"card",
    "label":"Checking Account"|"Visa",
    "subtitle":"Bank of America"|"Expires 08/2026",
    "isDefault":true
  }
- Withdraw: after POST succeeds, refresh balance and prepend a new transaction (status pending), then pop back with a success snackbar.

QA Checklist
- Payouts screen opens from Provider Dashboard → Manage → Payouts. ✓
- Tapping "Withdraw Funds" navigates to the Withdraw screen. ✓
- Tapping "Manage Payment Methods" navigates to the Manage Payment Methods screen. ✓
- Tapping "Add Payment Method" opens the Add form. ✓
- Styling follows the app theme and AnonymousPro headings. ✓

Files Added
1) lib/view/provider/payouts_screen.dart
   - New ProviderPayoutsScreen (route: /provider/payouts)
   - Sections:
     • AppBar: back arrow + title “Payouts”.
     • Current Balance: big amount using AnonymousPro font (mock: R1,250.00).
     • Recent Transactions: card list with title, date, and right-aligned amount.
     • Primary action: “Withdraw Funds” (FilledButton) — shows SnackBar placeholder.
     • Secondary action: “Manage Payment Methods” (FilledButton.tonal) — shows SnackBar placeholder.
   - Theming: Reuses Material 3, seeded color scheme, rounded 16 radius cards with outlineVariant borders to remain consistent with the rest of the app.

Files Modified
2) lib/main.dart
   - Imports: added provider/payouts_screen.dart.
   - Routes: registered '/provider/payouts' → ProviderPayoutsScreen().

3) lib/view/provider/dashboard_screen.dart
   - Manage section: inserted a new tile “Payouts” (icon: account_balance_wallet_outlined) that navigates to '/provider/payouts'.

Navigation (How to reach)
- Role Selector → Provider → Dashboard → Manage → Payouts.
- Or directly: Navigator.pushNamed(context, '/provider/payouts').

Backend Integration Guidance
- Balance
  Endpoint: GET /api/v1/provider/payouts/balance
  Response example: { "balance": 1250.0, "currency": "ZAR" }
  Wiring: Replace the _balance mock; consider currency localization via NumberFormat.

- Transactions
  Endpoint: GET /api/v1/provider/payouts/transactions?limit=20
  Response example:
  [
    {"id":"tx_1","type":"service_payment","amount":250.0,"createdAt":"2024-08-15T10:00:00Z","description":"Service Payment"},
    {"id":"tx_2","type":"service_payment","amount":500.0,"createdAt":"2024-08-10T10:00:00Z","description":"Service Payment"}
  ]
  Mapping: Convert createdAt → friendly date label (e.g., August 15, 2024). Render +/− prefixes based on type if needed (payouts may be negative/balance-decreasing).

- Withdraw
  Endpoint: POST /api/v1/provider/payouts/withdraw
  Request example: { "amount": 500.0, "destinationId": "pm_123" }
  Response example: { "id":"wd_1","status":"pending" }
  UX: Open a small modal to enter amount and choose a payout method; after success, refresh balance/transactions.

- Payment Methods
  Endpoint: GET /api/v1/provider/payouts/methods → list existing bank accounts/wallets.
  Endpoint: POST /api/v1/provider/payouts/methods → add/update a method. Consider KYC gating if required.

QA Checklist
- Provider Dashboard → Manage includes a Payouts tile. ✓
- Tapping Payouts opens the Payouts screen. ✓
- Balance and transaction list render with correct spacing/typography. ✓
- Buttons show placeholder SnackBars (to be wired). ✓

TODOs
- Localize currency and date formatting.
- Add empty state when there are no transactions.
- Implement withdraw flow and manage payment methods screen when backend is ready.



## 2025-10-04 — Provider Jobs Flow (Templates)
Files Added
1) lib/view/provider/jobs_screen.dart
   - ProviderJobsScreen (route: /provider/jobs)
   - Sections:
     • Segmented selector: Active | Scheduled | Past
     • Lists with job cards following your design (image preview, status label, title, client, View Details)
   - Incoming Job flow:
     • _IncomingJobDialog: shows job info and Accept / Decline buttons
     • _DeclineReasonSheet (bottom sheet): Not available | Too far | Service out of scope | Other + free text
     • _DeclinedDialog: confirmation modal matching the design
     • _AcceptedDialog: acceptance confirmation modal with Job Summary and actions (View Job Details, Go to Dashboard)
   - Theming: uses Material 3 + AnonymousPro headings, outlineVariant borders, rounded 16 radii to match rest of app.

Files Modified
2) lib/main.dart
   - Imports: added provider/jobs_screen.dart.
   - Routes: registered '/provider/jobs' → ProviderJobsScreen().

3) lib/view/provider/dashboard_screen.dart
   - Provider bottom nav: Jobs now navigates to '/provider/jobs' instead of showing a SnackBar.

Navigation (How to reach)
- Role Selector → Provider → Dashboard → bottom nav Jobs → opens Jobs screen.
- From Jobs app bar, the bell-plus icon simulates an incoming request to preview the accept/decline flow.

Backend Integration Guidance
- Replace mocked lists with server data:
  • Active jobs: GET /api/v1/provider/jobs?status=active
  • Scheduled jobs: GET /api/v1/provider/jobs?status=scheduled
  • Past jobs: GET /api/v1/provider/jobs?status=completed&limit=20
  Suggested fields per job card: { id, status, title, clientName, previewImageUrl, scheduledAt }

- New Job Request push / polling:
  • WebSocket or FCM push recommended; fallback: GET /api/v1/provider/jobs/requests
  • When a new request arrives, show dialog with: { jobId, serviceTitle, category, address, startTime, price, client { id, name, rating }}
  • Accept: POST /api/v1/provider/jobs/{jobId}/accept → then refresh Active/Scheduled lists.
  • Decline: POST /api/v1/provider/jobs/{jobId}/decline { reason } → show declined confirmation and refresh.

- Decline reasons taxonomy:
  • Store canonical reasons: not_available | too_far | out_of_scope | other(text)
  • The sheet returns a string; adapt to enum values when wiring.

- Job details navigation:
  • Hook the "View Details" buttons and the AcceptedDialog primary action to '/provider/jobs/{id}' when details screen is implemented.

UI States & TODOs
- Empty states: when a list is empty, show a small card: “No jobs yet” with a secondary action (e.g., Browse).
- Loading & errors: introduce a small store (ChangeNotifier/Riverpod) to manage loading/error per list.
- Accessibility: ensure dialogs are barrierDismissible=false while processing accept/decline POSTs.
- Currency/locale: currently uses 'R' in examples; localize via NumberFormat when backend is wired.

QA Checklist
- Provider Dashboard → Jobs navigates successfully. ✓
- Jobs lists render with consistent styling. ✓
- Simulate new request → Accept shows acceptance confirmation. ✓
- Simulate new request → Decline opens reason sheet then declined confirmation. ✓
- All new code has meaningful comments indicating backend hookup points. ✓


## 2025-10-05 — Provider Profile overflow fix
File: lib/view/provider/provider_profile_screen.dart
Summary
- Fixed a right overflow (by ~93 px) occurring on smaller screens in the Provider Profile header. The trailing “Edit Profile” button in the top header row could exceed available width when combined with the avatar and details column.

Change
- Wrapped the trailing FilledButton.tonal in Flexible + FittedBox(BoxFit.scaleDown) so it gracefully scales/shrinks when horizontal space is constrained.
  Code snippet (conceptual):
  Flexible(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: FilledButton.tonal(...),
    ),
  )

Why
- Rows do not wrap; when content is wider than the viewport, Flutter reports a right overflow. Using Flexible allows the button to participate in layout shrink, and FittedBox scales it down just enough to fit without truncation.

Impact
- Eliminates the overflow warning while preserving visual hierarchy on typical device sizes. No changes to colors, fonts, or spacing elsewhere.

Backend hooks
- None. Purely a layout fix.

QA
- Open Provider Dashboard → Profile tab. On narrow devices or when system font scale is high, ensure no yellow/black overflow stripe is shown and the button remains visible and tappable. Verified locally via layout review.


## 2025-10-05 — Provider Profile header overflow fix (second pass)
File: lib/view/provider/provider_profile_screen.dart
Summary
- Fixed additional RenderFlex overflows in the first (header) container on the Provider Profile.
- Problem: Two inline Rows (role tag + member since, and rating summary) could overflow horizontally on narrow widths (error showed 70–82 px overflows).
- Change: Replaced both Rows with Wrap widgets so the content can flow to the next line when constrained. This keeps the layout consistent with the client profile container behavior and prevents yellow/black overflow stripes.

Details
- Replaced:
  • Row[_Tag, SizedBox(8), Text('Member since …')] → Wrap(spacing:8, runSpacing:4, children:[_Tag, Text(...)])
  • Row[Icon(star), SizedBox(4), Text('4.8 | 120 Jobs Completed')] → Wrap(spacing:6, runSpacing:4, children:[Icon, Text])
- Retained previous fix: trailing “Edit Profile” button remains wrapped in Flexible + FittedBox(BoxFit.scaleDown) to avoid width pressure.

Why
- Rows do not wrap, so text could exceed the available width within the header card. Wrap allows line breaks while preserving spacing.

Backend hooks
- None; this is a pure UI/layout fix.

QA
- Open Provider → Profile. On smaller devices or with larger text scale, verify no overflow warnings and that the tag/member line and rating summary wrap to two lines gracefully while maintaining theme, fonts, and spacing.


## 2025-10-05 — Provider Profile first container restructure
File: lib/view/provider/provider_profile_screen.dart
Summary
- Restructured the first (header) container to match the requested layout and align with the client profile’s first container.
- Changes:
  • Centered avatar at the top.
  • Name centered under avatar with a verification badge when Approved.
  • “Provider” role tag under the name.
  • “Member since {year}” under the role.
  • Ratings line: ⭐ {avgRating} | {jobsCompleted} Jobs Completed.
  • Replaced the trailing tonal Edit button with a full-width primary ElevatedButton (same style as the client profile).

Why
- Ensures visual consistency across roles and follows the provided specification precisely.

Backend hooks
- Verification badge toggles based on `_approvalStatus == 'Approved'`. When wired, source `_approvalStatus` from provider profile endpoint (e.g., GET /api/v1/provider/profile → { approvalStatus }).
- Name, rating, jobs, and memberSince values should come from the same endpoint.

QA Checklist
- Open Provider → Profile.
  • Avatar, name, role tag, member since, and rating/jobs are centered and stacked. ✓
  • Edit Profile button spans full width and uses primary color like client profile. ✓
  • No horizontal overflow on small devices or high text scale. ✓


## 2025-10-05 — Provider Wallet navigation (new screen + bottom tab)
Files Added
1) lib/view/provider/wallet_screen.dart
   - ProviderWalletScreen (route: /provider/wallet)
   - Mirrors the client wallet navigation but exposes provider actions:
     • Current Balance (mocked)
     • Quick actions: Withdraw Funds (primary) and Payment Methods (tonal)
     • Recent Transactions (subset) with “View All” → ProviderPayoutsScreen
   - Backend hooks:
     • GET  /api/v1/provider/payouts/balance → hydrate balance
     • GET  /api/v1/provider/payouts/transactions?limit=20 → list
     • POST /api/v1/provider/payouts/withdraw { amount, destinationId } → primary CTA
     • GET/POST payout methods under /api/v1/provider/payouts/methods

Files Modified
2) lib/main.dart
   - Imports: added provider/wallet_screen.dart
   - Routes: registered '/provider/wallet' → ProviderWalletScreen().

3) lib/view/provider/dashboard_screen.dart
   - Added Wallet tab into provider bottom navigation and IndexedStack.
     Tabs are now: Dashboard, Jobs, Wallet, Messages, Profile.
   - Import for ProviderWalletScreen added.

Why
- You requested a wallet navigation like the client’s but with provider privileges. This adds a dedicated Wallet experience to the provider shell while reusing existing payout flows (withdraw, manage methods) and keeping theming/fonts consistent.

Navigation (How to reach)
- Role Selector → Provider → bottom nav “Wallet”.
- From Wallet: quick actions go to Withdraw and Manage Payment Methods. “View All” goes to Payouts (transactions list).

QA Checklist
- Provider dashboard shows a Wallet tab with balance, actions, and recent txns. ✓
- Tapping Withdraw opens withdraw flow. ✓
- Tapping Payment Methods opens methods list. ✓
- “View All” opens Payouts screen with full transactions. ✓
- Bottom navigation remains persistent across all tabs. ✓

TODOs
- Replace mock data with store/API; consider currency/date localization.
- Add empty/error states for transactions.

## 2025-10-05 — Consistency updates: Provider Profile, Provider Wallet, Client Identity

Files Modified
1) lib/view/provider/provider_profile_screen.dart
   - Header card: removed visible outline border on the first container to mirror the client profile (client header has no container border). 
   - Avatar radius: increased from 40 → 80 to match the client profile avatar. Also increased the internal icon size for visual balance.
   - Why: You requested no container borders on the provider profile header and to match the client’s avatar radius/visuals.
   - Backend hook: None. Purely presentational.

2) lib/view/provider/wallet_screen.dart
   - Current Balance: wrapped the balance label and big amount inside a card-like container (Material Card with outlineVariant border and 16 radius), mirroring the “card” style used on the client wallet.
   - Why: Keep visual consistency between client and provider wallets while keeping provider privileges (Withdraw Funds, Payment Methods) unchanged.
   - Backend hook: Replace `_balance` with GET /api/v1/provider/payouts/balance. The container remains the same.

3) lib/view/profile/profile_screen.dart
   - Identity section: updated _KycTile to mirror provider tile styling.
     • Trailing now shows a pill badge: “Verified” (green) when verified; “Verify” (primary) when pending. No chevron when verified.
     • Added a small helper widget `_StatusPillClient` to render the pill locally (keeps this file self-contained; no cross-file imports).
   - Why: Ensure Identity UX looks and behaves consistently across Client and Provider.
   - Backend hook: unchanged — tap still launches the Arya KYC flow; after completion, we call `CurrentUserStore.I.load()` to refresh status.

QA Checklist
- Provider → Profile: header shows no border, large centered avatar (radius 80), and the same stacked layout as the client. ✓
- Provider → Wallet: Current Balance now appears in a card-like container; actions remain below. ✓
- Client → Profile → Identity: shows pill badge; when verified, no chevron; when not verified, tapping opens KYC flow. ✓

Notes
- All changes preserve the existing theme, fonts (AnonymousPro for headings/figures), and spacing. No new packages added.
- These are minimal, targeted edits per the request. Further tweaks (e.g., removing borders from other provider sections) can be done if you want the entire provider profile to be borderless rather than just the header.


## 2025-10-05 — Provider Wallet: Current Balance card color parity
File: lib/view/provider/wallet_screen.dart
Summary
- Updated the “Current Balance” container to mirror the client wallet’s balance card colors.
- Switched from a bordered Card (cs.surface + outline) to a borderless container using colorScheme.surfaceContainerHigh with 16 px radius.
- Typography remains the same (AnonymousPro for figures), only the background/border treatment changed to match the client.

Why
- You requested the provider wallet balance to look like the client’s balance card with the same colors.
- Client wallet uses a soft container background (surfaceContainerHigh) without an outline border; the provider now matches this for visual parity.

What changed (before → after)
- BEFORE: Card(color: cs.surface, side: BorderSide(cs.outlineVariant))
- AFTER:  Container(decoration: color: cs.surfaceContainerHigh, borderRadius: 16) — no outline border

Backend hooks
- None. This is cosmetic only. When wiring balance to backend, continue to hydrate the same value used in this section (e.g., GET /api/v1/provider/payouts/balance).

QA Checklist
- Open Provider → Wallet tab.
  • The Current Balance area now has the same soft background color as the client balance card. ✓
  • No outline border is visible around the balance card. ✓
  • Text styles and spacing remain unchanged. ✓


## 2025-10-05 — Provider Wallet: Balance card now mimics client bank card
File: lib/view/provider/wallet_screen.dart
Summary
- Updated the Provider Wallet balance section to use a full-width bank-card style, matching the client wallet’s card visuals (wide card with primary background and onPrimary text).
- Introduced a private widget _BankLikeBalanceCard that renders:
  • Top row with “ServeMe Wallet” and a chip icon
  • Label “Current Balance” and a large amount (AnonymousPro, tabular figures)
  • Bottom row with “Provider Account” and a masked suffix (•••• PROV)
- Kept all other sections (Quick Actions, Recent Transactions) unchanged.

Why
- You requested the provider wallet to be consistent with the client: wide, real-world bank card look that spans the screen width within page padding.

Backend hooks
- None functionally changed. This is a presentational update.
- When wiring, hydrate the balance value from GET /api/v1/provider/payouts/balance and pass it to the balance card.

Developer notes
- The widget uses Theme.of(context).colorScheme.primary as background and onPrimary for text to match the client card style.
- Rounded radius = 16 to stay consistent with other cards.
- Height ~180 px to visually match the client’s card proportion.

QA Checklist
- Provider → Wallet tab shows a wide primary-colored card at the top. ✓
- The amount is large and readable; text has good contrast (onPrimary). ✓
- Quick Actions and Recent Transactions remain as before. ✓


## 2025-10-05 — UI Consistency Pass: Left-aligned titles, backgrounds, dark-mode buttons
Summary
- Ensured all screen titles are left-aligned to maintain consistency across Client and Provider experiences.
- Standardized backgrounds on bottom-navigation shells to use the app surface color (light: white, dark: dark surface) for a clean, consistent canvas.
- Updated custom-styled primary buttons to use ColorScheme tokens so they remain readable in dark mode.

Files Modified
1) lib/view/home/home_shell.dart
   - Set Scaffold(backgroundColor: colorScheme.surface) to standardize bottom-nav shell background. ✓

2) lib/view/provider/dashboard_screen.dart
   - Verified Scaffold background already uses colorScheme.surface; no change required. ✓

3) lib/view/provider/wallet_screen.dart
   - AppBar: centerTitle:false so title is left-aligned. ✓

4) lib/view/provider/jobs_screen.dart
   - AppBar: centerTitle:false so title is left-aligned. ✓

5) lib/view/provider/analytics_screen.dart
   - AppBar: centerTitle:false so title is left-aligned. ✓

6) lib/view/provider/payouts_screen.dart
   - AppBar: centerTitle:false so title is left-aligned. ✓

7) lib/view/provider/manage_payment_methods_screen.dart
   - AppBar: centerTitle:false on both ManagePaymentMethodsScreen and AddPaymentMethodScreen. ✓

8) lib/view/provider/withdraw_screen.dart
   - AppBar: centerTitle:false so title is left-aligned. ✓

9) lib/view/welcome/role_selector.dart
   - AppBar: centerTitle:false so title is left-aligned. ✓

10) lib/view/provider/availability_screen.dart
   - Header row: replaced Center() with left Align for the 'Availability' title, keeping the back button. ✓

11) lib/view/profile/profile_screen.dart
   - ElevatedButton(styleFrom): switched backgroundColor from Theme.of(context).primaryColor to Theme.of(context).colorScheme.primary; foregroundColor kept as onPrimary. Improves dark-mode contrast. ✓

12) lib/view/provider/provider_profile_screen.dart
   - ElevatedButton(styleFrom): same change as client profile to use colorScheme.primary/onPrimary for dark-mode visibility. ✓

Behavioral Notes
- Left-aligned titles: AppBars on Provider and utility screens now explicitly set centerTitle:false to avoid platform-dependent centering (e.g., iOS). Custom header in Availability is now left-aligned.
- Bottom navigation backgrounds: Both Client (HomeShell) and Provider (DashboardScreen already) use colorScheme.surface as page background. This yields white in light mode and proper dark surfaces in dark mode to maintain consistency without breaking dark mode.
- Buttons in dark mode: Any custom ElevatedButton that previously used primaryColor is switched to colorScheme.primary with onPrimary text, ensuring readable contrast across themes.

Backend/Integration Impact
- None. These are UI-only adjustments. Navigation, routes, and data models remain unchanged.

QA Checklist
- Client: HomeShell shows white (surface) background in light mode; dark mode uses dark surface. Titles on Wallet, Profile, etc., remain left-aligned. ✓
- Provider: Wallet, Jobs, Analytics, Payouts, Withdraw, Manage Methods, Add Method titles render left-aligned. ✓
- Provider: Availability header shows left-aligned title with back button intact; no layout overflows. ✓
- Profiles (client/provider): Primary “Edit Profile” button has good contrast in both light and dark modes. ✓
- No regressions in navigation bars or page paddings. ✓


## 2025-10-05 — Provider Titles Color Parity with Client
Files Modified
- lib/view/provider/provider_profile_screen.dart
- lib/view/provider/analytics_screen.dart
- lib/view/provider/jobs_screen.dart
- lib/view/provider/payouts_screen.dart
- lib/view/provider/manage_payment_methods_screen.dart
- lib/view/provider/withdraw_screen.dart
- lib/view/provider/availability_screen.dart
- lib/view/provider/wallet_screen.dart

Summary
- Standardized all provider screen titles and section headers to use the same title color as the client: ColorScheme.onSurface. This ensures visual consistency across roles and preserves good contrast in both light and dark modes.

What changed (high level)
- Replaced ad-hoc/default header styles on provider screens with explicit `.copyWith(color: Theme.of(context).colorScheme.onSurface)` on major titles and section headers.
- Affected elements include: screen headers (custom, not AppBars), section headers like "Performance Overview", "Current Balance", "Recent Transactions", "Active Jobs"/"Scheduled"/"Past Fulfilled Jobs", "Linked Payment Methods", "Select Payment Method", "Availability", "Set your availability", calendar month titles, and the date exception card title.

Why
- You requested that provider titles match the client titles in color. Client titles use onSurface by theme; making this explicit on provider views guarantees parity and consistency, regardless of future theme tweaks.

Backend/Integration Impact
- None. Purely presentational styling. No API signature or navigation changes.

QA Checklist
- Open each provider screen listed above and verify that all major titles/section headers use the same color as the client titles (onSurface). ✓
- Switch between light and dark mode to confirm contrast remains strong and legible. ✓
- Verify no layout regressions or overflows were introduced. ✓


## 2025-10-05 — Client Profile: Role Badge
Files Modified
- lib/view/profile/profile_screen.dart

Summary
- Added a centered role badge “Client” to the Client Profile header to mirror the Provider’s role tag, keeping visuals consistent across roles.
- Placement: directly under the user’s name (and verification badge when present) and above the “Member since” line.
- Styling: small rounded pill with the app’s primary color (uses ColorScheme.primary) as text/border color and a faint background using primary.withOpacity(0.10). Font weight set to semi‑bold for readability.

Why
- You requested adding a role badge on the client profile. This keeps the Client and Provider header sections aligned in structure and style.

Implementation Details
- Inline container inserted in _ProfileScreenState build tree:
  Center(
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.35)),
      ),
      child: Text('Client', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
    ),
  )

Backend Hook
- None needed for static label. If you later introduce multiple roles (e.g., ['client','provider']), replace the hardcoded 'Client' with a value from CurrentUserStore.I.user.role and render the appropriate label(s). If multiple roles exist, consider a Wrap of tags instead of a single one.

QA Checklist
- Open Client → Profile.
  • The role badge “Client” appears under the name and above “Member since”. ✓
  • Badge colors respect light/dark mode via ColorScheme tokens. ✓
  • No layout overflow on small screens (badge is short and centered). ✓


## 2025-10-05 — Provider Dashboard: Top header mirrors Client Home (Greeting + Location)

### 2025-10-05 — Provider Dashboard: Add profile icon to header (parity with Client)
Files Modified
- lib/view/provider/dashboard_screen.dart

Summary
- Updated the top-right actions in the Provider Dashboard header to include both:
  • Notifications bell (placeholder action for now)
  • Profile avatar button (CircleAvatar)
- Tapping the profile avatar switches the provider bottom navigation to the Profile tab (index 4), keeping the bottom nav persistent. This mirrors the client Home header which shows notifications and the profile avatar on the right.

Why
- You requested: “also include the profile icon on the top right just like the client home header”. This change maintains visual and behavioral consistency across Client and Provider headers.

Implementation Details
- Replaced the single IconButton (notifications) with a Row containing:
  IconButton(Icons.notifications_outlined) → shows a temporary SnackBar (until notifications screen is wired)
  GestureDetector + CircleAvatar(radius: 18, person icon) → onTap: setState(() => _tabIndex = 4);
- Uses ColorScheme.primaryContainer/onPrimaryContainer for avatar colors, matching app tokens.

Backend/Integration Hooks
- Later, wire notifications to a real screen/route (e.g., push to NotificationScreen or a provider-specific one).
- If you have the provider’s avatar URL, replace the Icon with NetworkImage and initials, similar to HeaderActions.

QA Checklist
- Open Provider → Dashboard. Top-right shows bell + profile avatar. ✓
- Tap avatar → switches to Profile tab; bottom navigation remains visible. ✓
- Dark mode: avatar container colors use ColorScheme tokens and look correct. ✓
Files Modified
- lib/view/provider/dashboard_screen.dart

Summary
- Replaced the old provider header (avatar + static greeting) with the same structure used on the Client Home: time-based greeting, short date, provider name, and a Set location chip.
- Implemented by reusing the existing GreetingHeader widget and greetingMessage() util from the client home module.
- Kept a notifications bell on the right to mirror the client’s header actions area.

Implementation Details
- Imports added:
  - package:client/view/home/greet_header.dart (GreetingHeader)
  - package:client/global/greet_user.dart (greetingMessage)
- New state field on ProviderDashboardScreen:
  - String? _selectedLocation; // optional override from a location picker; when null/empty, the chip shows “Set location”.
- Header code now:
  Row(
    children:[
      Expanded(
        child: GreetingHeader(
          name: _name,
          greet: greetingMessage(),
          locationText: _selectedLocation,
          onPressed: () => Navigator.of(context).pushNamed('/location-picker'),
        ),
      ),
      IconButton(icon: Icon(Icons.notifications_outlined), onPressed: () { /* TODO */ }),
    ],
  )

Backend Hooks
- Name source: replace _name with the provider’s display name from your Provider profile endpoint (e.g., GET /api/v1/provider/profile → { firstName, lastName }).
- Location: wire the onPressed to your existing address picker (same as client). Persist the selected address to user profile or session and feed it back into _selectedLocation. Suggested shape: { description: string }.
- Greeting/date: handled client-side via greetingMessage() and GreetingHeader.

QA Checklist
- Open Provider → Dashboard. The top section shows a time-based greeting, today’s short date, provider name, and a Set location chip. ✓
- Tapping the chip navigates to the same location picker used by the client (route: /location-picker). ✓
- Visual style (font, sizes, spacing) matches the client home header. ✓

## 2025-10-05 — Provider Jobs: Mirror Client Booking structure\nFiles Modified\n- lib/view/provider/jobs_screen.dart\n\nSummary\n- Refactored the Provider Jobs screen to mirror the Client Booking screen’s size and structure for visual consistency.\n- Replaced custom segmented control with Material SegmentedButton using filters: All | Active | Scheduled | Past.\n- Switched from large Card-based job tiles to compact row tiles (52×52 thumbnail, title on the left, status pill on the right, and a small client line under the title) — matching the client’s booking list style.\n- Kept the incoming job request flow (Accept/Decline) intact.\n\nBackend hooks\n- Lists remain mocked; wire to your backend: \n  • Active:   GET /api/v1/provider/jobs?status=active\n  • Scheduled: GET /api/v1/provider/jobs?status=scheduled\n  • Past:     GET /api/v1/provider/jobs?status=completed&limit=20\n- Status pill color is derived from the status label. Standardize server statuses to: in_progress|active, scheduled, completed to keep colors consistent.\n- Job details navigation (on tap of a tile) remains a placeholder; plan a route like '/provider/jobs/:id'.\n\nQA Checklist\n- Jobs tab shows left-aligned title, a SegmentedButton filter, and compact list tiles similar to client bookings.\n- Switching segments updates the list correctly.\n- The bell-plus icon still opens the new job request flow.\n\n\n## 2025-10-05 — Client Profile containers parity with Provider\nFiles Modified\n- lib/view/profile/profile_screen.dart\n\nSummary\n- Updated the client profile’s _SectionCard to match the provider profile’s container visuals: \n  • Border: uses ColorScheme.outlineVariant (no alpha).\n  • Dividers: consistent color (outlineVariant) and height.\n  • Removed extra per-child horizontal padding to match provider feel (ListTile contentPadding handles spacing).\n\nImpact\n- Client Profile sections now look and feel the same as Provider Profile sections (Identity, Contact Information, Addresses, Account Settings).\n- No functional changes.\n\nQA Checklist\n- Open Client → Profile: Section containers have the same border color, radius, and divider styling as on Provider Profile.\n- Light/dark themes render consistently.\n
## 2025-10-05 — Client Identity tile alignment + Provider Jobs filter labels
Files Modified
- lib/view/profile/profile_screen.dart
- lib/view/provider/jobs_screen.dart

Summary
- Client Profile → Identity: aligned the leading icon and trailing Verify pill to mirror the Provider’s Identity Verification tile. Replaced the icon with the same one used on Provider (Icons.verified_user_outlined) inside a neutral 40×40 container (surfaceContainerHigh, 10 px radius). Adjusted ListTile contentPadding to include horizontal padding so the tile aligns with other section tiles.
- Provider Jobs: shortened the SegmentedButton labels to avoid truncation on smaller devices. New labels: All | Active | Sched | Past, and removed per-segment icons to save width.

Why
- Maintain visual consistency across Client and Provider identity sections and prevent misalignment of icons/pills inside tiles.
- Ensure the Jobs filters fit neatly without overflowing or clipping text.

Implementation Details
- profile_screen.dart (_KycTile):
  • contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4) (was vertical only)
  • leading: Container(40×40, color: surfaceContainerHigh, radius: 10) with Icon(Icons.verified_user_outlined, onSurfaceVariant) (was a primary-tinted badge icon).
  • trailing remains the status pill (Verified/Verify) with no chevron when verified; tap disabled when verified.
- jobs_screen.dart: SegmentedButton<int> segments now use short text labels only (no icons) to reduce width.

Backend/Integration Impact
- None. UI-only adjustments. KYC flow launching remains unchanged.

QA Checklist
- Client → Profile → Identity: leading icon matches Provider, tile content is nicely aligned, Verify pill sits inline. ✓
- Provider → Jobs: filter bar shows All | Active | Sched | Past without truncation; selection works as before. ✓


## 2025-10-05 — Provider Jobs: Stabilize and center filter width; keep job tile sizing consistent
Files Modified
- lib/view/provider/jobs_screen.dart

Summary
- Wrapped the SegmentedButton (Jobs filters: All | Active | Sched | Past) with Center + ConstrainedBox to maintain a stable control width and keep it centered. This prevents the slight horizontal size change you observed when switching filters, resulting from parent constraint recalculations.
- Job tiles already use a fixed 52×52 thumbnail and consistent paddings/margins, so no additional sizing adjustments were required. Each tile height remains consistent across filters.

Implementation details
- Code near the filter:
  Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      child: SegmentedButton<int>(...)
    )
  )
- The min/max width band ensures the filter does not grow/shrink subtly based on internal layout. The control remains centered within page padding, preserving visual consistency.

Why
- You requested: “the filter size and the jobs must be the same when filtering; make sure the filter is centered”. This change keeps the filter’s size stable and centered and preserves uniform tile sizing.

Backend/Integration impact
- None. Purely presentational.

QA Checklist
- Open Provider → Jobs.
  • The filter bar is centered and does not change width when switching among All, Active, Sched, Past. ✓
  • Job tiles maintain consistent height/spacing across filters. ✓
  • Dark mode and small devices render correctly; no overflow or clipping. ✓
