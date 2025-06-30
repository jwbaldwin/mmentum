# Mmentum Development Roadmap

## Vision
A clean, modern, minimal UX-focused habit builder that helps users build momentum through "smaller amounts of effort, displaced over more time."

## Current State Analysis

### ✅ What's Working
- Clean, minimal UI with progress visualization (circles + connecting lines)
- Basic habit CRUD (create, edit, delete)
- Simple increment/decrement logging system
- User authentication system
- Time-aware greetings and day info
- Periodicity support (day/week/month) - though implementation seems incomplete

### ❌ Key Issues Found
- ~~No streak tracking~~ ✅ **REPLACED WITH MOMENTUM SYSTEM**
- No momentum visualization
- Cannot log more habits than the defined X per Day/Week/Month
- No progress analytics or insights
- Missing habit completion states
- No habit categories or organization
- Limited user onboarding experience

## Development Phases

### Phase 1: Core Momentum Features (2-3 weeks)
**Goal:** Fix fundamental functionality and add core momentum tracking

1. **Fix Periodicity Logic** ✅ **COMPLETED**

2. **Momentum Score System** ✅ **COMPLETED** *(Replaced Streak Tracking)*

3. **Habit Completion States** 🔄 **NEXT UP**
   - Visual feedback when habits are completed for the current period
   - Beautiful animations for completions
   - Integration with momentum system for enhanced feedback
   - Add notes to log entries

4. **Progress Analytics**
   - Simple completion percentages per habit
   - ✅ Momentum indicators (current score)
   - Weekly/monthly completion rates
   - Momentum trend analysis and decay visualization (momentum curves)
   - Github-like contribution graph

### Phase 2: Enhanced UX (2-3 weeks)
**Goal:** Improve user experience and reduce friction

5. **Improved Onboarding**
   - Guided habit creation flow
   - Examples of good habits with recommended frequencies
   - Best practices tips during setup

6. **Habit Templates**
   - Pre-built habit suggestions
   - One-click habit creation from templates

7. **Better Mobile Experience**
   - Touch-optimized increment/decrement controls
   - Responsive design improvements
   - Swipe gestures for quick actions

8. **Habit Reordering**
   - Drag & drop reordering
   - Priority/importance ordering
   - Custom habit grouping

### Phase 3: Retention Features (2-3 weeks)
**Goal:** Keep users engaged and motivated long-term

9. **Habit Insights**
   - Weekly progress reports
   - Monthly momentum summaries
   - Trend analysis and patterns

10. **Motivational Elements**
    - Encouraging messages based on momentum tiers
    - Milestone celebrations (momentum milestones, tier achievements, etc.)
    - Momentum-building tips and quotes
    - Dynamic feedback based on momentum decay/growth

11. **Habit History**
    - Calendar view of past performance
    - Historical momentum score tracking
    - Progress over time visualization with momentum curves

12. **Export/Backup**
    - CSV export of habit data
    - JSON backup for data portability
    - Import functionality for data migration

### Phase 4: Growth Features (3-4 weeks)
**Goal:** Advanced features for power users and growth

13. **Habit Categories**
    - Group related habits (Health, Productivity, Personal, etc.)
    - Category-based progress tracking
    - Visual organization improvements

14. **Smart Suggestions**
    - Recommend optimal habit frequency based on user patterns
    - Suggest habit adjustments for better success rates
    - AI-powered momentum insights

15. **Social Features** (Optional)
    - Habit sharing with friends/family
    - Accountability partners
    - Community challenges

16. **API/Integrations**
    - REST API for third-party integrations
    - Webhook support for external triggers
    - Connect with fitness trackers, calendars, etc.

## Technical Priorities

### Immediate Fixes Needed
- [x] Fix periodicity logic in `Habits.list_habits_with_range/2`
- [x] Update UI to respect habit periodicity settings
- [x] Fix user fixture missing `full_name` field in tests
- [ ] Fix broken routes in tests (logs routes not implemented)
- [ ] Resolve Gettext deprecation warnings

### Architecture Improvements
- [x] ~~Add proper streak tracking to database schema~~ **REPLACED WITH MOMENTUM SYSTEM**
- [x] Implement momentum score calculation and tracking infrastructure
- [ ] Implement habit state machine for completion tracking
- [ ] Add analytics/metrics tracking infrastructure
- [ ] Improve error handling and user feedback

## Success Metrics

### Phase 1 Success Criteria
- [x] All periodicity options work correctly
- [x] ~~Users can see their current streaks~~ **UPGRADED TO MOMENTUM SYSTEM**
- [x] Users can see their momentum scores and tiers with visual indicators
- [ ] Habit completion is visually clear
- [x] Basic progress tracking is functional (momentum-based)

### Long-term Success Metrics
- User retention: 70% weekly active users
- Habit completion rate: 60% average across all users
- User engagement: Average 2+ habits per user
- Growth: 20% month-over-month user growth

## Next Steps

## Recent Progress

### ✅ Completed: Fix Periodicity Logic (Phase 1, Item 1)
- **Fixed:** `Habits.list_habits_with_range/2` now respects individual habit periodicity
- **Added:** New `list_habits_with_range/1` function that loads logs based on each habit's specific period
- **Updated:** UI now displays habit periodicity information (e.g., "3 times per week (2/3 this week)")
- **Improved:** Habit display shows current progress within the correct time period

### ✅ Completed: Momentum Score System (Phase 1, Item 2) - *Major Upgrade*
- **Replaced:** Binary streak tracking with continuous momentum scoring (0-100)
- **Implemented:** Exponential decay algorithm with configurable half-life per habit periodicity
- **Added:** Completion boost with diminishing returns to prevent system gaming
- **Created:** Four-tier momentum system: "On Fire 🔥" (80-100), "Rolling" (50-79), "Warming Up" (20-49), "Cooling Off" (0-19)
- **Built:** Database schema with momentum fields: `momentum_score`, `momentum_last_updated`, `momentum_half_life_days`, `momentum_boost_amount`
- **Enhanced:** UI displays real-time momentum scores with color-coded tier indicators and emojis
- **Developed:** Comprehensive test suite covering all momentum calculation scenarios
- **Configured:** Smart defaults: Daily habits (1-day half-life), Weekly habits (6-day half-life), Monthly habits (18-day half-life)

### 🔄 Next Priority: Habit Completion States (Phase 1, Item 3)
Add visual feedback for habit completion status and celebration animations to enhance user motivation. Now enhanced with momentum-aware feedback.

**Key Innovation:** The momentum system provides a more nuanced and motivating representation of habit consistency than binary streaks. Users see their "momentum" naturally decay over time, encouraging consistent engagement while being forgiving of occasional misses. The diminishing returns system prevents gaming while the tier system provides clear, visual feedback on progress.
