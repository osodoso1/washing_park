# PicklePark — App Store Connect & TestFlight Complete Distribution Kit

This document contains every field, description, privacy declaration, and App Store Reviewer note needed for **immediate approval** on both **TestFlight External Beta Review** and **App Store Distribution**.

---

## 1. TestFlight Beta App Review Information (For Immediate Public Link Approval)

Copy and paste these exact values into **App Store Connect → TestFlight → Beta App Information & Beta App Review Information**:

* **Beta App Description**:
  > PicklePark is a free, ad-free community companion app for Washington Park Pickleball & Tennis Courts in Burlingame, CA. Players can view live City of Burlingame court reservations (Courts 2 & 3), crowdsource open-play paddle queue counts on Court 1, check estimated wait times modeled on a 15-minute doubles game, track on-court doubles rotations with PickleMatch, and report or claim items on the Washington Park Lost & Found board.

* **What to Test (TestFlight Beta Build Notes)**:
  > Welcome to PicklePark for Washington Park (Burlingame, CA)!
  > 1. Live Court Activity & Walk-On Status: Report active courts (0–4), paddle queue count, and Courts 2 & 3 walk-on availability.
  > 2. Estimated Wait Time Tab: View real-time wait estimates (triggered when all 4 permanent courts are full) and hourly wait trends built 100% from real player reports.
  > 3. Washington Park Lost & Found: Tap the box icon at the top next to Clubhouse Info to post or claim lost paddles, water bottles, and gear with photos, timestamps, and automated safety moderation.
  > 4. PickleMatch Doubles Companion: Generate balanced doubles rotations and track scores court-side.

* **Feedback Email**: `dominicsoriano@gmail.com` *(or your preferred email)*
* **Marketing URL**: `https://www.burlingame.org/rec` *(or your GitHub Pages / web URL)*
* **Privacy Policy URL**: *(See Hosted Privacy Policy text below)*
* **Sign-In Required**: **NO** (Uncheck `"Sign-in required"` — all features work immediately upon launch without an account or login).
* **Notes for Beta App Reviewer**:
  > No login or account creation is required to use any feature of PicklePark.
  > - All features are immediately accessible from the main dashboard.
  > - User-generated content (Lost & Found listings and Community Suggestions) complies with App Store Review Guideline 1.2:
  >   1. Automated on-device text profanity filtering (`ContentModerator`) and Apple Vision OCR + visual safety scanning (`LostAndFoundSafetyScanner`) automatically screen all submissions.
  >   2. Every user-generated post includes an immediate 1-tap "Flag Inappropriate Content" action and "Block User & Hide Their Posts" action.
  >   3. Flagged content is immediately hidden from the public feed and routed to the app owner's moderation queue.
  > - Camera and Photo Library permissions are used solely when a player chooses to attach a photo of a lost or found item at Washington Park.

---

## 2. Full App Store Listing Metadata (Copy-Paste Ready)

* **App Name**: `PicklePark: Washington Park`
* **Subtitle (30 chars max)**: `Burlingame Courts & Queue`
* **Primary Category**: `Sports`
* **Secondary Category**: `Lifestyle` (or `Utilities`)
* **Keywords (100 chars max)**:
  `pickleball,burlingame,washington park,courts,paddle queue,wait time,tennis,open play,picklematch`
* **Promotional Text (170 chars max)**:
  `Check live Washington Park pickleball court availability, real-time paddle queue wait times, City of Burlingame court schedules, and court-side Lost & Found—100% free.`

### App Store Description
```text
PicklePark is the all-in-one community court companion built specifically for Washington Park Pickleball & Tennis Courts in Burlingame, California.

Whether you're heading out for morning open play on Court 1 (4 permanent pickleball courts) or checking if Courts 2 & 3 are open for walk-on play between City reservations, PicklePark gives you live, community-powered court intelligence before you leave home.

KEY FEATURES:

• LIVE COURT & PADDLE QUEUE FEED
See how many of Court 1's 4 permanent pickleball courts are in use, how many paddles are waiting in the rotation queue, and how many walk-on pickleball courts are open on Courts 2 & 3. Submit a live update from the park to earn Community Leaderboard points!

• REAL-TIME ESTIMATED WAIT TIME & HOURLY TRENDS
Know before you go. Once all 4 permanent courts are filled, PicklePark calculates the estimated wait time using standard doubles rotation math (~15-minute average game to 11 points across 4 courts, or ~3.75 minutes per 4-paddle rack) and builds an interactive hourly wait-time graph from 100% real player reports.

• OFFICIAL CITY OF BURLINGAME RESERVATION SCHEDULE
View Today, 7-Day, and Monthly reservation schedules for Courts 2 & 3 synced with the City of Burlingame Parks & Recreation calendar, plus 1-tap access to reserve available slots on WebTrac.

• WASHINGTON PARK LOST & FOUND BOARD
Left a paddle, water bottle, or jacket by the courts? Snap a photo to post lost or found gear with exact "Lost / Reported" and "Marked Found" timestamps, court location tags, and item descriptions. Protected by automated on-device text and photo safety moderation.

• PICKLEMATCH DOUBLES ROTATION & SCORE TRACKER
Running a group session? Enter your players and let PickleMatch generate fair doubles matchups, manage the sitting queue, and track live game scores right at the net.

• LIVE COURT WEATHER, AQI & CLUBHOUSE HOURS
Check real-time Burlingame court temperature, wind speed, Air Quality Index (AQI), Clubhouse hours (8 AM–7 PM), and court light hours (until 10 PM) at a glance.

100% Free. No Ads. No Account Required. Built for the Burlingame pickleball community.
```

---

## 3. App Store Reviewer Notes (Guideline-by-Guideline Instant Approval)

Paste this into the **App Review Information → Notes** box in App Store Connect:

```text
Thank you for reviewing PicklePark!

1. NO LOGIN REQUIRED (Guideline 2.1):
All features of the app are unlocked and immediately testable upon launch without any sign-in or account creation.

2. USER-GENERATED CONTENT COMPLIANCE (Guideline 1.2):
PicklePark includes community court status reports, a Lost & Found board, and a Community Suggestions board. We strictly enforce all four requirements of Guideline 1.2:
• Community Guidelines Notice: Displayed prior to posting any content (zero tolerance for objectionable content or abusive behavior).
• Automated Content Filtering: All text is screened through our on-device ContentModerator profanity/abuse filter, and all Lost & Found photos are scanned on-device using Apple Vision (VNRecognizeTextRequest OCR + visual safety heuristics) prior to display.
• Immediate Reporting / Flagging: Every Lost & Found listing and Community Suggestion has a "Flag Inappropriate Content" button that immediately hides the content from the feed and flags it for moderator removal.
• Blocking Abusive Users: Every Lost & Found listing and Community Suggestion includes a "Block User & Hide Their Posts" action that immediately removes all posts from that author.

3. HARDWARE PERMISSIONS (Guideline 5.1.1):
• Camera & Photo Library: Used exclusively when a user voluntarily taps "Post Lost or Found Item" in the Lost & Found sheet to attach a photo of a lost paddle, water bottle, or piece of gear.

4. EXTERNAL LINKS:
• The "Reserve Courts 2 & 3 on WebTrac" button opens the official City of Burlingame Parks & Recreation reservation portal (burlingame.org/rec).
• A voluntary "Buy me a coffee" external link opens in external mobile Safari for users who wish to tip the developer; no in-app digital features or content are gated behind it (Guideline 3.1.1 / 3.2.2).
```

---

## 4. App Store Connect Privacy Questionnaire & Age Rating

### App Privacy ("Data Not Linked to You")
When filling out the **App Privacy** section in App Store Connect:
1. **Do you or your third-party partners collect data from this app?** $\rightarrow$ **Yes**
2. **Data Types Collected**:
   - **User Content → Photos or Videos** *(Optional Lost & Found item photos submitted by users; Not Linked to User; Not Used for Tracking; Used for App Functionality)*
   - **User Content → Other User Content** *(Optional court status updates, Lost & Found descriptions, and anonymous feedback; Not Linked to User; Not Used for Tracking; Used for App Functionality)*
3. **Do you use data for tracking purposes?** $\rightarrow$ **No**

### Age Rating Questionnaire (`4+` or `9+`)
- Cartoon or Fantasy Violence: **None**
- Realistic Violence: **None**
- Sexual Content or Nudity: **None**
- Profanity or Crude Humor: **None**
- Alcohol, Tobacco, or Drug Use: **None**
- Simulated Gambling: **None**
- Unrestricted Web Access: **No**

---

## 5. Privacy Policy & Support Text (Copy-Paste to Any URL / GitHub Page)

```markdown
# PicklePark Privacy Policy & Community Guidelines
Effective Date: October 19, 2026

## 1. Overview
PicklePark ("the App") is a free community utility app for Washington Park Pickleball & Tennis Courts in Burlingame, CA. We do not require user accounts, emails, phone numbers, or personal registration.

## 2. Information We Collect
- **Voluntary Court & Queue Reports**: When you submit court occupancy or paddle queue counts, the report timestamp and court numbers are shared via Apple CloudKit to calculate live and hourly wait times for players.
- **Voluntary Lost & Found & Feedback Posts**: If you post a lost or found item (including an optional photo) or a community suggestion, that post is displayed on the community board.
- **No Tracking or Selling of Data**: We do not collect device identifiers for advertising, do not use third-party analytics trackers, and never sell user data.

## 3. Content Moderation & Community Safety (Zero Tolerance Policy)
PicklePark enforces a strict zero-tolerance policy for objectionable content or abusive users:
- All text and photos are automatically screened on-device for inappropriate content prior to publication.
- Users can flag any post or block any user with one tap, which immediately removes the content from their feed and alerts the moderator.
- The developer reviews flagged content within 24 hours and permanently removes offending material.

## 4. Contact & Support
For questions, support, or content removal requests, please contact:
Dominic Soriano — dominicsoriano@gmail.com
```
