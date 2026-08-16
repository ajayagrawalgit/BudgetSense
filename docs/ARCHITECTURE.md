<h1 align="center">BudgetSense: Architecture</h1>

<p align="center"><em>How the pieces fit together: layers, modules, data flow, and the database.</em></p>

---

This is the map. If [SPEC.md](SPEC.md) is the full instruction manual and
[DESIGN.md](DESIGN.md) is the style guide, this doc is the "here's how it all
hangs together" tour. The diagrams are [Mermaid](https://mermaid.js.org/), so
they render right here on GitHub. Each one has a plain-English note above it in
case you're reading somewhere Mermaid doesn't work.

The whole thing is one Flutter codebase for Android and iOS. It leans on a
clean, layered setup: a pure logic core with no Flutter or database code in it,
a data layer that owns storage, an app layer that wires everything up and
handles routing, and a stack of screens on top. It's offline-first, so all the
state sits in SQLite on the device. Optional Google Drive backup sits on top of
that as an opt-in layer, uploading only an encrypted snapshot, so the offline
path stays the default and works unchanged when cloud backup is off.

---

## 1. The layers

One rule keeps this whole thing honest: dependencies point inward. Screens and
the app layer lean on `data` and `domain`; `data` leans on `domain`; `domain`
leans on nothing but plain Dart. The UI never pokes at the database directly. It
goes through Riverpod providers, which hand back repositories and pure logic
services.

```mermaid
graph TD
    subgraph UI[" features (the screens)"]
        DASH[Dashboard]
        EXP[Expenses]
        PAY[Payments]
        INS[Insights]
        SET[Settings + Trash]
        ONB[Onboarding]
        SEC[Security / Lock]
        WID[Home-screen Widgets]
        COMMON[common calm widgets<br/>CalmCard, CollapsibleCard, StatTile, IconPicker]
    end

    subgraph APP[" app (where it's all wired up)"]
        ROUTER[router.dart<br/>GoRouter shell]
        DI[providers.dart /<br/>feature_providers.dart<br/>Riverpod DI graph]
        THEME[Theme wiring<br/>ThemeResolver, AppThemeBuilder]
    end

    subgraph DOMAIN[" domain (pure logic, zero Flutter)"]
        ENT[entities<br/>TransactionEntity, Loan, RecurringPayment, ...]
        SUMS[SummaryService]
        THS[ThresholdService]
        RECS[RecurrenceService]
        INSS[InsightsService]
        REMS[ReminderPlanner]
        SNAPI[SnapshotService<br/>interface]
    end

    subgraph DATA[" data (storage and IO)"]
        REPOS[Repositories<br/>Transaction, Loan, RecurringPayment, ...]
        DBASE[(Drift AppDatabase<br/>SQLite, 11 tables, v3)]
        SNAP[AppSnapshotService<br/>JSON / CSV / XML]
        PAISA[Paisa Importer]
        MAP[Mappers<br/>row to entity, and back]
    end

    subgraph CORE[" core (shared bits)"]
        MONEY[Money<br/>integer minor units]
        CAL[FinancialCalendar]
        ICONS[category_icons +<br/>IconSuggester]
        ENUMS[enums]
        NOTIF[NotificationService]
        WSYNC[WidgetSyncService]
        APPICON[AppIconService]
    end

    UI --> APP
    UI --> COMMON
    APP --> DI
    DI --> REPOS
    DI --> SUMS & THS & RECS & INSS & REMS
    DI --> SNAP
    REPOS --> DBASE
    REPOS --> MAP
    SNAP --> DBASE
    SNAP -. implements .-> SNAPI
    PAISA --> DBASE
    SUMS & THS & RECS & INSS & REMS --> ENT
    REPOS --> ENT
    MAP --> ENT
    DOMAIN --> MONEY & CAL & ENUMS
    UI --> ICONS
    WID --> WSYNC
    APP --> THEME
    APP --> NOTIF

    classDef ui fill:#ECD9B4,stroke:#B07C5E,color:#262219;
    classDef app fill:#D3E0E6,stroke:#6E8B6A,color:#262219;
    classDef domain fill:#DCE3CE,stroke:#6E8B6A,color:#262219;
    classDef data fill:#E9D2DC,stroke:#B07C5E,color:#262219;
    classDef core fill:#F3ECDE,stroke:#262219,color:#262219;
    class DASH,EXP,PAY,INS,SET,ONB,SEC,WID,COMMON ui;
    class ROUTER,DI,THEME app;
    class ENT,SUMS,THS,RECS,INSS,REMS,SNAPI domain;
    class REPOS,DBASE,SNAP,PAISA,MAP data;
    class MONEY,CAL,ICONS,ENUMS,NOTIF,WSYNC,APPICON core;
```

---

## 2. Who's allowed to import whom

Same rule as above, drawn as a strict graph with no loops. If you ever catch
`domain` importing `flutter/material.dart` or a repository, something has gone
sideways and it needs fixing.

```mermaid
graph LR
    features --> app
    features --> data
    features --> domain
    features --> core
    app --> data
    app --> domain
    app --> core
    data --> domain
    data --> core
    domain --> core
    core --> dart([Dart SDK only])

    classDef box fill:#F3ECDE,stroke:#262219,color:#262219;
    class features,app,data,domain,core,dart box;
```

---

## 3. What happens when you add a transaction

You save something, it lands in SQLite, and every screen that cares updates on
its own. No screen keeps its own private copy of the data. It all flows out of
Drift streams that Riverpod exposes as providers.

```mermaid
sequenceDiagram
    autonumber
    actor U as You
    participant QA as QuickAddSheet
    participant IS as IconSuggester
    participant R as TransactionRepository
    participant DB as Drift AppDatabase
    participant P as Riverpod providers
    participant S as SummaryService
    participant V as Dashboard / Expenses

    U->>QA: type a name and amount
    QA->>IS: suggestCodePoint(name)
    IS-->>QA: a guessed icon (you can override)
    U->>QA: Save
    QA->>R: upsert(TransactionEntity)
    R->>DB: INSERT/UPDATE (stored as integer minor units)
    DB-->>P: the watch stream emits the new rows
    P->>S: monthlySummaryProvider recomputes
    S-->>V: balance, income, spent, invested
    P-->>V: this month's transactions
    Note over V: The screen rebuilds. Amounts stay<br/>blurred until you tap the eye.
```

---

## 4. Delete, undo, and the Trash

Deleting never really destroys anything on the first tap. A transaction moves
from active, to trashed, and then either back to active or gone for good. The
`archivedAt` column is the one thing that decides "is this in the Trash".

```mermaid
stateDiagram-v2
    [*] --> Active: upsert()
    Active --> Trashed: archive()<br/>(swipe, bulk, or menu)
    Trashed --> Active: unarchive()<br/>(10s undo snackbar,<br/>or Trash then Restore)
    Trashed --> [*]: delete() / emptyTrash()<br/>(permanent)
    note right of Active
        watchForMonth filters archivedAt IS NULL.
        Summaries ignore archived rows.
    end note
    note right of Trashed
        Only shows up in Settings, Trash.
        Included in backups, restored as trash.
    end note
```

---

## 5. Backup and restore

A backup grabs the lot: all 11 tables plus every setting you have (profile,
theme, accent, font, app icon), all in one file. Restore doesn't care which
format you picked, and it's forgiving. Columns it doesn't recognize get ignored,
and columns that don't exist yet just fall back to defaults, so an old backup
keeps working after an update.

```mermaid
flowchart LR
    subgraph Export
        DBx[(AppDatabase)] --> RA[readAllTables]
        RS[readSettings] --> AS
        RA --> AS[AppSnapshot model]
        AS --> ENC{format?}
        ENC -->|JSON| J[.json]
        ENC -->|CSV| C[.csv]
        ENC -->|XML| X[.xml]
    end

    J & C & X --> FILE[[backup file<br/>native share sheet]]

    subgraph Import
        FILE --> DET[auto-detect format]
        DET --> DEC[decode into AppSnapshot]
        DEC --> UP[insert-or-update<br/>all tables in one txn]
        DEC --> WS[writeSettings +<br/>reapply launcher icon]
        UP --> DBy[(AppDatabase)]
        DBy --> JMP[focusedMonth set to<br/>latestActiveDate]
        JMP --> VIS[restored data<br/>shows up right away]
    end

    classDef n fill:#F3ECDE,stroke:#262219,color:#262219;
    class DBx,RA,RS,AS,ENC,J,C,X,FILE,DET,DEC,UP,WS,DBy,JMP,VIS n;
```

> Why bother jumping the month after a restore? The dashboard and expenses list
> always open on the current financial month. Without the jump, data restored
> from an older month is sitting there invisibly until you manually page back,
> which honestly just reads as "my imported data vanished". Pointing
> `focusedMonthProvider` at `latestActiveDate()` after a restore puts the data
> right in front of you. The restore also calls `refreshAllDataProviders(ref)`,
> which invalidates every database-backed provider so a bulk import shows up
> instantly in the running session (no app restart), sitting alongside anything
> you added by hand. The same call runs after a Paisa import.

---

## 6. The database

Money is always an INTEGER (minor units), never a float, so rounding can't bite
you. Every record you own carries `id`, `createdAt`, `updatedAt`, `archivedAt`
(the soft delete), and `syncStatus` (used by the optional cloud backup).
Schema version 3 added `transactions.iconCodePoint`.

```mermaid
erDiagram
    CATEGORIES ||--o{ TRANSACTIONS : categorizes
    ACCOUNTS ||--o{ TRANSACTIONS : "funds"
    PAYMENT_METHODS ||--o{ TRANSACTIONS : "via"
    CATEGORIES ||--o{ RECURRING_PAYMENTS : categorizes
    RECURRING_PAYMENTS ||--o{ TRANSACTIONS : "auto-adds (linkedPaymentId)"
    LOANS ||--o{ TRANSACTIONS : "EMI (linkedLoanId)"
    CUSTOM_FIELDS ||--o{ CUSTOM_FIELD_VALUES : defines
    TRANSACTIONS ||--o{ CUSTOM_FIELD_VALUES : "annotated by (ownerId)"
    THRESHOLDS }o--|| CATEGORIES : "optional scope"

    TRANSACTIONS {
        text id PK
        int type
        text name
        int amountMinor
        datetime occurredAt
        int iconCodePoint "v3, nullable"
        text categoryId FK
        text accountId FK
        text paymentMethodId FK
        datetime archivedAt "Trash if set"
        datetime createdAt
        datetime updatedAt
    }
    CATEGORIES {
        text id PK
        text name
        int colorValue
        int iconCodePoint
        text semanticBucket
        bool isDefault
        int sortOrder
    }
    RECURRING_PAYMENTS {
        text id PK
        text name
        int amountMinor
        int frequency
        datetime nextDueDate
        bool autoAddTransaction
    }
    LOANS {
        text id PK
        text name
        int originalPrincipalMinor
        int emiMinor
        datetime nextPaymentDate
    }
    THRESHOLDS {
        text id PK
        int kind
        int value
        text scope
        bool enabled
    }
    CUSTOM_FIELDS {
        text id PK
        text label
        int type
    }
    CUSTOM_FIELD_VALUES {
        text id PK
        text fieldId FK
        text ownerId FK
        text value
    }
    ACCOUNTS { text id PK
        text name }
    PAYMENT_METHODS { text id PK
        text name }
```

> `NotificationPreferences` and `ExportRecords` have no foreign keys, so I left
> them out of the diagram to keep it readable. The full column list for every
> table is in [SPEC.md, section 4](SPEC.md).

---

## 7. State: the Riverpod graph

Providers are the seam between the UI and everything behind it. The database is
a stable singleton, and streams run from Drift out to the widgets. The one to
watch is `focusedMonthProvider`, because it decides which month every screen is
looking at.

```mermaid
graph TD
    DBP[databaseProvider<br/>singleton] --> TREPO[transactionRepositoryProvider]
    DBP --> LREPO[loanRepositoryProvider]
    DBP --> RREPO[recurringRepositoryProvider]
    DBP --> SNAPP[snapshotServiceProvider]

    FM[focusedMonthProvider] --> MT[monthTransactionsProvider]
    TREPO --> MT
    MT --> MS[monthlySummaryProvider]
    MS --> DASHV[[Dashboard]]
    MT --> EXPV[[Expenses]]
    TREPO --> ARCH[archivedTransactionsProvider] --> TRASHV[[Trash]]

    MS --> THP[thresholdWarningsProvider] --> INSV[[Insights]]
    RREPO --> OVD[overduePaymentsProvider] --> DASHV
    TREPO --> TRENDP[trend / insights providers] --> INSV

    SETC[settingsControllerProvider] --> THEMEP[theme / accent / font] --> APPV[[app.dart]]

    classDef p fill:#DCE3CE,stroke:#6E8B6A,color:#262219;
    classDef v fill:#ECD9B4,stroke:#B07C5E,color:#262219;
    class DBP,TREPO,LREPO,RREPO,SNAPP,FM,MT,MS,ARCH,THP,OVD,UPC,TRENDP,SETC,THEMEP p;
    class DASHV,EXPV,TRASHV,INSV,APPV v;
```

---

## 8. Getting around: the navigation shell

A `GoRouter` `StatefulShellRoute` holds five branches behind the bottom nav bar.
Onboarding gates the way in, and a few flows (export, the settings sub-pages)
push on top. The settings sub-screens like Backup, Trash, and Category Manager
open with a plain `MaterialPageRoute`.

```mermaid
graph LR
    START((launch)) --> GATE{onboarded?}
    GATE -->|no| ONB[/onboarding/]
    GATE -->|yes| SHELL
    ONB --> SHELL

    subgraph SHELL["StatefulShellRoute (bottom nav)"]
        B1[Dashboard]
        B2[Expenses]
        B3[Payments]
        B4[Insights]
        B5[Settings]
    end

    B5 --> BK[Backup & restore]
    B5 --> TR[Trash]
    B5 --> CM[Category manager]
    B5 --> MORE[Accounts, Methods, Thresholds, Notifications, Security, About]
    SHELL --> EXPRT[/export/]

    classDef n fill:#F3ECDE,stroke:#262219,color:#262219;
    class START,GATE,ONB,B1,B2,B3,B4,B5,BK,TR,CM,MORE,EXPRT n;
```

---

## 9. The rules I try not to break

These are the load-bearing ones. Bend any of them and the design slowly starts
to rot:

1. Money is never a `double`. `Money` wraps integer minor units, and all the math
   and formatting go through it.
2. `domain` stays pure. No Flutter, no Drift, no IO, just Dart and `core`. That's
   what makes the logic so easy to unit test.
3. There's one place that does month math: `monthlySummaryProvider` plus
   `FinancialCalendar`. Screens don't recompute totals on their own.
4. Nothing important is hard-coded. Categories, currencies, thresholds, and icons
   are editable defaults living in the database, not constants baked into widgets.
5. The UI talks to repositories and providers, never straight to the database.
6. Deleting is soft first. A user-facing delete archives; wiping something for
   good is a separate, deliberate action.
7. The icon library only ever grows. `kCategoryIcons` indices stay put so stored
   code points never break.
8. Every row carries `createdAt`, `updatedAt`, `archivedAt`, and `syncStatus`,
   which is what lets the snapshot and cloud backup work without a migration.

---

_For the full behaviour, see [SPEC.md](SPEC.md). For the full visual system, see
[DESIGN.md](DESIGN.md)._
