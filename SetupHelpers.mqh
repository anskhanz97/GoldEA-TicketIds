//+------------------------------------------------------------------+
//|                                            SetupHelpers.mqh       |
//|                    Gold Engulfing EA - Helper Functions v4.0      |
//|                    ✅ COMPLETE IMPLEMENTATION                     |
//+------------------------------------------------------------------+

// Forward declarations
bool CheckMT5HistoryForSetup(EngulfingSetup &setup);
void RecoverTicketsFromMT5History(EngulfingSetup &setup);

//+------------------------------------------------------------------+
//| Revalidate Untapped Setups (Check if still valid)               |
//+------------------------------------------------------------------+
void RevalidateUntappedSetups() {
   Print("\n🔍 Revalidating untapped setups...");
   
   int revalidatedCount = 0;
   int tappedCount = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         revalidatedCount++;
         
         // Check if range was tapped since creation
         bool wasTapped = CheckIfRangeTappedSinceCreation(g_allSetups[i]);
         
         if(wasTapped) {
            // Determine if MISSED or TRADED based on tickets
            if(ArraySize(g_allSetups[i].orderTickets) > 0) {
               // Has tickets → TRADED
               g_allSetups[i].state = SETUP_TAPPED;
               g_allSetups[i].tapped = true;
               g_allSetups[i].tradeStatus = TRADE_STATUS_TRADED;
               g_allSetups[i].wasTraded = true;
               g_totalSetupsTraded++;
            } else {
               // No tickets → MISSED
               g_allSetups[i].state = SETUP_TAPPED;
               g_allSetups[i].tapped = true;
               g_allSetups[i].tradeStatus = TRADE_STATUS_MISSED;
               g_allSetups[i].wasMissed = true;
               g_totalSetupsMissed++;
            }
            
            g_allSetups[i].tappedTime = TimeCurrent();
            RedrawTappedLines(g_allSetups[i]);
            tappedCount++;
            
            Print("   ⚠️ ", g_allSetups[i].setupID, " was tapped → Status: ", 
                  GetTradeStatusName(g_allSetups[i].tradeStatus));
         }
      }
   }
   
   Print("✅ Revalidated ", revalidatedCount, " setups (", tappedCount, " found tapped)\n");
}

//+------------------------------------------------------------------+
//| ✅ ENHANCED: Check MT5 History + Show Pending Orders Info        |
//+------------------------------------------------------------------+
bool CheckMT5HistoryForSetup(EngulfingSetup &setup) {
   // 🔍 DIAGNOSTIC: Show what we're looking for
   if(InpDebugMode) {
      Print("      Magic: ", setup.magicNumber);
      Print("      Created: ", TimeToString(setup.createdTime, TIME_DATE|TIME_MINUTES));
      
       // ✅ NEW: Show pending orders count for active setups
      if(setup.state == SETUP_UNTAPPED) {
         int pendingCount = CountPendingOrders(setup.setupID);
         if(pendingCount > 0) {
            Print("      📊 Pending Orders: ", pendingCount, " (still active, not in history yet)");
         }
      }
   }
   
   // Load history from setup creation time (use engulfingTime for broader search)
   datetime searchStart = setup.engulfingTime - 3600; // 1 hour before
   datetime searchEnd = TimeCurrent();
   
   if(!HistorySelect(searchStart, searchEnd)) {
      if(InpDebugMode) Print("      ❌ HistorySelect failed!");
      return false;
   }
   
   int totalHistoryOrders = HistoryOrdersTotal();
   int matchedOrders = 0;
   int filledOrders = 0;
   
      if(InpDebugMode) {
      // ✅ ENHANCED: Explain what "Total history orders" means
      if(totalHistoryOrders == 0 && setup.state == SETUP_UNTAPPED) {
         Print("      📊 Total history orders: ", totalHistoryOrders, 
               " (Orders still pending, will appear here when filled/cancelled)");
      } else {
         Print("      📊 Total history orders: ", totalHistoryOrders);
      }
   }
   
   // ✅ FIX: Search by BOTH magic number AND comment (fallback)
   for(int i = 0; i < totalHistoryOrders; i++) {
      ulong ticket = HistoryOrderGetTicket(i);
      if(ticket <= 0) continue;
      
      int orderMagic = (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC);
      string orderSymbol = HistoryOrderGetString(ticket, ORDER_SYMBOL);
      string orderComment = HistoryOrderGetString(ticket, ORDER_COMMENT);
      
      // Match by symbol AND (magic OR comment contains setupID)
      bool magicMatch = (orderMagic == setup.magicNumber);
      bool commentMatch = (StringFind(orderComment, setup.setupID) >= 0);
      
      if(orderSymbol == _Symbol && (magicMatch || commentMatch)) {
         matchedOrders++;
         
         // Found an order for this setup
         ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
         
         if(InpDebugMode) {
            Print("      ✅ Found order #", ticket, " | Magic: ", orderMagic, 
                  " | Comment: ", orderComment, " | State: ", EnumToString(state));
         }
         
         // If any order was filled, this setup was TRADED
         if(state == ORDER_STATE_FILLED) {
            filledOrders++;
         }
      }
   }
   
   if(InpDebugMode) {
      Print("      📈 Matched: ", matchedOrders, " orders | Filled: ", filledOrders);
   }
   
   return (filledOrders > 0);
}

//+------------------------------------------------------------------+
//| ✅ NEW: Recover Tickets from MT5 History (WITH COMMENT FALLBACK) |
//+------------------------------------------------------------------+
void RecoverTicketsFromMT5History(EngulfingSetup &setup) {
   // Clear existing arrays
   ArrayResize(setup.orderTickets, 0);
   ArrayResize(setup.filledTickets, 0);
   ArrayResize(setup.cancelledTickets, 0);
   
   datetime searchStart = setup.engulfingTime - 3600; // 1 hour before
   
   if(!HistorySelect(searchStart, TimeCurrent())) {
      return;
   }
   
   // Collect all orders for this setup
   for(int i = 0; i < HistoryOrdersTotal(); i++) {
      ulong ticket = HistoryOrderGetTicket(i);
      if(ticket <= 0) continue;
      
      int orderMagic = (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC);
      string orderSymbol = HistoryOrderGetString(ticket, ORDER_SYMBOL);
      string orderComment = HistoryOrderGetString(ticket, ORDER_COMMENT);
      
      // ✅ Match by magic OR comment
      bool magicMatch = (orderMagic == setup.magicNumber);
      bool commentMatch = (StringFind(orderComment, setup.setupID) >= 0);
      
      if(orderSymbol != _Symbol) continue;
      if(!magicMatch && !commentMatch) continue;
      
      // Add to orderTickets array
      int idx = ArraySize(setup.orderTickets);
      ArrayResize(setup.orderTickets, idx + 1);
      setup.orderTickets[idx] = ticket;
      
      // Categorize by state
      ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
      
      if(state == ORDER_STATE_FILLED) {
         idx = ArraySize(setup.filledTickets);
         ArrayResize(setup.filledTickets, idx + 1);
         setup.filledTickets[idx] = ticket;
         
      } else if(state == ORDER_STATE_CANCELED) {
         idx = ArraySize(setup.cancelledTickets);
         ArrayResize(setup.cancelledTickets, idx + 1);
         setup.cancelledTickets[idx] = ticket;
      }
   }
   
   // Update counts
   setup.ordersPlaced = ArraySize(setup.orderTickets);
   setup.ordersFilled = ArraySize(setup.filledTickets);
   setup.ordersCancelled = ArraySize(setup.cancelledTickets);
   setup.ordersPlacedFlag = (setup.ordersPlaced > 0);
   
   if(InpDebugMode) {
      Print("      📝 Recovered ", setup.ordersPlaced, " tickets (", 
            setup.ordersFilled, " filled, ", setup.ordersCancelled, " cancelled)");
   }
}

//+------------------------------------------------------------------+
//| Check if Setup Has Trade History                                |
//+------------------------------------------------------------------+
bool CheckSetupTradeHistory(EngulfingSetup &setup) {
   // If no tickets stored, check history directly
   if(ArraySize(setup.orderTickets) == 0) {
      return CheckHistoryForSetup(setup);
   }
   
   // Check if any stored tickets were filled
   for(int i = 0; i < ArraySize(setup.orderTickets); i++) {
      ulong ticket = setup.orderTickets[i];
      
      if(HistoryOrderSelect(ticket)) {
         ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
         if(state == ORDER_STATE_FILLED) {
            return true;  // Found filled order
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check History for Setup (Legacy Method)                         |
//+------------------------------------------------------------------+
bool CheckHistoryForSetup(EngulfingSetup &setup) {
   if(!HistorySelect(setup.createdTime, TimeCurrent())) {
      return false;
   }
   
   // Search for orders with matching magic number
   for(int i = 0; i < HistoryOrdersTotal(); i++) {
      ulong ticket = HistoryOrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(HistoryOrderGetInteger(ticket, ORDER_MAGIC) == setup.magicNumber &&
         HistoryOrderGetString(ticket, ORDER_SYMBOL) == _Symbol) {
         
         ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
         if(state == ORDER_STATE_FILLED) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Update Order Counts from History                                |
//+------------------------------------------------------------------+
void UpdateOrderCountsFromHistory(EngulfingSetup &setup) {
   if(!HistorySelect(setup.createdTime, TimeCurrent())) {
      Print("⚠️ Cannot access history for ", setup.setupID);
      return;
   }
   
   int ordersPlaced = 0;
   int ordersFilled = 0;
   int ordersCancelled = 0;
   
   // If we have stored tickets, use them
   if(ArraySize(setup.orderTickets) > 0) {
      ordersPlaced = ArraySize(setup.orderTickets);
      
      for(int i = 0; i < ArraySize(setup.orderTickets); i++) {
         ulong ticket = setup.orderTickets[i];
         
         if(HistoryOrderSelect(ticket)) {
            ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
            
            if(state == ORDER_STATE_FILLED) {
               ordersFilled++;
            } else if(state == ORDER_STATE_CANCELED) {
               ordersCancelled++;
            }
         }
      }
   } else {
      // Legacy method - scan by magic number
      for(int i = 0; i < HistoryOrdersTotal(); i++) {
         ulong ticket = HistoryOrderGetTicket(i);
         if(ticket <= 0) continue;
         
         if(HistoryOrderGetInteger(ticket, ORDER_MAGIC) != setup.magicNumber) continue;
         if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol) continue;
         
         ordersPlaced++;
         
         ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
         
         if(state == ORDER_STATE_FILLED) {
            ordersFilled++;
         } else if(state == ORDER_STATE_CANCELED) {
            ordersCancelled++;
         }
      }
   }
   
   // Update setup
   setup.ordersPlaced = ordersPlaced;
   setup.ordersFilled = ordersFilled;
   setup.ordersCancelled = ordersCancelled;
   
   if(ordersPlaced > 0) {
      setup.ordersPlacedFlag = true;
   }
   
   DebugPrint(StringFormat("Updated counts for %s: %d placed | %d filled | %d cancelled", 
                          setup.setupID, ordersPlaced, ordersFilled, ordersCancelled));
}

//+------------------------------------------------------------------+
//| Count Total Fills from History                                  |
//+------------------------------------------------------------------+
int CountTotalFills(EngulfingSetup &setup) {
   if(!HistorySelect(setup.createdTime, TimeCurrent())) {
      return 0;
   }
   
   int fillCount = 0;
   
   for(int i = 0; i < HistoryOrdersTotal(); i++) {
      ulong ticket = HistoryOrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(HistoryOrderGetInteger(ticket, ORDER_MAGIC) != setup.magicNumber) continue;
      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol) continue;
      
      ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
      if(state == ORDER_STATE_FILLED) {
         fillCount++;
      }
   }
   
   return fillCount;
}

//+------------------------------------------------------------------+
//| Count Pending Orders for Setup                                  |
//+------------------------------------------------------------------+
int CountPendingOrders(string setupID) {
   int count = 0;
   
   for(int i = 0; i < OrdersTotal(); i++) {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetString(ORDER_COMMENT) != setupID) continue;
      
      count++;
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Count Executed Positions for Setup                              |
//+------------------------------------------------------------------+
int CountExecutedPositions(string setupID, int magicNumber) {
   int count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      
      count++;
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Check if Order Exists at Price                                  |
//+------------------------------------------------------------------+
bool OrderExistsAtPrice(double price, string setupID) {
   for(int i = 0; i < OrdersTotal(); i++) {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetString(ORDER_COMMENT) != setupID) continue;
      
      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      if(MathAbs(orderPrice - price) < 0.001) {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if Setup Has Existing Orders                              |
//+------------------------------------------------------------------+
bool SetupHasExistingOrders(string setupID) {
   // Check pending orders
   for(int i = 0; i < OrdersTotal(); i++) {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      
      string comment = OrderGetString(ORDER_COMMENT);
      if(StringFind(comment, setupID) >= 0) {
         return true;
      }
   }
   
   // Check open positions
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, setupID) >= 0) {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Can Place Orders for Setup? w/ DEBUG + Configurable Age Limit    |
//+------------------------------------------------------------------+
bool CanPlaceOrdersForSetup(EngulfingSetup &setup) {
   // Already placed?
   if(setup.ordersPlacedFlag) {
      DebugPrint("Orders already placed for: " + setup.setupID);
      return false;
   }
   
   // Already tapped?
   if(setup.tapped) {
      DebugPrint("Setup already tapped: " + setup.setupID);
      return false;
   }
   
   // Check if orders already exist
   if(SetupHasExistingOrders(setup.setupID)) {
      DebugPrint("Orders already exist for: " + setup.setupID);
      return false;
   }
   
   // Check if setup is too old
   int ageInDays = (int)((TimeCurrent() - setup.engulfingTime) / 86400);
   if(ageInDays > InpLookbackDays) {
       DebugPrint("Setup too old: " + setup.setupID + " (" + IntegerToString(ageInDays) + " days)");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Find Setup by ID                                                |
//+------------------------------------------------------------------+
int FindSetupByID(string setupID) {
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].setupID == setupID) {
         return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Check if Pattern Already Exists                                 |
//+------------------------------------------------------------------+
bool PatternAlreadyExists(datetime engulfingTime, datetime engulfedTime) {
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].engulfingTime == engulfingTime && 
         g_allSetups[i].engulfedTime == engulfedTime) {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if Range Was Tapped (General)                             |
//+------------------------------------------------------------------+
bool CheckIfRangeTapped(EngulfingSetup &setup, datetime endTime) {
   int startBar = iBarShift(_Symbol, PERIOD_H1, setup.engulfingTime);
   if(startBar == -1) return false;
   
   for(int i = startBar; i >= 0; i--) {
      datetime barTime = iTime(_Symbol, PERIOD_H1, i);
      
      if(barTime > endTime) break;
      if(barTime == setup.engulfingTime) continue;
      
      double high = iHigh(_Symbol, PERIOD_H1, i);
      double low = iLow(_Symbol, PERIOD_H1, i);
      
      if(low <= setup.rangeHigh && high >= setup.rangeLow) {
         setup.tappedTime = barTime;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if Range Was Tapped Since Creation                        |
//+------------------------------------------------------------------+
bool CheckIfRangeTappedSinceCreation(EngulfingSetup &setup) {
   int startBar = iBarShift(_Symbol, PERIOD_H1, setup.engulfingTime);
   if(startBar == -1) {
      DebugPrint("Cannot find bar for setup: " + setup.setupID);
      return false;
   }
   
   for(int i = startBar; i >= 0; i--) {
      datetime barTime = iTime(_Symbol, PERIOD_H1, i);
      
      // Skip the engulfing candle itself
      if(barTime == setup.engulfingTime) continue;
      
      double high = iHigh(_Symbol, PERIOD_H1, i);
      double low = iLow(_Symbol, PERIOD_H1, i);
      
      // Check if this bar touched the range
      if(low <= setup.rangeHigh && high >= setup.rangeLow) {
         setup.tappedTime = barTime;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Is Valid Setup Index?                                           |
//+------------------------------------------------------------------+
bool IsValidSetupIndex(int index) {
   if(index < 0 || index >= ArraySize(g_allSetups)) {
      Print("ERROR: Invalid setup index: ", index);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Setup Statistics                                      |
//+------------------------------------------------------------------+
void CalculateSetupStatistics(EngulfingSetup &setup) {
   int totalTrades = setup.positionsClosed;
   
   if(totalTrades == 0) {
      setup.winRate = 0;
      setup.profitFactor = 0;
      setup.averageWin = 0;
      setup.averageLoss = 0;
      return;
   }
   
   int wins = setup.tpHits;
   int losses = setup.slHits;
   
   // Win Rate
   setup.winRate = (totalTrades > 0) ? (double)wins / totalTrades * 100.0 : 0;
   
   // Profit Factor
   setup.profitFactor = (setup.grossLoss != 0) ? 
                       MathAbs(setup.grossProfit / setup.grossLoss) : 
                       (setup.grossProfit > 0 ? 999.0 : 0);
   
   // Average Win/Loss
   setup.averageWin = (wins > 0) ? setup.grossProfit / wins : 0;
   setup.averageLoss = (losses > 0) ? setup.grossLoss / losses : 0;
}

//+------------------------------------------------------------------+
//| Validate Setup Data                                             |
//+------------------------------------------------------------------+
bool ValidateSetup(EngulfingSetup &setup) {
   if(setup.setupID == "") {
      Print("ERROR: Setup has empty ID");
      return false;
   }
   
   if(setup.rangeHigh <= setup.rangeLow) {
      Print("ERROR: Invalid range for setup: ", setup.setupID);
      return false;
   }
   
   if(setup.magicNumber <= 0) {
      Print("ERROR: Invalid magic number for setup: ", setup.setupID);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Setup Age in Days                                           |
//+------------------------------------------------------------------+
int GetSetupAge(EngulfingSetup &setup) {
   datetime currentTime = TimeCurrent();
   return (int)((currentTime - setup.createdTime) / 86400);
}

//+------------------------------------------------------------------+
//| Get Setup Direction String                                      |
//+------------------------------------------------------------------+
string GetSetupDirection(EngulfingSetup &setup) {
   return setup.isBullish ? "BULLISH" : "BEARISH";
}

//+------------------------------------------------------------------+
//| ✅ NEW: Manual Recovery - Fix ALL Missed Setups from MT5 History |
//+------------------------------------------------------------------+
void ManualRecoveryFromMT5() {
   Print("\n╔════════════════════════════════════════════════════════════════╗");
   Print("║  🔧 MANUAL RECOVERY MODE - Checking MT5 History               ║");
   Print("╚════════════════════════════════════════════════════════════════╝\n");
   
   int recoveredCount = 0;
   int checkedCount = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      // Only check MISSED setups
      if(g_allSetups[i].tradeStatus != TRADE_STATUS_MISSED) continue;
      
      checkedCount++;
      
      // Check if there are actually trades in MT5
      bool hasTradesInMT5 = CheckMT5HistoryForSetup(g_allSetups[i]);
      
      if(hasTradesInMT5) {
         Print("🔧 RECOVERING: ", g_allSetups[i].setupID);
         
         // Recover tickets from MT5
         RecoverTicketsFromMT5History(g_allSetups[i]);
         
         // Update status to TRADED
         g_allSetups[i].tradeStatus = TRADE_STATUS_TRADED;
         g_allSetups[i].wasTraded = true;
         g_allSetups[i].wasMissed = false;
         
         // Recalculate financials
         UpdateOrderStatus(g_allSetups[i]);
         CalculateSetupProfit(g_allSetups[i]);
         
         // Update visual lines
         RedrawTappedLines(g_allSetups[i]);
         
         recoveredCount++;
         
         Print("   ✅ Recovered: ", ArraySize(g_allSetups[i].orderTickets), " tickets");
         Print("   📊 Filled: ", g_allSetups[i].ordersFilled, " | P/L: $", 
               DoubleToString(g_allSetups[i].totalProfit, 2));
      }
   }
   
   Print("\n╔════════════════════════════════════════════════════════════════╗");
   Print("║  🔧 RECOVERY COMPLETE                                         ║");
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print("║  Checked: ", checkedCount, " MISSED setups");
   Print("║  Recovered: ", recoveredCount, " setups from MT5 history");
   Print("╚════════════════════════════════════════════════════════════════╝\n");
   
   if(recoveredCount > 0) {
      // Update global counters
      g_totalSetupsMissed -= recoveredCount;
      g_totalSetupsTraded += recoveredCount;
      
      // Save corrected data
      Print("💾 Saving corrected data to JSON...");
      SaveSetupsToFile();
      Print("✅ JSON file updated!\n");
   }
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if User is Manually Closing All Positions                  |
//+------------------------------------------------------------------+
bool IsUserClosingAllPositions(EngulfingSetup &setup) {
   // If only 1 position remains and it's being closed manually
   return (setup.positionsOpen == 1 && setup.manualCloses > 0);
}

//+-------------------------------------------------------------------+

