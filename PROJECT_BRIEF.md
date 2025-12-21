Gold Engulfing EA v2.1 - Project Brief

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

2-State System (v2.1)
UNTAPPED (yellow lines, waiting)
    ↓
    ↓ [Price enters range]
    ↓
TAPPED (red lines, stopped at tap time)
    ├─→ MISSED (EA was offline when tapped)
    └─→ TRADED (orders were placed & managed)
         ├─→ First TP Hit → Cancel remaining orders
         └─→ COMPLETE (all orders closed/cancelled)

File Structure
GoldH1EngulfingScalper.mq5      # Main orchestrator (OnInit, OnTick, OnDeinit)
├── Include/
    ├── Config.mqh               # Inputs, constants, EngulfingSetup struct
    ├── Utils.mqh                # ID generation, pip value, price checks
    ├── EngulfingDetector.mqh    # Pattern detection & historical scanning
    ├── VisualManager.mqh        # Line drawing, updating, cleanup
    ├── OrderManager.mqh         # Order placement, cancellation, monitoring
    ├── SetupManager.mqh         # State transitions, tap detection
    ├── SetupHelpers.mqh         # Setup validation, counting, statistics
    ├── StorageSystem.mqh        # JSON save/load with full tracking
    └── TableLogger.mqh          # Compact summaries & detailed tables
Key Data Structure (Enhanced v2.1)


struct EngulfingSetup {
   // === IDENTITY ===
   string setupID;                    // "Engulf_18122025-1000-B"
   int magicNumber;                   // Generated hash from setupID
   
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
```

## Critical Functions

### Pattern Detection
- `ScanHistoricalData()` → Scan 14 days, create setups, check if tapped, place orders
- `ScanForNewEngulfingPattern()` → Real-time detection on new H1 bar
- `ProcessEngulfingPattern()` → Create setup, check tapped, place orders if valid
- `ScanAllCandlesWithLogging()` → Complete candle analysis with detailed table

### State Management
- `CheckUntappedSetups()` → Monitor untapped setups for price entry
- `MarkSetupAsTapped()` → Transition UNTAPPED→TAPPED, determine MISSED vs TRADED
- `CheckTappedSetups()` → Monitor traded setups for TP hits & completion
- `MarkSetupAsComplete()` → All orders closed/cancelled
- `RevalidateUntappedSetups()` → Check if untapped setups were tapped while EA offline

### Order Management
- `PlaceOrders(setup)` → 3 top, 3 mid, 4 bottom zone distribution
- `PlaceSingleOrder()` → Place individual limit order with SL/TP
- `CancelPendingOrders(setupID)` → When first TP hits or manual close
- `UpdateOrderStatus(setup)` → Count pending, open, filled orders
- `CheckFirstTPHit(setup)` → Detect first TP from history
- `CalculateSetupProfit(setup)` → Calculate all financial metrics

### Visual Management
- `DrawRangeLines(setup)` → Yellow dotted lines for UNTAPPED
- `RedrawTappedLines(setup)` → Red dotted lines stopped at tap time
- `UpdateAllUntappedLines()` → Extend yellow lines to current time
- `RestoreVisualLines()` → Redraw all lines on EA restart
- `CleanupOldLines()` → Remove lines older than 14 days
- `DeleteAllEALines()` → Complete cleanup on EA removal

### Persistence
- `SaveSetupsToFile()` → JSON save with backup (only if changed)
- `LoadSetupsFromFile()` → Restore all setups from JSON
- `BuildAllSetupsJSON()` → Serialize complete state to JSON
- `ParseAllSetupsJSON()` → Deserialize JSON to g_allSetups array

### Helpers
- `CanPlaceOrdersForSetup()` → Validate: not placed, not tapped, within 14 days
- `CheckIfRangeTapped()` → Scan price history for range entry
- `GetSetupAge()` → Days since creation
- `ValidateSetupIntegrity()` → Data consistency checks

## Persistence (JSON Files)
- `GoldEngulfing_setups.json` → Current state (full tracking v2.1)
- `GoldEngulfing_backups.json` → Append-only history (only when data changes)
- `GoldEngulfing_logs.json` → Event log (state transitions, errors)
-> Location of Json Files: \MQL5\Files

## Key Design Decisions (v2.1)

1. **2-State System** → Simplified UNTAPPED→TAPPED (no ORDERED state)
2. **Trade Status Tracking** → MISSED vs TRADED within TAPPED state
3. **Time-based Deterministic IDs** → Bulletproof duplicate prevention
4. **First TP = Cancel Rest** → Aggressive risk management
5. **Manual Close Detection** → Also cancels remaining orders
6. **Re-validation on Restart** → Check if untapped setups were tapped while EA offline
7. **Complete Financial Tracking** → TP/SL breakdown, win rate, profit factor
8. **Visual Feedback** → Yellow (untapped, extending) → Red (tapped, stopped at tap time)
9. **Historical Scanning** → Full 14 days on EA start, places orders immediately
10. **State Persistence** → Survives restarts with complete tracking
11. **Backup Only on Change** → Efficient backup system (avoids duplicates)

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

##Global Tracking

int g_totalSetupsCreated = 0;    // All-time setup count
int g_totalSetupsTraded = 0;     // Setups with orders placed
int g_totalSetupsMissed = 0;     // Setups tapped while EA offline

##File Locations
-> Location of Placement of ALL Component Files: 
GoldEngulfing_Main ---> \MQL5\Experts
Rest of Files --------> \MQL5\Experts\Include