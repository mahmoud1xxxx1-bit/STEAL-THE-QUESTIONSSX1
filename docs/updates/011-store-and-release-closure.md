# UPDATE 011 — STORE + RELEASE CLOSURE

## Verified question bank
- 222 question/card entries are implemented.
- Source catalog contains 74 fact entries.
- Each fact generates 3 distinct question variants: 74 × 3 = 222.
- Card IDs are Q001 through Q222.
- Rarity contract remains 150 EPIC, 50 GOLD, 22 LEGENDARY.

## Weekly Pass store
- The product remains the only paid product: `weekly_pass_v1`.
- Store UI now reads the real localized product title, description, and price from the platform store.
- Web preview no longer presents store unavailability as a purchase error; it clearly states that IAP is mobile-only.
- Purchase and restore flows are separated.
- A purchase is completed only after server verification succeeds.
- Failed/canceled/pending purchases are not silently marked as delivered.

## Server verification
### Google Play
- Server verifies the subscription token against Google Play Developer API.
- Product ID and package name are checked.
- Active/grace-period entitlement and future expiry are required.
- Pending purchases are acknowledged.
- The entitlement is recorded server-side to prevent replay or claiming the same transaction on another account.

### Apple
- Server verifies the transaction through the App Store Server API.
- The bundle ID and product ID are checked.
- Future expiry and absence of revocation are required.
- Production is tried first, then sandbox for test transactions.
- The transaction is recorded server-side to prevent replay.

## Required external store configuration
These values must be configured in Firebase Secret Manager before real-store verification can succeed:
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- `APPLE_ISSUER_ID`
- `APPLE_KEY_ID`
- `APPLE_PRIVATE_KEY`

The mobile app store product must also be created in Google Play Console and App Store Connect with the exact product ID `weekly_pass_v1`.

No credentials are fabricated or stored in Git.

## Remaining platform release requirement
The repository currently contains the Flutter application and web preview. Android/iOS store console records and signing credentials are external release configuration, not source-code values.
