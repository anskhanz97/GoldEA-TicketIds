//+------------------------------------------------------------------+
//|                          GoldEngulfingScalper.mq5                 |
//|                     SIMPLIFIED v4.0 - NO RECONSTRUCTION           |
//|                     ✅ PURE TICKET-BASED TRACKING                 |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property version   "4.00"
#property strict

// Include all module files (EXCEPT HistoryReconstructor.mqh)
#include "Include/Config.mqh"
#include "Include/Utils.mqh"
#include "Include/StorageSystem.mqh"
#include "Include/VisualManager.mqh"
#include "Include/OrderManager.mqh"
#include "Include/SetupHelpers.mqh"
#include "Include/SetupManager.mqh"
#include "Include/TableLogger.mqh"
#include "Include/EngulfingDetector.mqh"
// ❌ REMOVED: #include "Include/HistoryReconstructor.mqh"
// ❌ REMOVED: #include "Include/HistoryDiagnostics.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {   
   Print("\n╔════════════════════════════════════════════════════════════════╗");
   Print("║        Gold Engulfing EA v4.0 - STARTING                      ║");
   Print("║        PURE TICKET-BASED TRACKING (No Reconstruction)         ║");
   Print("╚════════════════════════════════════════════════════════════════╝\n");
   
   // Validate inputs
   if(!ValidateInputs()) {
      Print("❌ Invalid input parameters");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Initialize storage system
   if(!InitializeStorage()) {
      Print("⚠️ Storage system initialization failed");
      return INIT_FAILED;
   }
   
   // Load saved setups from file
   if(!LoadSetupsFromFile()) {
      Print("⚠️ Failed to load setups from file - continuing with empty state");
   }
   
   Print("📂 Loaded ", ArraySize(g_allSetups), " setups from persistent storage\n");
   
   // ✅ SIMPLIFIED STARTUP FLOW
   Print("🔄 Syncing with current market state...\n");
   
   // Step 1: Scan historical data for NEW patterns only
   Print("📊 Step 1: Scanning for engulfing patterns...");
   ScanHistoricalData();
   
   // Step 2: Update existing setups using stored tickets + MT5 history verification
   Print("🔍 Step 2: Updating setup states (checking MT5 history)...");
   ValidateActiveSetupsFromTickets();
   
   // Step 3: Check for any missed taps
   Print("⚡ Step 3: Checking for missed taps...");
   CheckForMissedTaps();
   
   Print("✅ Sync complete!\n");
   
   // Count and display detailed setup states
   int untappedCount = 0;
   int tappedCount = 0;
   int tradedCount = 0;
   int missedCount = 0;
   int completeCount = 0;
   
   // Aggregate trade statistics
   int totalFills = 0;
   int totalCancelled = 0;
   int totalTPs = 0;
   int totalSLs = 0;
   double totalProfit = 0;
   
   string tradedSetupIDs[];
   string recentUntradedIDs[];
   ArrayResize(tradedSetupIDs, 0);
   ArrayResize(recentUntradedIDs, 0);
   
   datetime threeDaysAgo = TimeCurrent() - (3 * 86400);
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         untappedCount++;
      } else if(g_allSetups[i].state == SETUP_TAPPED) {
         tappedCount++;
         
         // ✅ FIX: Only count as TRADED if it actually has filled orders OR stored tickets
         bool hasRealTrades = (g_allSetups[i].ordersFilled > 0 || 
                              ArraySize(g_allSetups[i].orderTickets) > 0);
         
         if(g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED && hasRealTrades) {
            tradedCount++;
            
            // Store setup ID (sorted by date, newest first)
            int idx = ArraySize(tradedSetupIDs);
            ArrayResize(tradedSetupIDs, idx + 1);
            tradedSetupIDs[idx] = g_allSetups[i].setupID;
            
            // Aggregate stats
            totalFills += g_allSetups[i].ordersFilled;
            totalCancelled += g_allSetups[i].ordersCancelled;
            totalTPs += g_allSetups[i].tpHits;
            totalSLs += g_allSetups[i].slHits;
            totalProfit += g_allSetups[i].totalProfit;
            
         } else {
            // ✅ FIX: If marked TRADED but has no actual trades, it's MISSED
            if(g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED && !hasRealTrades) {
               g_allSetups[i].tradeStatus = TRADE_STATUS_MISSED;
               g_allSetups[i].wasMissed = true;
            }
            
            missedCount++;
            
            // Track recent missed setups (last 3 days)
            if(g_allSetups[i].engulfingTime >= threeDaysAgo) {
               int idx = ArraySize(recentUntradedIDs);
               ArrayResize(recentUntradedIDs, idx + 1);
               recentUntradedIDs[idx] = g_allSetups[i].setupID;
            }
         }
         
         if(g_allSetups[i].isComplete) completeCount++;
      }
   }
   
   Print("╔════════════════════════════════════════════════════════════════╗");
   Print("║                    SETUP STATE SUMMARY                        ║");
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print(StringFormat("║  Total Setups:     %-4d                                    ║", ArraySize(g_allSetups)));
   Print(StringFormat("║  UNTAPPED:         %-4d (Yellow, waiting)                  ║", untappedCount));
   Print(StringFormat("║  TAPPED:           %-4d (Red)                              ║", tappedCount));
   Print(StringFormat("║    → Traded:       %-4d (Has filled orders)                ║", tradedCount));
   Print(StringFormat("║    → Missed:       %-4d (No fills)                         ║", missedCount));
   Print(StringFormat("║    → Complete:     %-4d (All closed)                       ║", completeCount));
   Print("╠════════════════════════════════════════════════════════════════╣");
   
   if(tradedCount > 0) {
      Print("║                    TRADED SETUPS DETAIL                       ║");
      Print("╠════════════════════════════════════════════════════════════════╣");
      Print(StringFormat("║  Total Orders Filled:      %-4d                            ║", totalFills));
      Print(StringFormat("║  Total Orders Cancelled:   %-4d                            ║", totalCancelled));
      Print(StringFormat("║  TP Hits:                  %-4d                            ║", totalTPs));
      Print(StringFormat("║  SL Hits:                  %-4d                            ║", totalSLs));
      Print(StringFormat("║  Total Profit:             $%-8.2f                      ║", totalProfit));
      Print("╠════════════════════════════════════════════════════════════════╣");
      Print("║                    TRADED SETUP IDs                           ║");
      Print("╠════════════════════════════════════════════════════════════════╣");
      
      // Sort traded setups by date (newest first)
      SortSetupIDsByDate(tradedSetupIDs, false);
      
      // Show all traded setups (or limit to 15)
      int displayCount = MathMin(15, ArraySize(tradedSetupIDs));
      for(int i = 0; i < displayCount; i++) {
         int setupIdx = FindSetupByID(tradedSetupIDs[i]);
         if(setupIdx >= 0) {
            string dir = g_allSetups[setupIdx].isBullish ? "📈" : "📉";
            string dateStr = TimeToString(g_allSetups[setupIdx].engulfingTime, TIME_DATE);
            
            Print(StringFormat("║  %s %s (%s) | F:%d C:%d | TP:%d SL:%d | $%.2f",
                              dir,
                              tradedSetupIDs[i],
                              dateStr,
                              g_allSetups[setupIdx].ordersFilled,
                              g_allSetups[setupIdx].ordersCancelled,
                              g_allSetups[setupIdx].tpHits,
                              g_allSetups[setupIdx].slHits,
                              g_allSetups[setupIdx].totalProfit));
         }
      }
      
      if(ArraySize(tradedSetupIDs) > 15) {
         Print(StringFormat("║  ... and %d more (check logs for full list)              ║", 
                           ArraySize(tradedSetupIDs) - 15));
      }
   } else {
      Print("║  No traded setups with fills yet                             ║");
   }
   
   // ✅ NEW: Show recent missed/untraded setups (last 3 days)
   if(ArraySize(recentUntradedIDs) > 0) {
      Print("╠════════════════════════════════════════════════════════════════╣");
      Print("║              RECENT MISSED SETUPS (Last 3 Days)              ║");
      Print("╠════════════════════════════════════════════════════════════════╣");
      
      SortSetupIDsByDate(recentUntradedIDs, false);
      
      int displayCount = MathMin(10, ArraySize(recentUntradedIDs));
      for(int i = 0; i < displayCount; i++) {
         int setupIdx = FindSetupByID(recentUntradedIDs[i]);
         if(setupIdx >= 0) {
            string dir = g_allSetups[setupIdx].isBullish ? "📈" : "📉";
            string dateStr = TimeToString(g_allSetups[setupIdx].engulfingTime, TIME_DATE|TIME_MINUTES);
            bool hasOrders = (ArraySize(g_allSetups[setupIdx].orderTickets) > 0);
            string reason = hasOrders ? "Orders placed but not filled" : "EA was off";
            
            Print(StringFormat("║  %s %s | %s",
                              dir,
                              recentUntradedIDs[i],
                              reason));
         }
      }
      
      if(ArraySize(recentUntradedIDs) > 10) {
         Print(StringFormat("║  ... and %d more missed setups                               ║", 
                           ArraySize(recentUntradedIDs) - 10));
      }
   }
   
   Print("╚════════════════════════════════════════════════════════════════╝\n");
   
   // Restore visual lines
   Print("🎨 Restoring visual lines on chart...");
   RestoreVisualLines();
   
   // Place orders for untapped setups
   int ordersPlacedCount = 0;
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED && !g_allSetups[i].ordersPlacedFlag) {
         if(CanPlaceOrdersForSetup(g_allSetups[i])) {
            if(PlaceOrders(g_allSetups[i])) {
               g_allSetups[i].ordersPlacedFlag = true;
               ordersPlacedCount++;
            }
         }
      }
   }
   
   if(ordersPlacedCount > 0) {
      Print("📝 Placed orders for ", ordersPlacedCount, " untapped setups");
   }
   
   // Scan for new patterns on startup
   Print("🔍 Scanning for new engulfing patterns...");
   ScanForNewEngulfingPattern();
   
   // Display summary table
   if(InpEnableTableLogs) {
      DisplayCompactSummary();
   }
   
   // ❌ REMOVED: PrintSetupSummary() - now consolidated above
   
   // Save current state
   if(!SaveSetupsToFile()) {
      Print("⚠️ Failed to save initial state to file");
   }
   
   // Set up timer
   EventSetTimer(1);
   
   Print("\n✅ ═══════════════════════════════════════════════════════════");
   Print("✅ EA INITIALIZATION COMPLETE");
   Print("✅ Monitoring: ", untappedCount, " untapped setups");
   Print("✅ Tracking: ", tradedCount, " active trades");
   Print("✅ ═══════════════════════════════════════════════════════════\n");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| ✅ FIXED: Validate Active Setups - CHECK MT5 HISTORY FIRST!      |
//+------------------------------------------------------------------+
void ValidateActiveSetupsFromTickets() {
   Print("\n🔍 Validating active setups (checking MT5 history first)...\n");
   
   int validatedCount = 0;
   int updatedCount = 0;
   int recoveredCount = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      // Skip completed setups
      if(g_allSetups[i].isComplete) continue;
      
      // Only validate recent setups
      int ageInDays = (int)((TimeCurrent() - g_allSetups[i].engulfingTime) / 86400);
      if(ageInDays > 7) continue;
      
      validatedCount++;
      
      // ✅ CRITICAL FIX: Check MT5 history FIRST, before checking stored tickets
      bool hasTradesInMT5 = CheckMT5HistoryForSetup(g_allSetups[i]);
      int storedTickets = ArraySize(g_allSetups[i].orderTickets);
      
      // Case 1: Has trades in MT5 but no stored tickets (RECOVERY NEEDED)
      if(hasTradesInMT5 && storedTickets == 0) {
         Print("   🔧 RECOVERY: ", g_allSetups[i].setupID, " has MT5 trades but no stored tickets!");
         
         // Reconstruct ticket array from MT5 history
         RecoverTicketsFromMT5History(g_allSetups[i]);
         
         // Update state to TRADED
         g_allSetups[i].state = SETUP_TAPPED;
         g_allSetups[i].tapped = true;
         g_allSetups[i].tradeStatus = TRADE_STATUS_TRADED;
         g_allSetups[i].wasTraded = true;
         
         // Update financials
         CalculateSetupProfit(g_allSetups[i]);
         RedrawTappedLines(g_allSetups[i]);
         
         recoveredCount++;
         updatedCount++;
         
         Print("      ✅ Recovered ", ArraySize(g_allSetups[i].orderTickets), " tickets from MT5");
         continue;
      }
      
      // Case 2: No trades in MT5 and no stored tickets
      if(!hasTradesInMT5 && storedTickets == 0) {
         // Check if tapped
         if(g_allSetups[i].state == SETUP_UNTAPPED) {
            bool wasTapped = CheckIfRangeTappedSinceCreation(g_allSetups[i]);
            
            if(wasTapped) {
               Print("   ⚠️ ", g_allSetups[i].setupID, " was tapped with no trades → MISSED");
               g_allSetups[i].state = SETUP_TAPPED;
               g_allSetups[i].tapped = true;
               g_allSetups[i].tradeStatus = TRADE_STATUS_MISSED;
               g_allSetups[i].wasMissed = true;
               g_totalSetupsMissed++;
               
               RedrawTappedLines(g_allSetups[i]);
               updatedCount++;
            }
         }
         continue;
      }
      
      // Case 3: We have tickets - update their status
      if(storedTickets > 0) {
         UpdateOrderStatus(g_allSetups[i]);
         
         // Update state if needed
         if(g_allSetups[i].state == SETUP_UNTAPPED && g_allSetups[i].ordersFilled > 0) {
            Print("   🔴 ", g_allSetups[i].setupID, " → TRADED");
            g_allSetups[i].state = SETUP_TAPPED;
            g_allSetups[i].tapped = true;
            g_allSetups[i].tradeStatus = TRADE_STATUS_TRADED;
            g_allSetups[i].wasTraded = true;
            g_totalSetupsTraded++;
            
            CalculateSetupProfit(g_allSetups[i]);
            RedrawTappedLines(g_allSetups[i]);
            updatedCount++;
         }
         
         // Update financials
         if(g_allSetups[i].ordersFilled > 0) {
            CalculateSetupProfit(g_allSetups[i]);
         }
         
         // Check if complete
         if(AreAllOrdersHandled(g_allSetups[i]) && !g_allSetups[i].isComplete) {
            MarkSetupAsComplete(i);
            updatedCount++;
         }
      }
   }
   
   if(recoveredCount > 0) {
      Print("\n🔧 ═══════════════════════════════════════════════════════");
      Print("🔧 RECOVERED ", recoveredCount, " setups from MT5 history!");
      Print("🔧 These were marked MISSED but actually had trades");
      Print("🔧 ═══════════════════════════════════════════════════════\n");
   }
   
   Print("✅ Validated ", validatedCount, " setups (", updatedCount, " updated, ", recoveredCount, " recovered)\n");
}

//+------------------------------------------------------------------+
//| ✅ NEW: Check for Missed Taps (Simple Price Range Check)         |
//+------------------------------------------------------------------+
void CheckForMissedTaps() {
   int missedCount = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      // Only check untapped setups with no tickets
      if(g_allSetups[i].state == SETUP_UNTAPPED && 
         ArraySize(g_allSetups[i].orderTickets) == 0) {
         
         bool wasTapped = CheckIfRangeTappedSinceCreation(g_allSetups[i]);
         
         if(wasTapped) {
            g_allSetups[i].state = SETUP_TAPPED;
            g_allSetups[i].tapped = true;
            g_allSetups[i].tradeStatus = TRADE_STATUS_MISSED;
            g_allSetups[i].wasMissed = true;
            g_totalSetupsMissed++;
            
            RedrawTappedLines(g_allSetups[i]);
            missedCount++;
            
            Print("   ⚠️ Missed: ", g_allSetups[i].setupID);
         }
      }
   }
   
   if(missedCount > 0) {
      Print("Found ", missedCount, " missed taps");
   }
}

//+------------------------------------------------------------------+
//| Sort Setup IDs by Date                                           |
//+------------------------------------------------------------------+
void SortSetupIDsByDate(string &setupIDs[], bool ascending = true) {
   int count = ArraySize(setupIDs);
   if(count <= 1) return;
   
   // Bubble sort by engulfing time
   for(int i = 0; i < count - 1; i++) {
      for(int j = 0; j < count - i - 1; j++) {
         int idx1 = FindSetupByID(setupIDs[j]);
         int idx2 = FindSetupByID(setupIDs[j + 1]);
         
         if(idx1 < 0 || idx2 < 0) continue;
         
         datetime time1 = g_allSetups[idx1].engulfingTime;
         datetime time2 = g_allSetups[idx2].engulfingTime;
         
         bool shouldSwap = ascending ? (time1 > time2) : (time1 < time2);
         
         if(shouldSwap) {
            string temp = setupIDs[j];
            setupIDs[j] = setupIDs[j + 1];
            setupIDs[j + 1] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("\n╔════════════════════════════════════════════════════════════════╗");
   Print("║                    EA SHUTTING DOWN                           ║");
   Print("╚════════════════════════════════════════════════════════════════╝");
   
   EventKillTimer();
   
   if(!SaveSetupsToFile()) {
      Print("⚠️ Failed to save final state");
   } else {
      Print("💾 Final state saved successfully");
   }
   
   DeleteAllEALines();
   Print("🧹 Chart cleaned");
   
   string reasonText = "";
   switch(reason) {
      case REASON_PROGRAM:     reasonText = "EA removed manually"; break;
      case REASON_REMOVE:      reasonText = "EA deleted from chart"; break;
      case REASON_RECOMPILE:   reasonText = "EA recompiled"; break;
      case REASON_CHARTCHANGE: reasonText = "Chart changed"; break;
      case REASON_CHARTCLOSE:  reasonText = "Chart closed"; break;
      case REASON_PARAMETERS:  reasonText = "Parameters changed"; break;
      default:                 reasonText = "Unknown"; break;
   }
   
   Print("Shutdown reason: ", reasonText);
   Print("\n✅ EA Shutdown Complete\n");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   if(!IsNewBar()) return;
   
   Print("\n⏰ NEW H1 BAR: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   
   // 1. Scan for new patterns
   ScanForNewEngulfingPattern();
   
   // 2. Check untapped setups
   CheckUntappedSetups();
   
   // 3. Monitor tapped setups
   CheckTappedSetups();
   
   // 4. Detect manual closes
   CheckManualCloses();
   
   // 5. Update visuals
   UpdateAllUntappedLines();
   CleanupOldLines();
   
   // 6. Save state
   SaveSetupsToFile();
   
   // 7. Display summary
   if(InpEnableTableLogs) {
      DisplayCompactSummary();
   }
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer() {
   // Real-time tap detection
   CheckUntappedSetupsRealTime();
   
   // Sync visual lines
   SyncVisualLinesWithState();
   
   // Periodic ticket validation (every 60 seconds)
   static datetime lastValidation = 0;
   if(TimeCurrent() - lastValidation >= 60) {
      ValidateActiveSetupsFromTickets();
      lastValidation = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Real-Time Tap Detection                                          |
//+------------------------------------------------------------------+
void CheckUntappedSetupsRealTime() {
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentPrice = (currentBid + currentAsk) / 2.0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         if(IsPriceInRange(currentPrice, g_allSetups[i].rangeHigh, g_allSetups[i].rangeLow)) {
            MarkSetupAsTapped(i);
            SaveSetupsToFile();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Sync Visual Lines with State                                    |
//+------------------------------------------------------------------+
void SyncVisualLinesWithState() {
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(ObjectFind(0, g_allSetups[i].lineHighName) < 0) continue;
      
      color currentColor = (color)ObjectGetInteger(0, g_allSetups[i].lineHighName, OBJPROP_COLOR);
      color expectedColor = (g_allSetups[i].state == SETUP_UNTAPPED) ? 
                           InpUntappedLineColor : InpTappedLineColor;
      
      if(currentColor != expectedColor) {
         if(g_allSetups[i].state == SETUP_UNTAPPED) {
            DrawRangeLines(g_allSetups[i]);
         } else {
            RedrawTappedLines(g_allSetups[i]);
         }
      }
   }
}

//+------------------------------------------------------------------+