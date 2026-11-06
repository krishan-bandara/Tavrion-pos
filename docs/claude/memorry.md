# Tavrion POS — Project Memory

_Last updated: 2026-11-05. This file is the single source of truth for decisions made with Claude. Detailed docs are in the same folder (plan.html, architecture.html, security.html, database.html, localization-hardware.html)._

## Goal
Desktop standalone POS for a **small retail grocery shop in Sri Lanka**, UI mostly **Sinhala** (English secondary). Inspired by https://mypos.lk/ (myPOS ONE, a 20-module cloud/PWA retail suite) — we build only the grocery-relevant core, not the full suite.

## Target machine
Marcopos MP-TP001S all-in-one touch PC: Windows 10, Core i7 (4th gen), 8 GB RAM, 256 GB SSD, 15.6" touch display, built-in WiFi.
Implications: keep app light (Tauri ~10 MB, ~100 MB RAM), large touch targets (>=48 px), no heavy local services (no Docker/Postgres locally), WebView2 needed (installer bundles bootstrapper).

## Decisions (confirmed by user 2026-11-05)
| Topic | Decision |
|---|---|
| Scope | One shop, one terminal first; design so multi-terminal/branch can come later |
| Database | **Offline-first**: local SQLite is the source of truth at the till; sync to **Supabase (Postgres)** for backup, owner remote dashboard, future multi-branch |
| Stack | **Tauri 2 + React + TypeScript** (Rust side for printer, cash drawer, SQLite, sync) |
| Hardware phase 1 | Thermal receipt printer + cash drawer (drawer kicked via printer) |
| Hardware phase 2 | Barcode scanner (USB HID); later maybe scale / label printer |

## Decisions I (Claude) assumed — user may override
- Money stored as **integer cents (LKR x100)**; never floats.
- Primary keys = **UUID v7** (safe for offline creation and later sync).
- Stock = **append-only movement ledger**; on-hand is derived/cached.
- Sinhala receipts printed as **bitmap (canvas -> ESC/POS raster)** because thermal printers lack Sinhala fonts.
- Fonts bundled: Noto Sans Sinhala (Iskoola Pota is on Windows as fallback).
- Local DB encrypted at rest (SQLCipher) + daily encrypted backup to Supabase Storage and local USB/folder.
- VAT handling is configurable (off by default; many small shops are not VAT registered) — **confirm**.

## Open questions (still to ask the user)
1. Receipt printer exact model + paper width (58 or 80 mm) + connection (USB/serial)?
2. Cash drawer connection (RJ11 to printer — assumed).
3. Number of products (hundreds vs thousands)? Existing item list in Excel to import?
4. Are loose/weighed items sold (rice, sugar, veg)? Needed now or later?
5. Customer credit ("ණය") book needed in v1? (very common in Sri Lankan groceries — recommended yes)
6. Supplier purchases/GRN in v1 or later?
7. Cashiers: how many users, owner vs cashier roles, PIN login on touch screen?
8. VAT/SVAT registration? Need tax invoice?
9. Card payments / QR (LankaQR) in v1? (recommend record-only, no EFT integration yet)
10. Is this for one shop owner (private tool) or to sell to others (needs licensing)?
11. Supabase project: existing one or create new? (a Supabase MCP is available in this Claude environment)
12. Who supports the shop on failures (remote access, backup restore)?

## mypos.lk research summary (from site, 2026-11-05)
Modules: POS & sales (touch, offline, shift control, blind cash-off), inventory (multi-location, batch/expiry, reorder suggestions, cycle count), procurement/GRN, credit & hire purchase, promotions, loyalty (points, vouchers, gift cards, SMS), analytics/AI forecasting, payroll, finance ledger, restaurant, e-commerce. Hardware: barcode/label printers, scales, EFT terminals. Security: role/field permissions, approval matrix, audit log. Site does **not** mention Sinhala — Sinhala-first UI is our differentiator. Pricing not public.

## Scope cut for v1 (MVP)
Sales/billing, product & barcode, stock in/out, customers + credit book, cashier shift + cash drawer, receipts (Sinhala), daily sales & stock reports, backup + Supabase sync, roles (owner/cashier), audit log.
Later: suppliers/GRN, discounts/promos, loyalty, scale, label printing, multi-terminal, mobile owner app, SMS.

## Shop identity (given by user 2026-11-05)
- Shop: **චූටිනෝනා මධ්‍යම වෙළඳසැල**
- Address (print exactly): **නො 20. ෆාතිමා මාවත කාඳන**
- Phone: placeholder `07X XXX XXXX` until the user sends the real one. English shop name not given.
- Address + name appear in the app header and at the top of every printed bill / Z report.

## UI/print decisions (user, 2026-11-05)
- Technical terms stay **English** inside Sinhala UI (Online, All synced, Stock, Bill, Discount, Hold, Pay, Cash, Card, Credit, Reports...). Everyday words and item names stay Sinhala.
- **Bill line format:** name, then `245.00 /kg × 2.500 kg` (1 kg price first, then requested qty) on the left, line total on the right.
- **Discounts:** per item and per bill, as % or Rs. amount; shown on the bill (line, bill discount, "You saved"). Cashier limit **10%**; above that the **Owner PIN** is required (demo PIN 1234 — real app uses argon2id hash).
- Checkout shows the bill and auto-prints an 80 mm receipt (toggle "Auto print"); Print button reprints.
- User did not choose premium extras or receipt options when asked; I picked from the research (see research.html): shift + Z report, loyalty points (earn), e-bill button, credit limit.

## PARKED features (user decision 2026-11-05) — small shop, CASH ONLY
The shop accepts **cash only** (no credit/debit card, no Visa). Dropped for now, to be revisited only if the user asks:
- Card payments / EFT, split payments by card
- Customer credit sales (ණය) and the Credit book tab
- Loyalty points and customer picker
- e-Bill / WhatsApp / SMS bills
- All premium items in research.html (promotions engine, vouchers, GRN, expiry, multi-branch ...)
**Still in v1 (cash-related):** billing, item + bill discounts (cashier 10% / owner PIN above), hold/recall, stock + low-stock list, reports, Z report (cash count and variance), auto-print bill with shop name + address.
In the demo these are switches in `var F={card:false,credit:false,loyalty:false,ebill:false}` near the top of the script; code is kept so they can be turned back on. Database design should still keep `payment.method` as a column so card/credit can be added later without migration pain.
This supersedes the earlier "customer credit book in v1 (recommended)" suggestion and the card/credit/loyalty/e-bill lines in the UI/print decisions above.

## Quantity rules (user, 2026-11-05)
- Loose items are priced **per 1 kg**; any weight is sold pro-rata (250 g of Rs. 380/kg = Rs. 95.00). Bill shows `380.00 /kg × 0.250 kg`. Stock is stored in grams (milli-kg) and shown in kg.
- Packed items (soap, bread, egg ...) are priced **per piece**; qty is a whole number.
- Stock screen: **Stock in** (free), **Remove** (damaged/expired/wastage/own use — Owner PIN), **Count** (set exact stock; lowering needs Owner PIN), **Add product**, **delete product** (Owner PIN), and a movement log (every sale and manual change). kg items can be entered in kg (decimals) or g.
- Rounding: each line is rounded to the nearest cent after pro-rata calculation.

## Decisions from the stock/login round (user, 2026-11-05)
- **Weight step:** +/- on a bill line moves **250 g** (cashier can tap the quantity to type any exact weight; quick chips 100 g / 250 g / 500 g / 1 kg / 2 kg). Example confirmed: Samba Rs. 235/kg, cashier enters **500 g = Rs. 117.50** (250 g would be Rs. 58.75). Bill shows `235.00 /kg × 500 g`; under 1 kg shown in grams, 1 kg and above in kg.
- **Cashier may remove stock freely** (Stock in / Remove / Count need NO owner PIN). All changes are in the movement log with time and reason.
- **Login code added:** PIN sign-in screen, users **Owner කුමාර** (PIN 1234 in demo) and **Cashier රුවිනි** (PIN 1111 in demo); 5 wrong tries = 30 s lock; auto-lock after 5 min idle; Lock button in header. Real app: argon2id-hashed PINs, set by owner. Bill and Z report print the signed-in user's name.
- **Roles:** Owner (කුමාර) = everything. Cashier = billing, stock in/remove/count, add product, hold/recall, discount up to 10%. Needs Owner PIN (or owner signed in): discount above 10%, **delete product**, **change price**. Reports tab (incl. Z report) is **owner only** — my assumption, change if the cashier should close the shift.
- **Units (answer 3 = yes):** three kinds — kg (sold in g), **litre (sold in ml)** e.g. loose coconut oil Rs. 720/litre, and pieces/packs priced each (soap, bottle of oil, bread, eggs). New products can be created as kg / litre / pcs.
- **Price editing (answer 4 = yes):** Stock screen has a Price button and a Price column; changes are logged (`235.00 → 240.50`) and apply to new bills from then on.

## UI tweak: stock on product tiles (user, 2026-11-05)
- Available stock on every product tile is shown in **red, bold, larger**, labelled `Stock: 80 kg` / `Stock: 18` (kg and litre items show the unit) so the cashier sees it at a glance.
- Low-stock items (at or below reorder level) get a **filled red badge**: `Stock: 9 kg · Low`, so they still stand out from normal red text.
- Owner login display name is **කුමාර** (changed from හිමිකරු).

## Multi-type items (groups) — user, 2026-11-05
- Items with many types (first one: **Rice / සහල්**, 11 types) show as **one tile with no price** (`සහල් · 11 වර්ග ›`, total stock in red). Tapping opens a **type picker** listing every type with its **current stock (red)** and **price per 1 kg**; picking one opens the weight entry (grams) with the live calculation, then Add to bill. Cancel on the weight screen returns to the picker.
- Prices per 1 kg (from the shop's list; ranges given as one fixed selling price, range kept as a hint in the picker; edit anytime with the Price button): සම්බා 240, නාඩු 218, සුදු කැකුළු 194, රතු කැකුළු 190, සුදු අමු සහල් 207 (199–215), රතු අමු සහල් 213 (190–235), කීරි සම්බා 289 (253–325), මුතු සම්බා 270 (240–300), සූදුරු සම්බා 310 (300–320), රතු සම්බා 240 (220–260), සුදු සම්බා 240 (230–250).
- Bill/stock/log names carry the group: `සහල් · කීරි සම්බා`. Single-type items (sugar, soap ...) still show their price on the tile. New products can be assigned to the Rice group. Other groups (dhal, sugar types, oil brands ...) can be added the same way — user to list them.
- Earlier example price "Samba Rs. 235" was superseded by the shop's list (Samba 240; 500 g = Rs. 120.00).

## Round 2 of multi-type items + screen size (user, 2026-11-05)
- **Group tile shows the category name ONLY** (e.g. `සහල් / Rice ›`) — no price, no count, no stock. Tapping lists the types with **current stock (red) and price per 1 kg / 1 litre / packet**. Single-type items still show their price on the tile (user: "why hide the price, just show it").
- Range hints removed. Ranged rice types keep one fixed price (midpoint) — editable with the Price button.
- **Groups now in the demo (9):** Rice (11 types), Dhal (red, chana, urad), Sugar (white, brown, jaggery), Flour (wheat, rice, kurakkan), Pulses (chickpea, green gram, cowpea), Milk powder (local 400g, imported 400g, imported 1 kg), Tea (200g, 400g, green tea bags), Coconut oil (1 L bottle, 500 ml bottle, loose per litre), Spice powders (chilli 100g/250g, curry, turmeric, pepper).
- **Prices are indicative, from market research** (CAA weekly ranges May 2026: wheat flour Rs. 153–172/kg, white sugar 195–235, dhal 225–249 (April 248–271); DCS July 2026 wheat flour avg 192; imported milk powder from 20 May 2026: 400g Rs. 1,200, 1 kg Rs. 3,000). Chickpea, green gram, urad, jaggery, kurakkan, tea and coconut-oil prices had no 2026 source found = estimates. **Owner must confirm/edit all prices before go-live.**
- **Target screen = Marcopos 15.6" touch (assume 1366×768).** The demo is now a no-page-scroll kiosk layout: header + tabs + product grid (scrolls inside its panel) + bill panel (410 px) fit 1366×768; keypad dialogs shrink under 820 px height; text selection and overscroll disabled. Design rule for all future screens: **must fit 1366×768 without scrolling the page, touch targets ≥ 48 px** (≥ 44 px allowed on short screens).

## Add product form (user, 2026-11-05)
- Product name field is a **searchable dropdown + manual entry**: typing filters (Sinhala, English or barcode); the list shows products already in the shop (tag "Shop එකේ ඇත" — picking one opens **+ Stock in** for it instead of creating a duplicate) and a built-in list of ~18 common Sri Lankan grocery items not yet in the shop (picking one pre-fills name, English name, category, unit, indicative price, group). If nothing matches, the typed text is used as the new product name.
- **Group** field works the same way: pick an existing group (Rice, Dhal, ...) or type a new group name, which is created on save. Category follows the chosen group.
- The built-in list (`COMMON` in the demo) must later become an editable master list in the database.

## Big update: catalogue x7, decimal keypad, new UI (user, 2026-11-05)
- **Decimal point** added to every money keypad (cash tendered, Rs. discount, % discount, shift cash count, price edit) and to kg stock entry. Amounts now accept cents: Rs. 700.50 tendered. "Exact" button uses the exact total. **Clear (C) button now sits inside every number display**; physical keyboard digits, `.`, Backspace and Enter also work in dialogs and on the PIN screen.
- **Catalogue expanded from ~50 to 367 items in 46 groups** (user: "sugar has white and brown, likewise research all"). Built by 3 research agents in parallel (staples & cooking; dairy/bakery/beverages/snacks/packaged; fresh produce/dried fish/household/personal care/baby), merged and de-duplicated (ids 100+, barcodes auto `47919########`). New categories: **Fish & protein, Snacks & sweets, Personal care**; "Vegetables" now "Vegetables & fruit". Examples: Sugar group = white, brown, jaggery, kithul jaggery, coconut-palm jaggery, icing sugar, sugar cubes, kithul treacle, honey; Salt group = iodized (loose/400g), raw, rock, kalu lunu.
- **ALL new prices are ESTIMATES.** The research agents did not find or use 2026 sources (0 sourced). Only dhal, sugar, wheat flour and imported milk powder in the earlier hand-entered list had real references. **The owner must confirm every price before go-live** (Stock screen → Price). Raw data: `docs/claude/catalogue/researched-catalogue.json`.
- **New UI (ui-ux-pro-max skill, restyled by me):** left navigation rail (Sales / Stock / Reports / Theme / language / Lock) + top status bar; rounded cards with soft depth; tea-green brand, turmeric accent, chilli red for stock/danger; fonts Noto Sans Sinhala + Rubik (numbers); product tiles with colour avatar chip, price, red stock; stacked-card look for groups; glass-blur dialogs; light and dark theme with a **Theme toggle** (follows system by default); inline SVG icons, no emoji.
- **Animations (all disabled when the OS asks for reduced motion):** tiles stagger in when the category or tab changes; new bill lines slide in; bill total counts up/down and bumps; dialogs spring in; the bill **"prints out" with a reveal** on the receipt dialog; toast slides up; online dot pulses; low-stock badge breathes; PIN card rises in. The print stylesheet strips all animation so the printed 80 mm bill is unaffected.
- **Generic names only (user, 2026-11-05):** products are listed generically, size in the name where needed (e.g. "Milk powder · Imported 400g", "Tea 200g"). **No brand names** in the catalogue; the owner can add brands later via Add product.
- **Categories: KEEP ALL for now (user, 2026-11-05).** Household, personal care, snacks etc. all stay. Do NOT remove anything; the owner will decide later. (Possible future feature: a Settings switch to hide categories.)
## CLOUD BUDGET (user, 2026-11-05): under USD 20 per month
- Expected data is tiny (about 100-200 MB a year at ~300 bills/day; nightly backups 10-30 MB). Storage is not the cost driver.
- Supabase Pro is USD 25/month (8 GB DB, daily backups, no pausing) = **over budget**. Supabase Free (500 MB DB, 1 GB files) = USD 0 but **pauses after 7 days of inactivity and has no managed backups**.
- Firebase (Firestore 1 GiB + 50K reads/20K writes a day free; Cloud Storage needs the Blaze pay-as-you-go plan) is about USD 0-2/month, but weak for date-range profit reports (many reads, no joins).
- **Decision for now: Supabase Free (USD 0)** plus safeguards in the app: daily sync + a keep-alive ping so the project never sits idle 7 days (shop holidays), our own **encrypted daily backup to a local USB/folder AND a free cloud bucket**, and a documented restore drill. Upgrade to Pro (USD 25) only if the owner wants managed daily backups and accepts the cost. Fallback option within budget: a small VPS (about USD 5-12/month) running Postgres with our own backups (more admin work).
- Prices come from third-party 2026 guides; re-check the official Supabase / Firebase pricing pages before go-live.

## CREDIT BOOK + BUYING PRICE (user, 2026-11-05) — credit is back ON (cards still off)
Answers given: over-limit = **block, owner PIN override**; early alert at **80%** of the limit; **cashier adds the customer name, owner sets the limit**; stock cost = **keep each purchase as a batch, use the latest buying price**.
- **Credit book (ණය පොත)** tab for owner and cashier: customers by personal name + phone, balance, limit, available credit, usage bar, status pill (OK / Near limit % / Over limit / No limit set), search, totals (total owed, alerts). Buttons: **Take payment** (cash repayment, "Full balance" shortcut, goes into the cash drawer and the Z report as "Credit repayments"), **Statement** (ledger: credit sales, payments, limit changes), **Set limit** (**owner only**; the button is not shown to cashiers).
- **New customer starts with limit Rs. 0 = no credit** until the owner sets a limit. Customers can be added from the Credit book or straight from the bill (customer picker → + Add customer).
- **Credit sale on the bill:** pay dialog has Cash / Credit. Shows balance → new balance / limit with a bar. **Early alert (yellow) when the customer would reach the alert level (default 80%)**; **blocked (red) when over 100% or when no limit is set**; the cashier needs the **Owner PIN override** (an owner who is signed in is allowed and sees "Owner approval"). Bill prints customer name, balance, limit and a signature line. A yellow **"Credit alerts: N"** chip in the header (both roles) jumps to the Credit book. After a sale that leaves the customer near/over the limit the receipt dialog shows the alert.
- **Alert level is an owner-only setting:** Settings → Credit alert level (60 / 70 / 80 / 90 %), remembered on the PC.
- **Stock in now has Quantity / Buying price / Selling price** (three fields, one keypad; live margin %). Saves the buying price as the item's latest cost, fixes the selling price, and writes a **purchase batch** (time, item, qty, buy, sell, who) shown under **Recent purchases** on the Stock screen. A **cashier who changes the selling price at stock-in needs the Owner PIN** (same rule as the Price button); same price = no PIN. **Buying price is visible to the owner only** (Buy column in Stock and in Recent purchases); cashiers can type it but do not see it afterwards. Add product also asks for a buying price. Existing items got an estimated cost (82% of selling price) until the owner stocks in or edits.
- Real app notes: limits, ledger and batches live in the database (not browser memory); credit sales and repayments must be immutable ledger rows; per-customer statement printing and SMS reminders are later.
- Tests: 78 automated checks in headless Edge pass (the earlier 48 + 30 for credit, limits, alerts, owner override, repayment, statement, alert level, buying/selling price at stock-in, cashier PIN rules).

- **Product pictures REMOVED from cards (user, 2026-11-05: "not professional, make it normal text"):** product and group cards are now plain text cards with a category-coloured left edge: Sinhala name, English name, price per kg/litre/piece (large, green) and stock in red; groups show the name and a › arrow. Type-list rows are text only too. The illustrations are kept in the file behind one switch (`SHOW_PICS=false` near the top of the script) in case the owner wants them back; the shopping cart on the sign-in screen, the empty bill and the left-bar logo stay. This supersedes the "Picture cards" item below.
- **Settings → Categories (owner only, user said yes 2026-11-05):** a Settings screen with an on/off switch per category (Rice & grains, Spices, Drinks, Bakery, Dairy & eggs, Vegetables & fruit, Household, Fish & protein, Snacks & sweets, Personal care). Switching one off hides it and its items from the **Sales** screen only; items stay in Stock and nothing is deleted; the choice is remembered on the PC (browser storage; the real app will keep it in the database). All switched ON for now.
- **Type lists show the 10 most popular types first (user: "list most 10")**, ranked by units sold, with a search box and a **"Show all (N)"** button when a group has more than 10 types (e.g. noodles 43 types).
- **Add product dropdown** now lists ready-made new items first (9 left), then matching items already in the shop.
- **Self-test:** 48 automated checks were run in headless Edge on the demo (sign-in, rice 500 g = 120.00, decimals, item + bill discount, cash 300.50, stock −500 g exactly, bill shows shop name + address + `240.00 /kg × 500 g`, stock in/remove/count, price PIN, add product, 700 items all have pictures, no empty groups, categories hide/show, top-10 list, search, owner Reports/Z report, language and theme switches): all passed. Not tested: a physical printer, touch hardware, real data.
- **Brand-level catalogue added (user asked for noodle vendors "and likewise" other multi-vendor items):** 4 research agents covered noodles/pasta, dairy & beverages, household & personal care, snacks & pantry. Demo now has **700 items in 72 groups**. Noodles group has 54 types (Maggi, Prima Kottu Mee, plus other brands, cup noodles, pasta, macaroni, vermicelli). This replaces the earlier "generic names only" rule for these items. Raw files: `docs/claude/catalogue/brands-*.json`.
- **Research quality caveat:** the agents could not read Keells, Cargills, Glomark or Daraz (404/403/empty). Only a minority of prices are "sourced" (mostly Kapruka listings, the May 2026 imported milk powder notice, Nov 2025 CAA canned-fish ceilings); the rest are estimates. Estimated prices are flagged **"est"** in the Stock screen price column. Canned-fish "sourced" prices are legal ceilings, Cadbury prices from Kapruka look high. **Owner must confirm all prices.** Whether Mama, Koka, Ching's, Yum Yum, Nissin Cup are on local shelves was not confirmed.
- **Picture cards (user, 2026-11-05):** the Sinhala initial-letter chip on tiles was removed; each card now shows a flat illustration (rice bowl, dhal bowl, sugar jar, flour sack, etc.) over a category-tinted background, with the Sinhala name kept, price tag overlay and red stock. 68 illustrations drawn by 3 agents, mapped by group id / keywords / category (`GIMG`, `KEYWORDS`, `CATIMG` in the demo). Picker rows show a small thumbnail.
- **Left rail logo = small shopping-cart mark** (not a Sinhala letter). **Sign-in screen:** animated shopping cart in the middle, shop title and address under it, then the PIN pad. Empty bill also shows the cart.
- **Look & feel v2:** warm cream background, green header banner, yellow Pay button with shine, category chips with colour dots, green total strip, soft cards.
- Layout rule unchanged: fits 1366×768 with no page scroll (panels scroll inside); tall bills scroll inside the dialog with Print / New bill always visible.

## Demo
Folder `demo/`: `chutinona-pos-demo.html` (source, also published as artifact earlier — old artifact link was deleted, republish needed) and `demo/chutinona-pos/` (standalone `index.html`, `open-demo.bat`, `README.md`). `#sample-bill` hash shows a finished sample bill. `sample-receipt.png/pdf` are checks of the bill layout.

## Research (2026-11-05)
Read mypos.lk (home, modules, industries, plans) and lankabill.lk (Lanka POS: Rs. 59,900 lifetime, 7-day trial, WhatsApp billing, Sinhala/Tamil/English, hardware from Rs. 3,500/8,500/4,500). Full table in `research.html`.
Backlog from research: split payment, label printing, GRN + expiry, promotions engine, gift vouchers, SMS/WhatsApp e-bill gateway, stock count.

## Status
- [x] Research mypos.lk
- [x] Planning docs written (this folder)
- [ ] Answer open questions
- [ ] Scaffold Tauri project, SQLite schema, Supabase project

## Final category structure (round: sri_lankan_grocery_categories_si.json)
- User supplied `sri_lankan_grocery_categories_si.json` (copy in `catalogue\`) as the FINAL list: 18 categories (CAT001-018) and 95 sub-categories (SUB001-095). The old 10 categories (and the drinks DSUBS) were removed; every product now has `cat` = CATxxx and `sub` = SUBxxx.
- Sales screen: category chips + a sub-category row under the chosen category (counts, only non-empty subs). Add-product has category and sub-category chips. Settings -> Categories lists the 18.
- Existing 1,056 products re-mapped by rules; eggs placed under Meat & poultry > Chicken & eggs (SUB016) because the list has no egg slot. Drink milks sit in Dairy > Liquid milk. Open question for owner.
- 20 parallel agents filled empty/thin sub-categories (+686 products, raw files in `catalogue\new-categories\`). All prices are ESTIMATES (flag est), none web-verified; Sinhala names unproofread. Owner must confirm prices and Sinhala before go-live.
- Still pending: credit sales without printed bill + credit register, daily P&L and Reports date-range KPI (buying vs sold), buying price visible to cashier in Stock.

## Credit sales without bill + Reports/P&L (round)
- Credit sale: NO bill is printed or issued. A "Credit sale recorded" confirmation dialog shows ref, customer, amount, balance, limit (+ limit alert). Every sale (cash/credit) is stored as a per-bill record with a cost snapshot (S.sales: date, time, method, customer, gross, discounts, total, cost, lines[{pid, qty, revenue, cost}]).
- Credit book has two tabs: Customers | Credit sales register (date range, customer, items, amount; owner also sees buying cost and profit; cashier sees no cost/profit).
- P&L is accrual: credit sales count as sales and profit on the sale date; repayments appear only as "Credit collected". Cash received = cash sales + collections.
- Reports (owner only): presets Today / Yesterday / 7 days / 30 days / This month / Last month / Custom From-To (single date = same From and To). KPI cards: Net sales, Buying cost, Gross profit, Margin, Bills, Credit given (+ collected), each vs the previous equal period. Buying vs selling side by side (bars), P&L statement, daily table with totals, daily/hourly chart (sales vs cost), item table (qty, buying value, sold value, profit, margin).
- Buying price is now visible to the cashier in Stock and Recent purchases (owner answered Q1 yes).
- Demo data: 46 days of generated bills (deterministic), per-item cost = 76-86% of price (placeholder). Real data comes from stock-in buying prices.
- Sinhala names of the 706 agent-added products were proofread by 10 agents (118 corrections applied). Colocasia (small taro) still flagged as probably wrong.
- Self-test: 101 checks pass. Screenshots: screenshots\reports.png, creditreg.png.

## Catalogue v2 - rebuilt from retail sources (replaces the 18/95 JSON and the 1,742-item list)
- Owner said the old catalogue had duplicates and wrong categories; asked to rebuild from SPAR Sri Lanka, KGS Mart, Sahanakade, Family Super. Decisions (owner answered): rebuild categories from the 4 sources; start products fresh; use store prices where shown; agents may browse.
- Source access: SPAR (spar2u.lk, Shopify) fully readable (124 sub-categories, ~820 priced products). KGS Mart (12 top-level only, JS site), Family Super (8 top-level, brochure), Sahanakade (blocked, search snippets only). So only SPAR gave real products/prices; the other three confirm top-level structure only.
- New tree: 17 categories C01-C17, 106 sub-categories S001-S106 (`catalogue\v2\taxonomy.json`, Sinhala + English). SPAR sub-category names are mapped to ours inside the taxonomy file.
- 20 parallel agents built the products; raw files `catalogue\v2\cat_01..20.json`, merged `catalogue\v2\merged.json`. Result: 1,826 products, every sub-category filled, 34 cross-agent duplicates removed, 773 prices SOURCED from SPAR (price+URL), the rest ESTIMATES (flag est) - agents ran no web verification on the items they added.
- Known items to check: SPAR 'Fresh Harvest Frozen Salmon Portions' (100g vs 1kg in URL), 'Scan Jumbo Peanuts' size, some SPAR vegetable prices look per-kg, SPAR Broccoli listing dropped (6650/500g looked wrong). Sinhala names written by agents, not native-reviewed (only the earlier 706 items had a proofreading pass).
- Groups (brand/type pickers) removed: browsing is now category -> sub-category chips; GROUPS is empty.
- Self-test suite replaced (36 checks, all pass) because old tests referenced old products.

## Catalogue v2 – second check pass (10 agents)
- 10 agents reviewed 10 slices (~183 items each) for sub-category, Sinhala name and price. **None ran web checks** – every fix is from model knowledge (unverified).
- Applied 163 fixes: Sinhala names (incl. ~57 "(වැල්)" -> "(පැකට් නැති)"), sub-category moves (onion/garlic/ginger/potato -> S014, swiss rolls -> Cakes, nectars -> S053, etc.), 8 duplicate removals, 8 est-price changes. Catalogue is now 1,818 items. Self-test: 36/36 pass.
- NOT applied: Star Light Candle 8 pcs (SPAR-sourced Rs 1,340; agent suggested 275 – owner to check).
- Still doubtful (native/owner review): plantain and Rathambala banana Sinhala names; "Fair & Lovely" may now be "Glow & Lovely"; Pringles 107g and Ferrero 3pcs (Rs 650) may be low; SPAR per-kg-looking vegetable prices (Cabbage 1kg 890, Capsicum 250g 1190, Bell Pepper 500g 2790).
- Backup before this pass: scratchpad pre_ver.bak.

## Simplified Sales screen: family -> product -> brand/size (30 agents)
- User feedback: 17 categories + 106 sub-category chips was too complex. Wanted ONE main category per product family (e.g. Rice holding everything rice-related) and the cashier picking the quantity/size (100g, 250g, 500g, 1kg, 2kg, 5kg).
- Decisions (user answers): product-family categories; one product with size buttons; brand is a choice inside the product.
- Structure now: 96 families (F001-F096, old sub-categories with a few merges, coloured by old category) -> 948 products (e.g. "Nadu Rice") -> SKUs (brand + pack size). SKUs/stock/barcodes/sales/reports are unchanged (still P rows); P rows have extra columns: fam, pk (product key), psi/pen, bsi/ben (brand), size.
- Sales: family tiles -> product list (crumb "<- All categories") -> tapping a multi-SKU product opens a picker: brand chips, loose items get 100g/250g/500g/1kg/2kg/5kg + custom weight buttons (price on each), packs show size+price+stock; picker stays open so several adds can be made, "Done" closes. Single-SKU products add straight away (loose -> weight keypad). Search works across all families (name, brand, barcode).
- Add product: family dropdown + brand + size; matching name in the family joins the existing product.
- 30 agents (limit 20 at once -> 20 then 10) classified product/brand/size from the SKU names; 71 same brand+size collisions auto-labelled with the variant word (e.g. "Chocolate 200g"). Not native-reviewed: generic Sinhala product names.
- Self-test: 40/40 pass. Backups in scratchpad: pre_fam.bak, pre_ui.bak. Screenshots: screenshots\fam-families/rice/pick/pick2.png.
