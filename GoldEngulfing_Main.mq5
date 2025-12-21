//+------------------------------------------------------------------+
//|                                  GoldH1EngulfingScalper       |
//|                    Gold Engulfing EA - Main File v2.1         |
//|                    2-STATE SYSTEM: UNTAPPED → TAPPED          |
//+---------------------------------------------------------------+

#property copyright "Your Name"
#property link      ""
#property version   "2.10"
#property description "Gold H1 Engulfing Scalper"
#property description "H1 Timeframe | XAUUSD Only"
#property description "10 Limit Orders per Setup | 1:2 RR"
#property strict

// Include all module files
#include "Include/Config.mqh"
#include "Include/Utils.mqh"
#include "Include/StorageSystem.mqh"
#include "Include/VisualManager.mqh"
#include "Include/OrderManager.mqh"
#include "Include/SetupHelpers.mqh"
#include "Include/SetupManager.mqh"
#include "Include/TableLogger.mqh"
#include "Include/EngulfingDetector.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function |
//+------------------------------------------------------------------+
int OnInit() {   
   // Validate inputs
   if(!ValidateInputs()) {
      //Print("❌ Input validation failed");
      return INIT_PARAMETERS_INCORRECT;
   }
   //Print("✅ Input validation passed");
   
   // Initialize storage system
   if(!InitializeStorage()) {
     // Print("⚠️ Storage system initialization failed");
   } else {
     // Print("✅ Storage system initialized");
   }
   
   // Load saved setups
  // Print("\n📂 Loading saved setups from file...");
   LoadSetupsFromFile();
   Print("   Loaded ", ArraySize(g_allSetups), " setups from file");
   
   // Re-validate all untapped setups (check if they were tapped while EA was off)
   //Print("\n🔄 Re-validating untapped setups from saved data...");
   RevalidateUntappedSetups();
   
   // Count setup states BEFORE historical scan
   int untappedBefore = 0;
   int tappedBefore = 0;
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED) untappedBefore++;
      else if(g_allSetups[i].state == SETUP_TAPPED) tappedBefore++;
   }
  // Print("   Setups before scan: Untapped=", untappedBefore, " Tapped=", tappedBefore);
   
   // Restore visual lines
   //Print("\n🎨 Restoring visual lines...");
   RestoreVisualLines();
   
   // Scan historical data (14 days)
  // Print("\n📊 Starting historical scan (14 days)...");
   ScanHistoricalData();
   
   // Count setup states AFTER historical scan
   int untappedAfter = 0;
   int tappedAfter = 0;
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED) untappedAfter++;
      else if(g_allSetups[i].state == SETUP_TAPPED) tappedAfter++;
   }
   Print("   Setups after scan: Untapped=", untappedAfter, " Tapped=", tappedAfter);
   
   // NOW CHECK WHICH SETUPS NEED ORDERS
   //Print("\n🔍 Checking which setups need orders...");
   int needsOrders = 0;
   int alreadyHasOrders = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         if(!g_allSetups[i].ordersPlacedFlag) {
            needsOrders++;
            Print("   Setup ", g_allSetups[i].setupID, " needs orders (ordersPlacedFlag=false)");
            
            // Try to place orders NOW
            bool canPlace = CanPlaceOrdersForSetup(g_allSetups[i]);
            if(canPlace) {
              // Print("   ✅ Attempting to place orders for: ", g_allSetups[i].setupID);
               PlaceOrders(g_allSetups[i]);
               g_allSetups[i].ordersPlacedFlag = true;
            } else {
               Print("   ❌ Cannot place orders for: ", g_allSetups[i].setupID);
               Print("      Reason: tapped=", g_allSetups[i].tapped, 
                     " ordersPlacedFlag=", g_allSetups[i].ordersPlacedFlag,
                     " age=", GetSetupAge(g_allSetups[i]), " days");
            }
         } else {
            alreadyHasOrders++;
           // Print("   Setup ", g_allSetups[i].setupID, " already has orders (ordersPlacedFlag=true)");
         }
      }
   }
   
  // Print("\n📋 Order placement summary:");
  // Print("   Setups needing orders: ", needsOrders);
  // Print("   Setups with orders:    ", alreadyHasOrders);
   
   // Call ScanForNewEngulfingPattern on EA start/restart
  // Print("\n🔍 Checking for new engulfing patterns on EA start...");
   ScanForNewEngulfingPattern();
   
   // Call ScanAllCandlesWithLogging on EA start/restart (shows detailed candle table)
  // Print("\n📋 Running complete candle analysis...");
   ScanAllCandlesWithLogging(MAX_LOOKBACK_BARS, "📋 INITIAL CANDLE ANALYSIS (14 DAYS)");
   
   // Display summary
   DisplayCompactSummary();
   PrintSetupSummary();
   
   // Save state
   SaveSetupsToFile();
   
   //Print("\n✅ EA Initialized Successfully");
   //Print("╔════════════════════════════════════════════════════════════════╗");
   //Print("║  Monitoring ", ArraySize(g_allSetups), " total setups");
   //Print("║  Active Untapped: ", GetActiveUntappedCount());
   //Print("║  Active Traded: ", GetActiveTradedCount());
   //Print("╚════════════════════════════════════════════════════════════════╝\n");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Save final state to file
   SaveSetupsToFile();
   
   // Complete chart cleanup when EA is removed/detached
   DeleteAllEALines();
   
   //Print("🧹 EA Removed - Chart completely cleaned");
   //Print("Deinit Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   // Check for new bar
   if(!IsNewBar()) return;
   
   Print("\n⏰ New H1 Bar - ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   
   // 1. Scan for new engulfing pattern
   ScanForNewEngulfingPattern();
   
   // 2. Check untapped setups (has price entered range?)
   CheckUntappedSetups();
   
   // 3. Check tapped setups (monitor orders, TP hits, completion)
   CheckTappedSetups();
   
   // 4. Check for manual closes
   CheckManualCloses();
   
   // 5. Update visual lines
   UpdateAllUntappedLines();
   
   // 6. Cleanup old lines (14+ days)
   CleanupOldLines();
   
   // 7. Save state to file
   SaveSetupsToFile();
   
   // 8. Display compact summary
   if(InpEnableTableLogs) {
      DisplayCompactSummary();
   }
}

//+------------------------------------------------------------------+
//| Expert timer function (Optional - runs every minute)             |
//+------------------------------------------------------------------+
void OnTimer() {
   // Optional: Periodic checks can be added here
   // For now, all logic is in OnTick()
}

//+------------------------------------------------------------------+