# PicklePark — Privacy Policy, Terms of Use & Community Guidelines

**Effective Date:** October 19, 2026  
**Developer:** Dominic Soriano

---

## 1. Overview
**PicklePark** ("the App") is a free community utility app built for pickleball players at Washington Park (850 Burlingame Ave, Burlingame, CA). We do not require user accounts, emails, phone numbers, or personal registration to use any feature of the App.

---

## 2. Zero Personal Data Collection ("Data Not Collected")
PicklePark is architected for maximum user privacy (`NSPrivacyTracking = false`, `NSPrivacyCollectedDataTypes = []`):
- **No Accounts or Personal Identifiers:** You never provide a name, email address, phone number, Apple ID, or device identifier (`IDFA` / `IDFV`) to use the App.
- **No Location Tracking:** The App fetches live weather and EPA Air Quality Index (AQI) data using Washington Park's fixed public coordinates in Burlingame, CA (`37.5779° N, 122.3481° W`). The App never requests or accesses your device GPS location.
- **Anonymous Community Court & Lost-and-Found State:** Voluntary court occupancy updates and Lost & Found board items are shared anonymously as public park state. Optional Lost & Found photos are re-rendered on-device into a clean bitmap prior to upload, automatically stripping all camera EXIF and GPS metadata.
- **No Tracking, Analytics, or Selling of Data:** We include zero third-party analytics or advertising SDKs, never track users across apps or websites, and never sell or rent data.

---

## 3. User-Generated Content & Community Safety (Zero-Tolerance Policy)
In compliance with Apple App Store Review Guideline 1.2, PicklePark enforces a strict **zero-tolerance policy** for objectionable content, profanity, harassment, or abusive behavior:
1. **Automated On-Device Moderation:** All text submissions and uploaded Lost & Found photos are automatically screened on-device using text filters and Apple Vision (`VNRecognizeTextRequest`) optical character recognition prior to publication.
2. **One-Tap Reporting ("Flag Inappropriate Content"):** Every Lost & Found item and Community Board post includes a **Flag** button that immediately hides the reported post from your feed and flags it for moderator removal.
3. **One-Tap User Blocking ("Block User & Hide Their Posts"):** Users can immediately block any author from the Flag menu, instantly removing all posts from that user across the App.
4. **24-Hour Moderator Review:** Flagged content is reviewed by the developer within 24 hours and permanently deleted from CloudKit.

---

## 4. Contact & Support
For support, bug reports, feature requests, or content removal inquiries:
- **GitHub Issues / Support Portal:** [https://github.com/osodoso1/washing_park/issues](https://github.com/osodoso1/washing_park/issues)
- **Developer Contact:** Dominic Soriano (`dominicsoriano@gmail.com`)
