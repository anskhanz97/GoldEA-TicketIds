//+------------------------------------------------------------------+
//|                                                       Config.mqh  |
//|                              Gold Engulfing EA - Configuration    |
//|                              v4.0 - TICKET-BASED TRACKING         |
//+------------------------------------------------------------------+

//=== EA INFORMATION ===
#define EA_NAME     "Gold Engulfing Ticket Based Scalper"
#define EA_VERSION  "4.0"

//=== TRADING PARAMETERS ===
input group "=== Basic Settings ==="
input double InpLotSize = 0.01;                    // Lot Size per Order
input int InpSLPips = 40;                          // Stop Loss (pips) [$4]
input int InpTPPips = 80;                          // Take Profit (pips) [$8]

input group "=== Engulfing Detection ==="
input double InpGapTolerance = 2.0;                // Gap Tolerance (pips)
input double InpMinBodyPips = 2.0;                 // Minimum Engulfed Body (pips)

input group "=== Order Distribution ==="
input int InpTopZoneOrders = 3;                    // Top Zone Orders
input int InpMidZoneOrders = 3;                    // Mid Zone Orders
input int InpBottomZoneOrders = 4;                 // Bottom Zone Orders

input group "=== Visual Settings ==="
input color InpUntappedLineColor = clrYellow;      // Untapped Line Color
input color InpTappedLineColor = clrRed;           // Tapped Line Color

input group "=== System Settings ==="
input bool InpEnableTableLogs = true;              // Enable Table Logging
input bool InpEnableAlerts = true;                 // Enable Alerts
input bool InpDebugMode = false;                   // Debug Mode
input int InpLookbackDays = 14;                    // Historical Scan Days

//=== SETUP STATES (2-STATE SYSTEM) ===
#define SETUP_UNTAPPED   0    // Fresh setup, yellow lines, waiting for price
#define SETUP_TAPPED     1    // Price touched range, red lines

//=== TRADE EXECUTION STATUS ===
#define TRADE_STATUS_MISSED   0    // EA was off when tapped
#define TRADE_STATUS_TRADED   1    // Orders placed & managed

//=== FILE PATHS ===
#define FILE_SETUPS    "GoldEngulfing_TicketSetups.json"
#define FILE_LOGS      "GoldEngulfing_TicketLogs.json"

//=== CONSTANTS ===
#define MAX_LOOKBACK_BARS  336    // 14 days * 24 hours

//=== ENHANCED DATA STRUCTURE v3.0 ===
struct EngulfingSetup {
   // ===== IDENTITY =====
   string setupID;
   int magicNumber;
   
   // ===== ✅ NEW: TICKET TRACKING ARRAYS =====
   ulong orderTickets[];         // All order tickets for this setup
   ulong filledTickets[];        // Tickets that got filled (became positions)
   ulong cancelledTickets[];     // Tickets that were cancelled
   
   // ===== TIME TRACKING =====
   datetime engulfingTime;
   datetime engulfedTime;
   datetime tappedTime;
   datetime createdTime;
   datetime firstOrderTime;
   datetime firstFillTime;
   datetime lastActivityTime;
   datetime completedTime;
   
   // ===== PRICE LEVELS =====
   double rangeHigh;
   double rangeLow;
   
   // ===== DIRECTION =====
   bool isBullish;
   
   // ===== STATE TRACKING (2-STATE) =====
   int state;                    // UNTAPPED or TAPPED
   int tradeStatus;              // MISSED or TRADED
   bool isComplete;              // All orders closed/cancelled?
   bool tapped;                  // Has price entered range?
   bool firstTPHit;              // First TP hit, cancel rest
   
   // ===== ORDER TRACKING =====
   bool ordersPlacedFlag;
   int ordersPlaced;
   int ordersFilled;
   int ordersCancelled;
   int ordersExpired;
   
   // ===== POSITION TRACKING =====
   int positionsOpen;
   int positionsClosed;
   
   // ===== CLOSE REASONS =====
   int tpHits;
   int slHits;
   int manualCloses;
   int breakEvenCloses;
   
   // ===== FINANCIAL =====
   double totalProfit;
   double grossProfit;
   double grossLoss;
   double largestWin;
   double largestLoss;
   
   // ===== VISUAL =====
   string lineHighName;
   string lineLowName;
   
   // ===== METRICS =====
   double winRate;
   double profitFactor;
   double averageWin;
   double averageLoss;
   
   // ===== FLAGS =====
   bool wasTraded;
   bool wasMissed;
   bool hadFirstTP;
   
   // ✅ Constructor - Initialize ticket arrays
   EngulfingSetup() {
      setupID = "";
      magicNumber = 0;
      
      // Initialize dynamic arrays
      ArrayResize(orderTickets, 0);
      ArrayResize(filledTickets, 0);
      ArrayResize(cancelledTickets, 0);
      
      engulfingTime = 0;
      engulfedTime = 0;
      tappedTime = 0;
      createdTime = TimeCurrent();
      firstOrderTime = 0;
      firstFillTime = 0;
      lastActivityTime = 0;
      completedTime = 0;
      rangeHigh = 0;
      rangeLow = 0;
      isBullish = false;
      state = SETUP_UNTAPPED;
      tradeStatus = TRADE_STATUS_MISSED;
      isComplete = false;
      tapped = false;
      firstTPHit = false;
      ordersPlacedFlag = false;
      ordersPlaced = 0;
      ordersFilled = 0;
      ordersCancelled = 0;
      ordersExpired = 0;
      positionsOpen = 0;
      positionsClosed = 0;
      tpHits = 0;
      slHits = 0;
      manualCloses = 0;
      breakEvenCloses = 0;
      totalProfit = 0;
      grossProfit = 0;
      grossLoss = 0;
      largestWin = 0;
      largestLoss = 0;
      lineHighName = "";
      lineLowName = "";
      winRate = 0;
      profitFactor = 0;
      averageWin = 0;
      averageLoss = 0;
      wasTraded = false;
      wasMissed = false;
      hadFirstTP = false;
   }
};

//=== Pattern Detection ===
struct PatternData {
   int barIndex;
   datetime candleTime;
   double open;
   double high;
   double low;
   double close;
   string status;
   string reason;
   string setupID;
};

//=== GLOBAL ARRAYS ===
EngulfingSetup g_allSetups[];       // ALL setups (historical + real-time)
PatternData g_allCandles[];         // Candle analysis data

//=== TRACKING VARIABLES ===
datetime g_lastBarTime = 0;
int g_totalSetupsCreated = 0;
int g_totalSetupsTraded = 0;
int g_totalSetupsMissed = 0;

//+------------------------------------------------------------------+
//| Validate Input Parameters                                         |
//+------------------------------------------------------------------+
bool ValidateInputs() {
   if(InpLotSize <= 0) {
      Print("ERROR: Lot size must be positive");
      return false;
   }
   
   if(InpSLPips <= 0 || InpTPPips <= 0) {
      Print("ERROR: SL and TP must be positive");
      return false;
   }
   
   if(InpTPPips <= InpSLPips) {
      Print("WARNING: TP should be greater than SL for 1:2 RR");
   }
   
   if(InpTopZoneOrders + InpMidZoneOrders + InpBottomZoneOrders != 10) {
      Print("ERROR: Total orders must equal 10");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get State Name                                                    |
//+------------------------------------------------------------------+
string GetStateName(int state) {
   switch(state) {
      case SETUP_UNTAPPED:  return "UNTAPPED";
      case SETUP_TAPPED:    return "TAPPED";
      default:              return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Get Trade Status Name                                            |
//+------------------------------------------------------------------+
string GetTradeStatusName(int status) {
   switch(status) {
      case TRADE_STATUS_MISSED:  return "MISSED";
      case TRADE_STATUS_TRADED:  return "TRADED";
      default:                   return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
