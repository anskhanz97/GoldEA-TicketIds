Gold Engulfing EA v2.4 - Project Brief

Strategy Overview
Asset: XAUUSD only
Timeframe: H1 only
Pattern: Engulfing candles (opposite colors, body-to-body)
Entry: 10 limit orders distributed across engulfed candle body (3-3-4 zones)
Risk: $4 SL per order, $8 TP per order (1:2 RR)
Position Size: 0.01 lots per order
Gap Tolerance: 2 pips (0.20 points) for engulfing detection
Min Body Size: 2 pips (engulfed candle must meet minimum)
Historical Scan: 14 days (336 H1 bars) on EA start
Core Logic Flow
EA Start → Load saved setups → Re-validate untapped setups → Scan 14 days history
Historical Patterns Found → Create setups → Check if already tapped → Place orders if UNTAPPED
New H1 Bar → Detect new engulfing (bar 1 engulfs bar 2)
Create Setup → Time-based ID: "Engulf_DDMMYYYY-HHMM-D" (D = B/S for Bull/Bear)
Draw Lines → Yellow dotted lines (UNTAPPED state)
Place Orders → 10 limit orders across range (if untapped)
Price Taps Range → Lines turn RED (TAPPED state)
Determine Trade Status → MISSED (EA was off) or TRADED (orders placed)
First TP Hit → Cancel all remaining pending orders
All Orders Handled → Mark COMPLETE
Save State → Persistent JSON storage on every change



CORE LOGIC FLOW v4.0
EA Start (OnInit)
    ↓
Load saved setups WITH TICKETS from JSON
    ↓
✅ NEW: ValidateActiveSetupsFromTickets()
    ├── Check MT5 History FIRST for each setup
    ├── Recover tickets from MT5 if missing
    ├── Update states based on ACTUAL trades
    ↓
Scan 14 days historical data
    ↓
For each UNTAPPED pattern found:
    ├── Create setup
    ├── Draw YELLOW lines
    ├── ✅ Place orders immediately (3-3-4 distribution)
    ├── ✅ Store ACTUAL TICKETS in setup.orderTickets[]
    ↓
Save ALL setups WITH TICKETS to JSON
    ↓
OnTick() (New H1 Bar)
    ├── Detect new engulfing patterns
    ├── Check if price taps UNTAPPED setups
    ├── Update TAPPED setups using STORED TICKETS
    ├── Check for first TP hit
    ├── Save state WITH TICKETS
    ↓
OnDeinit()
    ├── Save final state WITH TICKETS
    ├── Clean up chart objects



STATE TRANSITIONS (Simplified 2-State System)
UNTAPPED (🟡 Yellow lines, extending)
    │
    │ [Price enters range OR orders fill]
    ↓
TAPPED (🔴 Red lines, stopped at tap time)
    ├──→ MISSED (No tickets, EA was offline)
    │       ├── BUT can be RECOVERED from MT5 history
    │       └── Mark as MISSED in statistics
    │
    └──→ TRADED (Has stored tickets)
            ├──→ First TP Hit → Cancel remaining orders
            ├──→ Monitor using stored tickets
            └──→ COMPLETE (All orders handled)



File Structure
MQL5/
├── Experts/
│   └── GoldEngulfing_Main.mq5          # Main orchestrator
│
└── Include/
    ├── Config.mqh                        # Inputs, constants, EngulfingSetup struct
    ├── Utils.mqh                         # ID generation, pip value, price checks
    ├── EngulfingDetector.mqh             # Pattern detection & historical scanning
    ├── VisualManager.mqh                 # Line drawing, updating, cleanup
    ├── OrderManager.mqh                  # ✅ DIAGNOSTIC VERSION - Tracks ticket flow
    ├── SetupManager.mqh                  # ✅ TICKET-BASED VALIDATION SYSTEM
    ├── SetupHelpers.mqh                  # ✅ COMPLETE IMPLEMENTATION with MT5 recovery
    ├── StorageSystem.mqh                 # ✅ TICKET-BASED PERSISTENT STORAGE
    └── TableLogger.mqh                   # Simplified logger for 2-STATE system

Files/ (auto-created by EA)
├── GoldEngulfing_setups.json            # ✅ Stores ACTUAL TICKETS (ulong arrays)
├── GoldEngulfing_backups.json           # Append-only backup history
└── GoldEngulfing_logs.json              # Event log



Key Data Structure (Enhanced v2.1)
struct EngulfingSetup {
   // === IDENTITY ===
   string setupID;                    // "Engulf_18122025-1000-B"
   int magicNumber;                   // Generated hash from setupID (FIXED for uniqueness)
   
   // === ✅ TICKET STORAGE (NEW v4.0) ===
   ulong orderTickets[];              // ACTUAL ORDER TICKETS placed
   ulong filledTickets[];             // TICKETS that filled
   ulong cancelledTickets[];          // TICKETS that cancelled
   
   // === TIME TRACKING ===
   datetime engulfingTime;            // Engulfing candle time
   datetime engulfedTime;             // Engulfed candle time
   datetime tappedTime;               // When price entered range
   datetime createdTime;              // When setup was created
   datetime firstOrderTime;           // First order placed time
   datetime firstFillTime;            // First order filled time
   datetime lastActivityTime;         // Last order activity
   datetime completedTime;            // When all orders done
   
   // === PRICE LEVELS ===
   double rangeHigh;                  // Engulfed body high
   double rangeLow;                   // Engulfed body low
   
   // === DIRECTION ===
   bool isBullish;                    // Engulfing direction
   
   // === STATE TRACKING (2-STATE) ===
   int state;                         // UNTAPPED=0, TAPPED=1
   int tradeStatus;                   // MISSED=0, TRADED=1
   bool isComplete;                   // All orders handled?
   bool tapped;                       // Price entered range?
   bool firstTPHit;                   // Cancel rest when true
   
   // === ORDER TRACKING ===
   bool ordersPlacedFlag;             // Were orders placed?
   int ordersPlaced;                  // Total orders placed
   int ordersFilled;                  // Orders that executed
   int ordersCancelled;               // Orders cancelled
   int ordersExpired;                 // Orders that expired
   
   // === POSITION TRACKING ===
   int positionsOpen;                 // Current open positions
   int positionsClosed;               // Total closed positions
   
   // === CLOSE REASON BREAKDOWN ===
   int tpHits;                        // Closed at TP
   int slHits;                        // Closed at SL
   int manualCloses;                  // Manual closes
   int breakEvenCloses;               // Break-even closes
   
   // === FINANCIAL ===
   double totalProfit;                // Net P/L
   double grossProfit;                // Total wins
   double grossLoss;                  // Total losses
   double largestWin;                 // Biggest win
   double largestLoss;                // Biggest loss
   
   // === VISUAL ===
   string lineHighName;               // "EngulfHigh_SetupID"
   string lineLowName;                // "EngulfLow_SetupID"
   
   // === PERFORMANCE METRICS ===
   double winRate;                    // TP/(TP+SL) %
   double profitFactor;               // GrossProfit/|GrossLoss|
   double averageWin;                 // Average TP amount
   double averageLoss;                // Average SL amount
   
   // === LIFECYCLE FLAGS ===
   bool wasTraded;                    // Ever had orders?
   bool wasMissed;                    // EA offline when tapped?
   bool hadFirstTP;                   // First TP ever hit?
}


## Critical Functions

CRITICAL FUNCTIONS v4.0
Pattern Detection (EngulfingDetector.mqh)
ScanHistoricalData() → Scan 14 days, create setups, place orders for untapped

ScanForNewEngulfingPattern() → Real-time detection on new H1 bar

ProcessEngulfingPattern() → Create setup, check tapped, place orders if valid

Order Management (OrderManager.mqh)
PlaceOrders(setup) → STORES ACTUAL TICKETS in setup.orderTickets[]

PlaceSingleOrder() → Place limit order, IMMEDIATELY STORE TICKET

UpdateOrderStatus(setup) → Uses STORED TICKETS to check status

CalculateSetupProfit(setup) → Calculates P/L using FILLED TICKETS

Setup Management (SetupManager.mqh)
ValidateActiveSetupsFromTickets() → VALIDATES AGAINST MT5 HISTORY

MarkSetupAsTapped() → Determines MISSED vs TRADED based on TICKET PRESENCE

CheckTappedSetups() → Monitors using STORED TICKETS

Setup Recovery (SetupHelpers.mqh)
CheckMT5HistoryForSetup() → Checks MT5 trade history for setup trades

RecoverTicketsFromMT5History() → Recovers tickets from MT5 when missing

ManualRecoveryFromMT5() → Manual command to fix missed setups

Storage System (StorageSystem.mqh)
SaveSetupsToFile() → SAVES TICKET ARRAYS to JSON

LoadSetupsFromFile() → LOADS TICKET ARRAYS from JSON

ParseUlongArray() → Special parser for ticket arrays

Visual Management (VisualManager.mqh)
DrawRangeLines() → Yellow dotted lines for UNTAPPED (extending)

RedrawTappedLines() → Red dotted lines stopped at tap time

RestoreVisualLines() → Redraw lines based on stored state

## Persistence (JSON Files)
- `GoldEngulfing_setups.json` → Current state (full tracking v2.4)
- `GoldEngulfing_backups.json` → Append-only history (only when data changes)
- `GoldEngulfing_logs.json` → Event log (state transitions, errors)

-File Locations
Primary: MQL5/Files/GoldEngulfing_setups.json (Current state WITH tickets)
Backup: MQL5/Files/GoldEngulfing_backups.json (Append-only backup)
Logs: MQL5/Files/GoldEngulfing_logs.json (Event log)


## PERSISTENCE SYSTEM v4.0
JSON Structure with Tickets
{
  "version": "3.0",
  "setupCount": 12,
  "setups": [
    {
      "setupID": "Engulf_18122025-1000-B",
      "magicNumber": 123456,
      "orderTickets": [1001001, 1001002, 1001003, ...],  // ACTUAL TICKETS
      "filledTickets": [1001001, 1001003],
      "cancelledTickets": [1001002],
      "state": 1,
      "tradeStatus": 1,
      // ... all other fields
    }
  ]
}


## Detailed Table Logging
When `InpEnableTableLogs = true`, displays:
```
TIME     | BAR | DATE/TIME       | DIR     | BODY(p)| OPEN/CLOSE        | STATUS/REASON
11:20:06 | 4   | 2025.12.18 07:00| BEARISH | 25.2   | 4333.937/4331.418 | TAPPED [Engulf_18122025-0700-B]
11:20:06 | 6   | 2025.12.18 05:00| BULLISH | 14.9   | 4331.812/4333.307 | UNTAPPED [Engulf_18122025-0500-S]
Shows:

All candles scanned (336 bars = 14 days)
Engulfing patterns with Setup ID and state
Rejection reasons (body too small, same direction, not engulfing)

## File Locations
-> Location of Placement of ALL Component Files: 
GoldEngulfing_Main ---> \MQL5\Experts
Rest of Files --------> \MQL5\Experts\Include

## Global Variables:
// Global tracking
EngulfingSetup g_allSetups[];          // ALL setups with tickets
int g_totalSetupsCreated = 0;          // All-time count
int g_totalSetupsTraded = 0;           // Setups with REAL trades
int g_totalSetupsMissed = 0;           // Setups tapped while offline
datetime g_lastBarTime = 0;            // New bar detection
string g_lastSavedJSON = "";           // Backup optimization