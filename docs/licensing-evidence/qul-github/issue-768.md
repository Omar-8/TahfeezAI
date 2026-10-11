# QUL issue #768: Licence for the mushaf layout resources (KFGQPC V1 / V2) — bundling in a free offline app

- URL: https://github.com/TarteelAI/quranic-universal-library/issues/768
- Opened by ZainulArkaanAlinsi on 2026-09-24T14:30:00Z; state: closed, closed 2026-09-27T07:52:40Z
- Retrieved through the GitHub API on 2026-10-11 (raw JSON beside this file).

## Question

Assalamu'alaikum,

Thank you for QUL — having the mushaf layout data gathered in one place is a
real service to everyone building Qur'an apps.

I am an independent developer working on Ruang Tilawah, a free Android app for
Indonesian users. It has no ads, no paywall and nothing for sale; it is handed
out as an APK through public GitHub releases. I would like to use QUL's mushaf
layout data so the app can show pages the way the printed mushaf lays them out,
and I want to get the permissions right before shipping anything.

What I would like to use:

  - KFGQPC V1 layout (1405H print) — /resources/mushaf-layout/15
  - KFGQPC V2 layout (1421H print) — /resources/mushaf-layout/10

How I would use it: download the SQLite file once, bundle it inside the app as
read-only data, and use the page and line records to render pages offline. I
would not re-publish the database as a downloadable dataset of its own, and I
would not sell it or charge for access to it.

My question comes from the FAQ, which says:

  "The resources available on QUL vary in their copyright status. Some are in
   the public domain, while others may be subject to specific licenses. We
   recommend reviewing the licensing information provided by each resource's
   author before use."

I have gone through the resource pages for both layouts above and could not find
any licensing information on them — there is no licence field, and none of the
mushaf-layout pages appear to carry one. I understand the MIT licence in the
repository covers the QUL software itself rather than the data.

So, concretely:

  1. Is there a licence or permission statement for these two layout resources
     that I have missed? If so, where can I read it?
  2. If there is none published, may these layout databases be bundled inside an
     application that is distributed free of charge, as described above?
  3. What attribution would you like displayed? I am happy to credit both
     QUL/Tarteel and the King Fahd Glorious Quran Printing Complex wherever you
     think is appropriate, and to link back to qul.tarteel.ai.
  4. Since the layouts originate with KFGQPC, is this something I should be
     asking them directly instead? If so, is there a contact you would suggest?

If there are conditions attached, I would rather hear them and follow them than
guess. If the answer is that the data should not be bundled, that is a clear
answer too and I will look elsewhere — I would simply rather not ship something
I do not have permission for.

Jazakumullahu khayran for your time and for the work you have put into QUL.

Wassalamu'alaikum,

Zainul Arkaan
Ruang Tilawah — https://github.com/ZainulArkaanAlinsi/Qur-an_App


## Comment by ZainulArkaanAlinsi (NONE) — 2026-09-27T07:37:25Z
Permalink: https://github.com/TarteelAI/quranic-universal-library/issues/768#issuecomment-5853869146

Assalamu'alaikum warahmatullahi wabarakatuh,

A short update on my request above, since a few things have changed:

New name: the app is now called MyQuran (same app as "Ruang Tilawah"). It is my personal student project and also part of my school coursework.

Distribution: besides GitHub releases, I now plan to publish it on Google Play. It will remain completely free there too: no fees, no ads, no subscriptions, no in-app purchases, no paid version, and no sale of user data. I receive no funding, sponsorship or payment of any kind from anyone for this app.

Nothing shipped yet: the mushaf page view is disabled in the published build (it shows "coming soon"), and no QUL layout data ships in any release until I hear back from you.

KFGQPC: I have also written to KFGQPC. At their request, I sent a formal letter addressed to their Secretary-General on 27 September 2026.

Terms I am happy to follow (please let me know if you need anything else):

Scope: the SQLite layout (V1 1405H or V2 1421H) is bundled read-only inside MyQuran only and is never re-published as a standalone dataset.

No changes: page, line and word positions are used as they are.
Attribution: QUL / Tarteel and KFGQPC credited on the app's "Sources & licences" page, with a link to qul.tarteel.ai and the resource version.
Free and non-commercial: the app stays free on Google Play and everywhere else; any change would need new permission first.
Corrections: updates you publish are pulled in within 14 days of release.
Withdrawal: if you ask me to stop, the data is removed in the next update, within 14 days.
No endorsement: no claim that Tarteel endorses the app, and no use of your logo.

My four questions above still stand. If it helps, you can try the app here:

Demo build (direct download of the latest APK, Android 7.0+, ~46 MB): 
https://github.com/ZainulArkaanAlinsi/Qur-an_App/releases/latest/download/myquran.apk

JazakAllahu khairan for your time and for QUL.

Zainul Arkaan
