# HeyListen

**Mirrors ready checks and whispers from one WoW account to another**, so you never miss them while alt-tabbed away or playing without sound on your second account.

## Why

If you multi-box two accounts on TBC Classic — boosting one character with the other, while you raid / farm / level the other manually — you've probably missed a ready check after a boost run, or a whisper while focused on the other window. **HeyListen** mirrors those events from one account to the other, in-game, with a clear visual + audio alert.

- **Ready check** → full-screen red flash on the receiving account
- **Whisper** → toast notification (sender + message), top-right corner, movable

No external tools. No background daemon. Pure Lua addon — communication runs entirely inside WoW over the standard addon-message channel.

## Requirements

- TBC Classic / Anniversary (Interface `2.5.x`)
- Both characters must be on the **same realm** and **same faction** (TBC whisper limitation)
- Addon installed on **both** accounts

## Installation

Install via your addon manager (CurseForge app, etc.), or unpack into the AddOns folder:

```
World of Warcraft/_classic_/Interface/AddOns/HeyListen/
```

For Anniversary realms:

```
World of Warcraft/_anniversary_/Interface/AddOns/HeyListen/
```

## Setup

After install, log in on **each** account and pair it to the other character:

```
/hey <Charname-Realm>
```

Example with two characters `Stroetroll` (Account A) and `Andryusha` (Account B), both on realm `Spineshatter`:

- On Account A: `/hey Andryusha-Spineshatter`
- On Account B: `/hey Stroetroll-Spineshatter`

Verify with `/hey test` from either side — the other account should see a green TEST toast.

## Commands

All commands also work with `/heylisten` and `/hl` as aliases.

| Command | What it does |
|---|---|
| `/hey <Name-Realm>` | Set the mirror partner (shorthand) |
| `/hey pair <Name-Realm>` | Set the mirror partner |
| `/hey unpair` | Clear partner |
| `/hey status` | Show current partner and state |
| `/hey test` | Send a test signal to the partner |
| `/hey mute` | Toggle sound on/off for received alerts |
| `/hey move` | Toggle drag mode to reposition the toast stack |

## Limitations

- TBC Classic does not allow cross-realm whispers, so both characters must share a realm.
- Whispers **from** your partner **to** you are not mirrored back (prevents loops).
- If the partner character is offline when an event fires, the message is silently dropped — the addon-message API in TBC does not report delivery failures back to the sender.
- Whisper text longer than ~200 bytes is split into multiple addon messages and reassembled on the receiving side. Very long whispers (multi-paragraph) work but arrive after a brief delay.

## License

MIT — see [LICENSE](LICENSE).

## Author

Stroe-Spineshatter
