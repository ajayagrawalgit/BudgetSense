<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/brand/budgetsense-logo-inverse-on-dark.png" />
  <source media="(prefers-color-scheme: light)" srcset="docs/assets/brand/budgetsense-logo-primary-on-light.png" />
  <img src="docs/budgetsense_logo.png" width="150" alt="The BudgetSense mark: a hand-inked ensō brush circle with a single clay-coloured dot where the brush lifts away" />
</picture>

# BudgetSense

**Money, minus the anxiety.**

A quiet little notebook for your money, living on your phone.

<img src="docs/assets/brand/budgetsense-underline-terracotta.webp" width="220" alt="" />

<br />

<a href="https://github.com/ajayagrawalgit/BudgetSense/releases/latest">
  <img src="https://img.shields.io/badge/%E2%AC%87%EF%B8%8F%20Download%20for%20Android-BudgetSense%200.1-B07C5E?style=for-the-badge&logo=android&logoColor=white" alt="Download BudgetSense 0.1 for Android" />
</a>

<br />
<br />

<img src="https://img.shields.io/badge/free-forever-6E8B6A?style=flat-square" alt="Free forever" />
<img src="https://img.shields.io/badge/no-ads%20%C2%B7%20no%20accounts%20%C2%B7%20no%20tracking-5A4A3C?style=flat-square" alt="No ads, no accounts, no tracking" />
<img src="https://img.shields.io/badge/works-offline-262219?style=flat-square" alt="Works offline" />

<br />

<sub>
  <a href="https://ajayagrawalgit.github.io/BudgetSense/">Website</a>
  &nbsp;·&nbsp;
  <a href="PRIVACY.md">Privacy</a>
  &nbsp;·&nbsp;
  <a href="docs/DATA_RECOVERY.md">Your data</a>
  &nbsp;·&nbsp;
  <a href="CONTRIBUTING.md">Contributing</a>
</sub>

</div>

<br />

<div align="center">
  <img src="docs/assets/brand/budgetsense-divider.webp" width="100%" alt="" />
</div>

<br />

## Hello

You know that feeling when you get to the end of the month and the money is just gone, and you genuinely cannot say where? Not in a dramatic way. You didn't do anything reckless. It just quietly leaked out through a hundred small taps you never wrote down.

BudgetSense is where you write them down.

It's a journal, really. You open it, you jot down what came in and what went out, and you close it. Over a few weeks those little notes turn into something honest: the actual shape of your month, in your own handwriting, so to speak. No red warnings. No cheerful robot telling you to cut back on coffee. Nothing gets uploaded anywhere, because there's nowhere to upload it to. It's your notebook, sitting on your phone.

And if you're already the sort of person who keeps a note somewhere with rent, the gym, that streaming thing you keep meaning to cancel, your SIPs, the EMI, the money you lent your cousin in March, then this is the place all of that finally belongs. Recurring payments roll themselves forward, so once you've told BudgetSense about your rent you never type it again. Mark it paid, and the entry writes itself. Loans keep track of what's left. Your investments sit alongside your spending instead of in a separate app you forget to open.

That's it. That's the whole thing. A calm place to put your numbers, so they stop living in your head.

<br />

## Getting it on your phone

Takes about two minutes.

**1.** Open [the latest release](https://github.com/ajayagrawalgit/BudgetSense/releases/latest) on your phone and tap the APK to download it.

**2.** Open it, from the download notification or your Files app.

**3.** Android will probably say *"For your security, your phone can't install unknown apps from this source."* That's completely normal for anything that doesn't come from the Play Store. Tap **Settings**, turn on **Allow from this source**, tap **Back**, then **Install**.

**4.** Open it and start writing. There's no sign-up, no email, no "create your account" screen. It's just there.

> **On an iPhone?** Not yet, sorry. The app builds and runs on iOS, but getting it onto the App Store is a whole different mountain. For now it's Android.

Want to be careful about what you're installing? Every release lists a checksum you can compare against your download. [Here's how to check it](docs/getting-started/verify.md).

<br />

<div align="center">
  <img src="docs/assets/brand/budgetsense-divider.webp" width="100%" alt="" />
</div>
<br />

## What it's like to use

**It stays quiet.** Your balance sits at the top and everything else is folded away until you go looking for it. No dashboard screaming eleven numbers at you the moment you open it.

**Writing something down takes seconds.** One sheet handles money in, money out, investments, and transfers between your own accounts. Start typing "coffee" and it quietly finds the coffee cup icon for you. Small thing, but it makes the whole business feel less like data entry.

**The repeating stuff looks after itself.** Rent, subscriptions, SIPs, EMIs, the yearly insurance you always forget. Tell BudgetSense once. When it's due, mark it paid and the transaction is written and the date moves along on its own. Loans quietly count down what you still owe.

**It notices things, gently.** How your spending is trending, which categories are eating the most, how much you're actually keeping, roughly where the month will land if you carry on at this pace. These are just descriptions of what you already wrote down. It isn't predicting your future or telling you what to do with your money.

**It looks the way you want.** Light, dark, true black for AMOLED screens, and a transparent glass theme. Six accent colours and six typefaces, including a few handwritten ones. Make it yours.

**One tap hides everything.** Tap the eye and every number blurs. Handy when someone's reading over your shoulder on the train.

**It locks properly.** Uses your phone's own fingerprint, face, or PIN. Blocks screenshots by default and hides your numbers on home screen widgets while it's locked.

**Deleting isn't final.** Swipe something away and you get ten seconds to undo. Miss the window, and it's still sitting in the Trash in Settings waiting for you.

**Widgets, if you like them.** Eleven of them, from your balance or dashboard to a no-spend streak, what's due next, or a single tap to add something without opening the app.

**Your data leaves with you.** One tap writes a single file with everything in it, right down to your trash and your theme. It's yours to keep, move, or delete.

<br />

## Where your money notes actually live

On your phone. That's the honest answer.

Everything you write goes into a small database on your own device. There is no BudgetSense server. I'm not holding your numbers, because I never receive them. There's no account to make, no analytics watching which buttons you press, and no crash reporting quietly shipping things off in the background.

One feature can use the internet, and it's switched off until you decide otherwise. If you turn on **Google Drive backup**, your data is encrypted on your phone first, with a passphrase only you know, and only the scrambled file goes to your own Drive. The passphrase never leaves your device. That does mean if you forget it, nobody can rescue that backup, including me. That's the tradeoff for it being genuinely private.

There's also no updater built into the app. It can't download or install anything on its own, and it doesn't have permission to. New versions come from the releases page when you go and get them.

One more thing worth being straight about: the database on your phone isn't separately encrypted by the app. It relies on Android keeping other apps out of it and on your phone's own disk encryption. On a locked, ordinary phone that's fine. On a rooted or unlocked one, it isn't a serious defence.

[The privacy page](PRIVACY.md) spells all of this out properly, including exactly what's in a backup file and how to wipe everything.

<br />

## A gentle disclaimer

BudgetSense helps you organise and keep track of your own budgeting. That's the entire job.

It isn't financial, investment, tax, or accounting advice. It isn't a bank and it isn't any kind of financial service. It can't promise you'll save money, and it won't pretend to. Using it is completely optional, you can stop whenever you like and take everything with you, and every decision about your money stays yours. If you need real advice, please talk to someone qualified.

<br />

<div align="center">
  <img src="docs/assets/brand/budgetsense-divider.webp" width="100%" alt="" />
</div>

<br />

## The look of it

The whole app grew out of one small drawing: an *ensō*, the brush circle you make in one breath, with a single clay-coloured dot where the brush lifts away. It felt calm and complete, and it hints at a coin without looking anything like a bank.

<div align="center">

| | |
|:--|:--|
| **Paper** | warm cream `#F3ECDE`, never a harsh white |
| **Ink** | deep espresso `#262219`, never pure black |
| **Clay** | one warm accent, `#B07C5E` |

</div>

Everything else follows from those three. If you're curious about the full visual system, it's written up in [DESIGN.md](docs/DESIGN.md).

<br />

## If you'd like to poke around the code

BudgetSense is written in Flutter and all of it is here to read.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

You'll want Flutter 3.44.4, Dart 3.12.x, JDK 21, and the Android SDK. [CONTRIBUTING.md](CONTRIBUTING.md) has the fuller setup and the checks your changes need to pass. [ARCHITECTURE.md](docs/ARCHITECTURE.md) is the map if you want to understand how the pieces fit together before changing anything.

Bug reports and pull requests are genuinely welcome. Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md), which is the short and obvious kind. If you've found a security problem, please don't open a public issue, [SECURITY.md](SECURITY.md) has a quieter way to reach me.

<br />

## Who made this

Hi, I'm **Ajay Agrawal**. I built BudgetSense because I wanted it to exist and nothing quite like it did.

[GitHub](https://www.github.com/ajayagrawalgit) &nbsp;·&nbsp; [LinkedIn](https://www.linkedin.com/in/theajayagrawal)

The handwritten and interface typefaces come from Google Fonts under the SIL Open Font License 1.1, with the details in [assets/fonts/README.md](assets/fonts/README.md).

<br />

## License

BudgetSense is free software under the GNU General Public License v3.0. Use it, read it, change it, share it. If you distribute a changed version it stays GPL-3.0 with the source available. It comes with no warranty. Full text in [LICENSE](LICENSE).

Copyright © 2026 Ajay Agrawal.

<br />

<div align="center">
  <img src="docs/assets/brand/favicon-192.png" width="56" alt="" />
  <br />
  <br />
  <sub><i>Write it down. Then go live your life.</i></sub>
</div>