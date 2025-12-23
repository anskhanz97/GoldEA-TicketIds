//+------------------------------------------------------------------+
//|                          GoldEngulfingScalper.mq5                 |
//|                     SIMPLIFIED v4.0 - NO RECONSTRUCTION           |
//|                     ✅ PURE TICKET-BASED TRACKING                 |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property version   "4.00"
#property strict

#include "Include/Config.mqh"
#include "Include/Utils.mqh"
#include "Include/StorageSystem.mqh"
#include "Include/VisualManager.mqh"
#include "Include/OrderManager.mqh"
#include "Include/SetupHelpers.mqh"      // ✅ Move BEFORE SetupManager
#include "Include/SetupManager.mqh"       // ✅ Now can use functions from SetupHelpers
#include "Include/TableLogger.mqh"
#include "Include/EngulfingDetector.mqh"

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
//| ✅ ENHANCED: Validate Active Setups with Clear Status Logging    |
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
      
      // ✅ NEW: Determine setup status for logging
      string statusLabel = "";
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         statusLabel = "UNTAPPED (Active)";
      } else if(g_allSetups[i].tradeStatus == TRADE_STATUS_MISSED) {
         statusLabel = "MISSED (EA was off)";
      } else if(g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED) {
         statusLabel = "TRADED";
      }
      
      // ✅ ENHANCED: Print status in the header
      if(InpDebugMode) {
         Print("   🔎 Checking MT5 history for: ", g_allSetups[i].setupID, 
               " | ", statusLabel);
      }
               
      // Check MT5 history FIRST, before checking stored tickets
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
         } else if(g_allSetups[i].tradeStatus == TRADE_STATUS_MISSED) {
            // ✅ NEW: Special logging for confirmed MISSED setups
               Print("      ⚠️ Confirmed MISSED: No orders placed (EA was off when tapped)");
               Print("      📊 Stored tickets: 0 (as expected for MISSED setup)");
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
//| Expert timer function (Updated with Position Tracking)           |
//+------------------------------------------------------------------+
void OnTimer() {
   // Real-time tap detection
   CheckUntappedSetupsRealTime();
   
   // Sync visual lines
   SyncVisualLinesWithState();
   
   // ✅ CRITICAL: Periodic position verification (backup for OnTradeTransaction)
   // This ensures we catch any trades that happened while EA was off
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(!g_allSetups[i].isComplete && g_allSetups[i].state == SETUP_TAPPED) {
         
         // Update order status
         UpdateOrderStatusWithPositions(g_allSetups[i]);
         
         // Check for completion
         if(AreAllOrdersHandled(g_allSetups[i])) {
            MarkSetupAsComplete(i);
         }
      }
   }
   
   // Periodic validation (every 60 seconds)
   static datetime lastValidation = 0;
   if(TimeCurrent() - lastValidation >= 60) {
      ValidateActiveSetupsFromTickets();
      SaveSetupsToFile();
      lastValidation = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| ✅ NEW: Update Order Status INCLUDING Position Tracking          |
//+------------------------------------------------------------------+
void UpdateOrderStatusWithPositions(EngulfingSetup &setup) {
   if(InpDebugMode) {
      Print("🔍 UpdateOrderStatusWithPositions for ", setup.setupID);
   }
   
   // If no tickets stored, use legacy method
   if(ArraySize(setup.orderTickets) == 0) {
      UpdateOrderStatusLegacy(setup);
      return;
   }
   
   // Reset counters
   int pendingCount = 0;
   int filledCount = 0;
   int cancelledCount = 0;
   int openPositions = 0;
   
   ArrayResize(setup.filledTickets, 0);
   ArrayResize(setup.cancelledTickets, 0);
   
   // Check each stored ticket
   for(int i = 0; i < ArraySize(setup.orderTickets); i++) {
      ulong ticket = setup.orderTickets[i];
      
      // Check if still pending
      if(OrderSelect(ticket)) {
         pendingCount++;
         continue;
      }
      
      // Check in history
      if(HistoryOrderSelect(ticket)) {
         ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
         
         if(state == ORDER_STATE_FILLED) {
            filledCount++;
            int idx = ArraySize(setup.filledTickets);
            ArrayResize(setup.filledTickets, idx + 1);
            setup.filledTickets[idx] = ticket;
            
            // ✅ CRITICAL: Check if this filled order has an OPEN position
            bool positionStillOpen = false;
            
            // Get position ID from this order
            if(HistorySelect(setup.createdTime, TimeCurrent())) {
               for(int j = 0; j < HistoryDealsTotal(); j++) {
                  ulong dealTicket = HistoryDealGetTicket(j);
                  
                  if(HistoryDealGetInteger(dealTicket, DEAL_ORDER) == ticket &&
                     HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
                     
                     // Found entry deal - get position ID
                     ulong positionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
                     
                     // Check if position is still open
                     for(int k = 0; k < PositionsTotal(); k++) {
                        ulong posTicket = PositionGetTicket(k);
                        if(posTicket == positionID) {
                           positionStillOpen = true;
                           openPositions++;
                           break;
                        }
                     }
                     break;
                  }
               }
            }
            
         } else if(state == ORDER_STATE_CANCELED) {
            cancelledCount++;
            int idx = ArraySize(setup.cancelledTickets);
            ArrayResize(setup.cancelledTickets, idx + 1);
            setup.cancelledTickets[idx] = ticket;
         }
      }
   }
   
   // Update setup tracking
   setup.ordersPlaced = ArraySize(setup.orderTickets);
   setup.ordersFilled = filledCount;
   setup.ordersCancelled = cancelledCount;
   setup.positionsOpen = openPositions;
   
   if(InpDebugMode) {
      Print("📊 ", setup.setupID, ": ", pendingCount, " pending | ", 
            filledCount, " filled | ", openPositions, " open positions | ",
            cancelledCount, " cancelled");
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
//|                    REAL-TIME TRADE TRACKING SYSTEM                |
//|-------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ Trade Transaction Handler (INSTANT Detection)                 |
//+------------------------------------------------------------------+
void OnTradeTransaction(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result
) {
   // Only process our symbol
   if(trans.symbol != _Symbol) return;
   
   // Get magic number based on transaction type
   ulong magicNumber = 0;
   
   if(trans.type == TRADE_TRANSACTION_ORDER_DELETE || 
      trans.type == TRADE_TRANSACTION_ORDER_ADD) {
      // For order transactions, get magic from order
      if(trans.order > 0) {
         if(OrderSelect(trans.order)) {
            magicNumber = OrderGetInteger(ORDER_MAGIC);
         } else if(HistoryOrderSelect(trans.order)) {
            magicNumber = HistoryOrderGetInteger(trans.order, ORDER_MAGIC);
         }
      }
   } else if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      // For deal transactions, get magic from deal
      if(trans.deal > 0 && HistoryDealSelect(trans.deal)) {
         magicNumber = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
      }
   }
   
   if(magicNumber == 0) return; // Not our trade or couldn't get magic
   
   // Find which setup this belongs to by checking magic number
   int setupIndex = -1;
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].magicNumber == magicNumber) {
         setupIndex = i;
         break;
      }
   }
   
   if(setupIndex < 0) return; // Not our trade
   
   // Handle different transaction types
   switch(trans.type) {
      case TRADE_TRANSACTION_ORDER_DELETE:
         // Pending order cancelled/expired
         HandleOrderCancellation(setupIndex, trans);
         break;
         
      case TRADE_TRANSACTION_DEAL_ADD:
         // Deal executed (order filled OR position closed)
         if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL) {
            // Check if this is an ENTRY or EXIT deal
            if(HistoryDealSelect(trans.deal)) {
               ENUM_DEAL_ENTRY entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
               
               if(entryType == DEAL_ENTRY_IN) {
                  // Order filled → became position
                  HandleOrderFill(setupIndex, trans);
               } else if(entryType == DEAL_ENTRY_OUT) {
                  // Position closed
                  HandlePositionClose(setupIndex, trans);
               }
            }
         }
         break;
   }
}
//+------------------------------------------------------------------+
//| ✅ Handle Order Fill (Pending → Position)                        |
//+------------------------------------------------------------------+
void HandleOrderFill(int setupIndex, const MqlTradeTransaction& trans) {
   g_allSetups[setupIndex].ordersFilled++;
   g_allSetups[setupIndex].positionsOpen++;
   g_allSetups[setupIndex].lastActivityTime = TimeCurrent();
   
   if(g_allSetups[setupIndex].firstFillTime == 0) {
      g_allSetups[setupIndex].firstFillTime = TimeCurrent();
   }
   
   // Add to filledTickets array if not already there
   bool alreadyTracked = false;
   for(int i = 0; i < ArraySize(g_allSetups[setupIndex].filledTickets); i++) {
      if(g_allSetups[setupIndex].filledTickets[i] == trans.order) {
         alreadyTracked = true;
         break;
      }
   }
   
   if(!alreadyTracked) {
      int idx = ArraySize(g_allSetups[setupIndex].filledTickets);
      ArrayResize(g_allSetups[setupIndex].filledTickets, idx + 1);
      g_allSetups[setupIndex].filledTickets[idx] = trans.order;
   }
   
   int pendingCount = CountPendingOrders(g_allSetups[setupIndex].setupID);
   
   Print("✅ ", g_allSetups[setupIndex].setupID, " - Order FILLED @ ", 
         DoubleToString(trans.price, _Digits));
   Print("   → Filled: ", g_allSetups[setupIndex].ordersFilled, "/", 
         g_allSetups[setupIndex].ordersPlaced, 
         " | Pending: ", pendingCount, 
         " | Open: ", g_allSetups[setupIndex].positionsOpen);
   
   SaveSetupsToFile();
}

//+------------------------------------------------------------------+
//| ✅ Handle Position Close (TP/SL/Manual) - THE KEY FUNCTION!      |
//+------------------------------------------------------------------+
void HandlePositionClose(int setupIndex, const MqlTradeTransaction& trans) {
   // ✅ CRITICAL: Decrease open positions count
   if(g_allSetups[setupIndex].positionsOpen > 0) {
      g_allSetups[setupIndex].positionsOpen--;
   }
   
   g_allSetups[setupIndex].positionsClosed++;
   g_allSetups[setupIndex].lastActivityTime = TimeCurrent();
   
   // Get deal details
   double profit = 0;
   string comment = "";
   
   if(HistoryDealSelect(trans.deal)) {
      profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
      comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
      
      profit = profit + commission + swap; // Net profit
   }
   
   // Determine close reason
   string reason = "UNKNOWN";
   
   // Check comment for TP/SL
   if(StringFind(comment, "tp") >= 0 || StringFind(comment, "TP") >= 0) {
      g_allSetups[setupIndex].tpHits++;
      reason = "TP ✅";
      
      // ✅ FIRST TP HIT LOGIC
      if(!g_allSetups[setupIndex].firstTPHit) {
         g_allSetups[setupIndex].firstTPHit = true;
         g_allSetups[setupIndex].hadFirstTP = true;
         
         // Cancel ALL remaining pending orders
         int cancelled = CancelPendingOrders(g_allSetups[setupIndex].setupID);
         g_allSetups[setupIndex].ordersCancelled += cancelled;
         
         Print("🎯 ", g_allSetups[setupIndex].setupID, " - FIRST TP HIT!");
         Print("   → Cancelled ", cancelled, " pending orders");
         
         SendAlert("🎯 First TP Hit: " + g_allSetups[setupIndex].setupID);
      }
      
   } //else if(StringFind(comment, "sl") >= 0 || StringFind(comment, "SL") >= 0) {
     // g_allSetups[setupIndex].slHits++;
     // reason = "SL ❌";
      
      // ✅ CANCEL REMAINING ORDERS ON SL TOO
      //if(g_allSetups[setupIndex].positionsOpen == 0) { // Last position closed at SL
        // int cancelled = CancelPendingOrders(g_allSetups[setupIndex].setupID);
        // if(cancelled > 0) {
        //    g_allSetups[setupIndex].ordersCancelled += cancelled;
        //    Print("   → Cancelled ", cancelled, " pending orders (SL hit)");
        // }
      //}
      
  // } 
  else {
      g_allSetups[setupIndex].manualCloses++;
      reason = "MANUAL 🔧";
      
      // ✅ CANCEL REMAINING ORDERS ON MANUAL CLOSE TOO
      int cancelled = CancelPendingOrders(g_allSetups[setupIndex].setupID);
      if(cancelled > 0) {
         g_allSetups[setupIndex].ordersCancelled += cancelled;
         Print("   → Cancelled ", cancelled, " pending orders (manual close)");
      }
   }
   
   // Update financials
   g_allSetups[setupIndex].totalProfit += profit;
   if(profit > 0) {
      g_allSetups[setupIndex].grossProfit += profit;
      if(profit > g_allSetups[setupIndex].largestWin) {
         g_allSetups[setupIndex].largestWin = profit;
      }
   } else {
      g_allSetups[setupIndex].grossLoss += profit;
      if(profit < g_allSetups[setupIndex].largestLoss) {
         g_allSetups[setupIndex].largestLoss = profit;
      }
   }
   
   int pendingCount = CountPendingOrders(g_allSetups[setupIndex].setupID);
   
   Print("💰 ", g_allSetups[setupIndex].setupID, " - Position CLOSED (", reason, ")");
   Print("   → P/L: $", DoubleToString(profit, 2), 
         " | Open: ", g_allSetups[setupIndex].positionsOpen,
         " | Pending: ", pendingCount);
   Print("   → Total P/L: $", DoubleToString(g_allSetups[setupIndex].totalProfit, 2));
   Print("   → TP:", g_allSetups[setupIndex].tpHits, 
         " SL:", g_allSetups[setupIndex].slHits,
         " Manual:", g_allSetups[setupIndex].manualCloses);
   
   // Check if setup is complete
   if(pendingCount == 0 && g_allSetups[setupIndex].positionsOpen == 0) {
      MarkSetupAsComplete(setupIndex);
   }
   
   SaveSetupsToFile();
   
   // Display live status
   if(InpEnableTableLogs) {
      DisplayLiveSetupStatus(g_allSetups[setupIndex].setupID);
   }
}

//+------------------------------------------------------------------+
//| ✅ Handle Order Cancellation                                     |
//+------------------------------------------------------------------+
void HandleOrderCancellation(int setupIndex, const MqlTradeTransaction& trans) {
   g_allSetups[setupIndex].ordersCancelled++;
   g_allSetups[setupIndex].lastActivityTime = TimeCurrent();
   
   // Add to cancelledTickets array
   int idx = ArraySize(g_allSetups[setupIndex].cancelledTickets);
   ArrayResize(g_allSetups[setupIndex].cancelledTickets, idx + 1);
   g_allSetups[setupIndex].cancelledTickets[idx] = trans.order;
   
   int pendingCount = CountPendingOrders(g_allSetups[setupIndex].setupID);
   int positionCount = g_allSetups[setupIndex].positionsOpen;
   
   Print("🚫 ", g_allSetups[setupIndex].setupID, " - Order cancelled #", trans.order);
   Print("   → Pending: ", pendingCount, " | Open: ", positionCount);
   
   // Check if setup is now complete
   if(pendingCount == 0 && positionCount == 0) {
      MarkSetupAsComplete(setupIndex);
   }
   
   SaveSetupsToFile();
}
