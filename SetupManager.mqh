//+------------------------------------------------------------------+
//|                                            SetupManager.mqh       |
//|                    Gold Engulfing EA - Setup State Machine v4.0   |
//|                    ✅ TICKET-BASED VALIDATION SYSTEM              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check All UNTAPPED Setups - Have They Been Tapped?               |
//+------------------------------------------------------------------+
void CheckUntappedSetups() {
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentPrice = (currentBid + currentAsk) / 2.0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         // Check if price has entered the range
         if(IsPriceInRange(currentPrice, g_allSetups[i].rangeHigh, g_allSetups[i].rangeLow)) {
            MarkSetupAsTapped(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Mark Setup as TAPPED (Main State Transition)                     |
//+------------------------------------------------------------------+
void MarkSetupAsTapped(int index) {
   if(!IsValidSetupIndex(index)) return;
   
   // Update state
   g_allSetups[index].state = SETUP_TAPPED;
   g_allSetups[index].tapped = true;
   g_allSetups[index].tappedTime = TimeCurrent();
   g_allSetups[index].lastActivityTime = TimeCurrent();
   
   // Determine MISSED vs TRADED based on ticket storage
   if(ArraySize(g_allSetups[index].orderTickets) > 0) {
      // Tickets were stored → TRADED
      g_allSetups[index].tradeStatus = TRADE_STATUS_TRADED;
      g_allSetups[index].wasTraded = true;
      g_totalSetupsTraded++;
      
      Print("🎯 Setup TAPPED (TRADED): ", g_allSetups[index].setupID, 
            " | Tickets stored: ", ArraySize(g_allSetups[index].orderTickets));
      SendAlert("🎯 TAPPED-TRADED: " + g_allSetups[index].setupID);
      
   } else {
      // No tickets stored → MISSED
      g_allSetups[index].tradeStatus = TRADE_STATUS_MISSED;
      g_allSetups[index].wasMissed = true;
      g_totalSetupsMissed++;
      
      Print("⚠️ Setup TAPPED (MISSED): ", g_allSetups[index].setupID, 
            " | No tickets stored - EA was not running");
      SendAlert("⚠️ TAPPED-MISSED: " + g_allSetups[index].setupID);
   }
   
   // Redraw lines as RED
   RedrawTappedLines(g_allSetups[index]);
   
   // Log to file
   WriteLog(StringFormat("Setup %s TAPPED | Status: %s | Time: %s", 
                        g_allSetups[index].setupID,
                        GetTradeStatusName(g_allSetups[index].tradeStatus),
                        TimeToString(g_allSetups[index].tappedTime, TIME_DATE|TIME_MINUTES)));
}

//+------------------------------------------------------------------+
//| Check TAPPED Setups - Monitor Trade Execution & Completion       |
//+------------------------------------------------------------------+
void CheckTappedSetups() {
   for(int i = ArraySize(g_allSetups) - 1; i >= 0; i--) {
      if(g_allSetups[i].state == SETUP_TAPPED) {
         
         // Skip MISSED setups (no orders to monitor)
         if(g_allSetups[i].tradeStatus == TRADE_STATUS_MISSED) {
            continue;
         }
         
         // For TRADED setups, monitor orders
         if(g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED) {
            
            // Update order tracking using stored tickets
            UpdateOrderStatus(g_allSetups[i]);
            
            // Check if first TP hit
            if(!g_allSetups[i].firstTPHit) {
               if(CheckFirstTPHit(g_allSetups[i])) {
                  g_allSetups[i].firstTPHit = true;
                  g_allSetups[i].hadFirstTP = true;
                  g_allSetups[i].lastActivityTime = TimeCurrent();
                  
                  // Cancel remaining pending orders
                  int cancelled = CancelPendingOrders(g_allSetups[i].setupID);
                  g_allSetups[i].ordersCancelled += cancelled;
                  
                  Print("✅ First TP hit for ", g_allSetups[i].setupID, 
                        " | Cancelled ", cancelled, " pending orders");
                  SendAlert("✅ First TP Hit: " + g_allSetups[i].setupID);
                  
                  WriteLog(StringFormat("First TP hit: %s | Cancelled: %d orders", 
                                       g_allSetups[i].setupID, cancelled));
               }
            }
            
            // Calculate financial metrics
            CalculateSetupProfit(g_allSetups[i]);
            
            // Check if setup is complete
            if(AreAllOrdersHandled(g_allSetups[i])) {
               MarkSetupAsComplete(i);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Mark Setup as Complete (All orders closed/cancelled)             |
//+------------------------------------------------------------------+
void MarkSetupAsComplete(int index) {
   if(!IsValidSetupIndex(index)) return;
   
   // Already complete?
   if(g_allSetups[index].isComplete) return;
   
   // Update completion status
   g_allSetups[index].isComplete = true;
   g_allSetups[index].completedTime = TimeCurrent();
   g_allSetups[index].lastActivityTime = TimeCurrent();
   
   // Final metrics calculation
   CalculateSetupProfit(g_allSetups[index]);
   
   Print("✔ Setup COMPLETE: ", g_allSetups[index].setupID);
   Print(StringFormat("   Status: %s | Orders: %d/%d filled | P/L: $%.2f",
                     GetTradeStatusName(g_allSetups[index].tradeStatus),
                     g_allSetups[index].ordersFilled,
                     g_allSetups[index].ordersPlaced,
                     g_allSetups[index].totalProfit));
   
   SendAlert(StringFormat("✔ Complete: %s | $%.2f", 
                         g_allSetups[index].setupID, 
                         g_allSetups[index].totalProfit));
   
   WriteLog(StringFormat("Setup COMPLETE: %s | Status:%s | Filled:%d/%d | TP:%d SL:%d | P/L:$%.2f",
                        g_allSetups[index].setupID,
                        GetTradeStatusName(g_allSetups[index].tradeStatus),
                        g_allSetups[index].ordersFilled,
                        g_allSetups[index].ordersPlaced,
                        g_allSetups[index].tpHits,
                        g_allSetups[index].slHits,
                        g_allSetups[index].totalProfit));
}

//+------------------------------------------------------------------+
//| Check for Manual Position Close (Cancel Remaining Orders)        |
//+------------------------------------------------------------------+
void CheckManualCloses() {
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_TAPPED && 
         g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED && 
         !g_allSetups[i].firstTPHit) {
         
         int previousOpen = g_allSetups[i].positionsOpen;
         UpdateOrderStatus(g_allSetups[i]);
         int currentOpen = g_allSetups[i].positionsOpen;
         
         // Check if positions decreased (manual close detected)
         if(currentOpen < previousOpen) {
            Print("🔧 Manual close detected for setup: ", g_allSetups[i].setupID);
            
            // Cancel remaining pending orders
            int cancelled = CancelPendingOrders(g_allSetups[i].setupID);
            g_allSetups[i].ordersCancelled += cancelled;
            
            if(cancelled > 0) {
               Print("🚫 Cancelled ", cancelled, " pending orders due to manual close");
               SendAlert("Manual close: Cancelled " + IntegerToString(cancelled) + " orders");
            }
            
            // Mark as complete if no orders remain
            if(AreAllOrdersHandled(g_allSetups[i])) {
               MarkSetupAsComplete(i);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Print Setup Summary                                              |
//+------------------------------------------------------------------+
void PrintSetupSummary() {
   int untappedCount = 0;
   int tappedCount = 0;
   int missedCount = 0;
   int tradedCount = 0;
   int completeCount = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      switch(g_allSetups[i].state) {
         case SETUP_UNTAPPED:  
            untappedCount++; 
            break;
            
         case SETUP_TAPPED:    
            tappedCount++;
            if(g_allSetups[i].tradeStatus == TRADE_STATUS_MISSED) {
               missedCount++;
            } else {
               tradedCount++;
            }
            if(g_allSetups[i].isComplete) {
               completeCount++;
            }
            break;
      }
   }
   
   Print("╔════════════════════════════════════════════════════════════════╗");
   Print("║                     SETUP SUMMARY v3.0                         ║");
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print(StringFormat("║ Total Setups:      %-4d                                     ║", ArraySize(g_allSetups)));
   Print(StringFormat("║ UNTAPPED:          %-4d  (Yellow lines, waiting)            ║", untappedCount));
   Print(StringFormat("║ TAPPED:            %-4d  (Red lines)                        ║", tappedCount));
   Print(StringFormat("║   - Missed:        %-4d  (No tickets stored)                ║", missedCount));
   Print(StringFormat("║   - Traded:        %-4d  (Tickets tracked)                  ║", tradedCount));
   Print(StringFormat("║   - Complete:      %-4d  (All orders done)                  ║", completeCount));
   Print("╚════════════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| Validate Setup Data Integrity                                    |
//+------------------------------------------------------------------+
bool ValidateSetupIntegrity() {
   bool allValid = true;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      // Check for valid setup ID
      if(g_allSetups[i].setupID == "") {
         Print("ERROR: Setup at index ", i, " has empty ID");
         allValid = false;
      }
      
      // Check for valid range
      if(g_allSetups[i].rangeHigh <= g_allSetups[i].rangeLow) {
         Print("ERROR: Setup ", g_allSetups[i].setupID, " has invalid range");
         allValid = false;
      }
      
      // Check for valid magic number
      if(g_allSetups[i].magicNumber <= 0) {
         Print("ERROR: Setup ", g_allSetups[i].setupID, " has invalid magic number");
         allValid = false;
      }
      
      // Check state consistency (2-state system)
      if(g_allSetups[i].state != SETUP_UNTAPPED && g_allSetups[i].state != SETUP_TAPPED) {
         Print("ERROR: Setup ", g_allSetups[i].setupID, " has invalid state: ", g_allSetups[i].state);
         allValid = false;
      }
      
      // Check trade status for tapped setups
      if(g_allSetups[i].state == SETUP_TAPPED) {
         if(g_allSetups[i].tradeStatus != TRADE_STATUS_MISSED && 
            g_allSetups[i].tradeStatus != TRADE_STATUS_TRADED) {
            Print("ERROR: Setup ", g_allSetups[i].setupID, " has invalid trade status");
            allValid = false;
         }
      }
      
      // ✅ NEW: Check ticket array consistency
      if(g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED) {
         if(ArraySize(g_allSetups[i].orderTickets) == 0) {
            Print("WARNING: Setup ", g_allSetups[i].setupID, " marked TRADED but has no tickets");
         }
      }
   }
   
   return allValid;
}

//+------------------------------------------------------------------+
//| ✅ NEW: Validate Active Setups Using Ticket System               |
//+------------------------------------------------------------------+
void ValidateActiveSetups() {
   Print("\n🔍 ===== VALIDATING ACTIVE SETUPS (TICKET-BASED) =====\n");
   
   int validatedCount = 0;
   int updatedCount = 0;
   int ticketCount = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      // Skip completed setups
      if(g_allSetups[i].isComplete) continue;
      
      // Only validate recent setups (last 7 days)
      int ageInDays = (int)((TimeCurrent() - g_allSetups[i].engulfingTime) / 86400);
      if(ageInDays > 7) continue;
      
      validatedCount++;
      
      Print("--- Validating: ", g_allSetups[i].setupID, " ---");
      
      // ✅ Check if we have stored tickets
      int storedTickets = ArraySize(g_allSetups[i].orderTickets);
      
      if(storedTickets == 0) {
         // No tickets stored - check if this is a missed setup
         if(g_allSetups[i].state == SETUP_UNTAPPED) {
            bool wasTapped = CheckIfRangeTappedSinceCreation(g_allSetups[i]);
            
            if(wasTapped) {
               Print("   ⚠️ Range was tapped but no tickets stored → MISSED");
               g_allSetups[i].state = SETUP_TAPPED;
               g_allSetups[i].tapped = true;
               g_allSetups[i].tradeStatus = TRADE_STATUS_MISSED;
               g_allSetups[i].wasMissed = true;
               g_totalSetupsMissed++;
               
               RedrawTappedLines(g_allSetups[i]);
               updatedCount++;
            } else {
               Print("   ✅ Still UNTAPPED (no tickets, not tapped yet)");
            }
         } else {
            Print("   ℹ️ Already marked as ", GetStateName(g_allSetups[i].state), 
                  " / ", GetTradeStatusName(g_allSetups[i].tradeStatus));
         }
         continue;
      }
      
      // ✅ We have tickets - validate their status
      Print("   📝 Found ", storedTickets, " stored tickets");
      ticketCount += storedTickets;
      
      // Update order status using tickets
      UpdateOrderStatus(g_allSetups[i]);
      
      // Check if state needs updating
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         // Has tickets but still marked untapped - check if tapped
         bool wasTapped = CheckIfRangeTappedSinceCreation(g_allSetups[i]);
         
         if(wasTapped || g_allSetups[i].ordersFilled > 0) {
            Print("   🔴 Range was tapped → Updating to TRADED");
            g_allSetups[i].state = SETUP_TAPPED;
            g_allSetups[i].tapped = true;
            g_allSetups[i].tradeStatus = TRADE_STATUS_TRADED;
            g_allSetups[i].wasTraded = true;
            g_totalSetupsTraded++;
            
            CalculateSetupProfit(g_allSetups[i]);
            RedrawTappedLines(g_allSetups[i]);
            updatedCount++;
         }
      }
      
      // Update financials if filled
      if(g_allSetups[i].ordersFilled > 0) {
         CalculateSetupProfit(g_allSetups[i]);
         
         Print("   💰 P/L: $", DoubleToString(g_allSetups[i].totalProfit, 2), 
               " (", g_allSetups[i].ordersFilled, " fills)");
      }
      
      // Check if complete
      if(AreAllOrdersHandled(g_allSetups[i]) && !g_allSetups[i].isComplete) {
         MarkSetupAsComplete(i);
         updatedCount++;
      }
      
      Print("   📊 Status: ", g_allSetups[i].ordersFilled, " filled | ",
            g_allSetups[i].ordersCancelled, " cancelled | ",
            g_allSetups[i].positionsOpen, " open");
   }
   
   Print("\n✅ ===== VALIDATION COMPLETE =====");
   Print("Setups checked: ", validatedCount);
   Print("Tickets validated: ", ticketCount);
   Print("Updates made: ", updatedCount);
   Print("====================================\n");
}
