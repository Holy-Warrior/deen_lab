# DeenLab

DeenLab is a mobile app of Islamic daily-practice tools — prayer times, Qibla direction, Quran,
duas, Sehri & Iftari timings, and a Feature Studio that builds small extra tools on request.

It has been written twice. The Flutter version came first; the Tauri version is a rewrite of the
same idea on a different stack. Both of them work, so both are kept here rather than one
replacing the other.

## The two apps

| App | Stack | Directory |
| --- | --- | --- |
| Flutter | Flutter / Dart, with Android-native Kotlin | [`flutter-app/`](flutter-app/) |
| Tauri | Tauri v2 / Rust, with SvelteKit 5 and Tailwind 4 | [`tauri-app/`](tauri-app/) |

Each app also has a branch holding only that app, for when checking out both is not wanted:

- `flutter-app-deen-lab`
- `tauri-app-deen-lab`

## How the two differ

The Tauri version is a rewrite rather than a straight port, and it is not finished:

- **Not carried over yet** — prayer reminders, and the Silence of Salah engine that mutes the
  phone during salah. That engine is an Android foreground service kept in its own repository,
  [silence_of_salah_engine](https://github.com/Holy-Warrior/silence_of_salah_engine), and so far
  only the Flutter app is wired up to it.
- **Deliberately dropped** — the Hadith library. Its translations could not be licensed for
  redistribution, so the feature was removed instead of shipped on unclear terms. The Flutter
  app no longer ships the database either; its `lib/features/hadees/` code is left in place,
  unused, in case the content is ever replaced with a source that can be shared.
- **Rebuilt, not ported** — the Feature Studio. Both versions turn a plain-English description
  into a small tool, but the Tauri one runs each generated tool in a sandbox, keeps every
  version, and can revise a tool after it has been made.

Prayer times, Qibla, Quran, duas and Sehri & Iftari exist in both.

## Building either one

Each app carries its own setup instructions:

- [`flutter-app/README.md`](flutter-app/README.md)
- [`tauri-app/README.md`](tauri-app/README.md)

Both apps read a Groq API key from a gitignored config file for their Feature Studio tool, and
neither will compile until that file exists — each app's README says which template to copy.
Nothing in this repository uses Git LFS.

## License

Proprietary. All rights reserved.
