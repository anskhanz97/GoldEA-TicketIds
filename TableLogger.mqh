//+------------------------------------------------------------------+
//|                                            TableLogger.mqh        |
//|                    Gold Engulfing EA - Simplified Logger v2.1     |
//|                    2-STATE SYSTEM                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Display Compact Summary                                          |
//+------------------------------------------------------------------+
void DisplayCompactSummary() {
   int untappedCount = 0;
   int tappedCount = 0;
   int completeCount = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      switch(g_allSetups[i].state) {
         case SETUP_UNTAPPED:  
            untappedCount++; 
            break;
            
         case SETUP_TAPPED:    
            tappedCount++; 
            if(g_allSetups[i].isComplete) completeCount++;
            break;
      }
   }
   
  // Print("┌────────────────────────────────────────────────────────────────┐");
  // Print("│                    SETUP STATUS SUMMARY                        │");
  // Print("├────────────────────────────────────────────────────────────────┤");
  // Print(StringFormat("│ Total Setups:     %-4d                                     │", ArraySize(g_allSetups)));
  // Print(StringFormat("│ UNTAPPED (🟡):    %-4d  (Waiting for price)              │", untappedCount));
  // Print(StringFormat("│ TAPPED (🔴):      %-4d  (Price entered range)            │", tappedCount));
  // Print(StringFormat("│ COMPLETE (✅):    %-4d  (All orders done)                │", completeCount));
  // Print("└────────────────────────────────────────────────────────────────┘");
}

//+------------------------------------------------------------------+
//| Display Active Setups                                            |
//+------------------------------------------------------------------+
void DisplayActiveSetups() {
   if(ArraySize(g_allSetups) == 0) {
      Print("No setups found");
      return;
   }
   
  // Print("═══════════════════════════════════════════════════════════════════");
   Print("                        ACTIVE SETUPS                              ");
  //  Print("═══════════════════════════════════════════════════════════════════");
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].isComplete) continue;
      
      string state = GetStateName(g_allSetups[i].state);
      string direction = g_allSetups[i].isBullish ? "BULLISH" : "BEARISH";
      
      Print(StringFormat("%s | %s | %s | Orders: %d/%d | P/L: $%.2f",
                        g_allSetups[i].setupID,
                        state,
                        direction,
                        g_allSetups[i].ordersFilled,
                        g_allSetups[i].ordersPlaced,
                        g_allSetups[i].totalProfit));
      
      if(g_allSetups[i].state == SETUP_TAPPED) {
         Print(StringFormat("  └─> Status: %s | TP:%d SL:%d | First TP: %s",
                           GetTradeStatusName(g_allSetups[i].tradeStatus),
                           g_allSetups[i].tpHits,
                           g_allSetups[i].slHits,
                           g_allSetups[i].firstTPHit ? "YES" : "NO"));
      }
   }
   
   //Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Display Trading Statistics                                       |
//+------------------------------------------------------------------+
void DisplayTradingStatistics() {
   double totalProfit = 0;
   int totalPlaced = 0;
   int totalFilled = 0;
   int totalTP = 0;
   int totalSL = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED) {
         totalProfit += g_allSetups[i].totalProfit;
         totalPlaced += g_allSetups[i].ordersPlaced;
         totalFilled += g_allSetups[i].ordersFilled;
         totalTP += g_allSetups[i].tpHits;
         totalSL += g_allSetups[i].slHits;
      }
   }
   
   Print("═══════════════════════════════════════════════════════════════════");
   Print("                    TRADING STATISTICS                             ");
   Print("═══════════════════════════════════════════════════════════════════");
   Print(StringFormat("Total Setups Created:      %d", g_totalSetupsCreated));
   Print(StringFormat("Total Traded:              %d", g_totalSetupsTraded));
   Print(StringFormat("Total Missed:              %d", g_totalSetupsMissed));
   Print("───────────────────────────────────────────────────────────────────");
   Print(StringFormat("Orders Placed:             %d", totalPlaced));
   Print(StringFormat("Orders Filled:             %d (%.1f%%)", 
                     totalFilled, 
                     totalPlaced > 0 ? (double)totalFilled/totalPlaced*100 : 0));
   Print(StringFormat("TP Hits:                   %d", totalTP));
   Print(StringFormat("SL Hits:                   %d", totalSL));
   if(totalTP + totalSL > 0) {
      Print(StringFormat("Win Rate:                  %.1f%%", 
                        (double)totalTP/(totalTP+totalSL)*100));
   }
   Print("───────────────────────────────────────────────────────────────────");
   Print(StringFormat("Total Profit:              $%.2f", totalProfit));
   if(totalFilled > 0) {
      Print(StringFormat("Average per Trade:         $%.2f", totalProfit/totalFilled));
   }
   Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Display Recent Engulfing Patterns (Last 10)                       |
//+------------------------------------------------------------------+
void DisplayRecentEngulfing() {
   int count = MathMin(10, ArraySize(g_allSetups));
   if(count == 0) {
      Print("No engulfing patterns found yet");
      return;
   }
   
  // Print("═══════════════════════════════════════════════════════════════════");
   Print("                    RECENT ENGULFING PATTERNS                      ");
  // Print("═══════════════════════════════════════════════════════════════════");
   
   for(int i = ArraySize(g_allSetups) - 1; i >= ArraySize(g_allSetups) - count && i >= 0; i--) {
      string dir = g_allSetups[i].isBullish ? "🟢 BULLISH" : "🔴 BEARISH";
      string state = GetStateName(g_allSetups[i].state);
      string time = TimeToString(g_allSetups[i].engulfingTime, TIME_DATE|TIME_MINUTES);
      
      Print(StringFormat("%s | %s | %s | Profit: $%.2f",
                        g_allSetups[i].setupID, dir, state, g_allSetups[i].totalProfit));
   }
   
   Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Display Candle Table (Simplified - Only Engulfing Patterns)      |
//+------------------------------------------------------------------+
void DisplayCandleTable() {
   if(!InpEnableTableLogs) return;
   
   Print("═══════════════════════════════════════════════════════════════════");
   Print("              ENGULFING PATTERNS (14 DAYS)                         ");
   Print("═══════════════════════════════════════════════════════════════════");
   Print(StringFormat("%-25s | %-19s | %-8s | %-10s",
                     "Setup ID", "Date/Time", "Direction", "Status"));
   Print("───────────────────────────────────────────────────────────────────");
   
   if(ArraySize(g_allSetups) == 0) {
      Print("No engulfing patterns detected yet");
   } else {
      for(int i = 0; i < ArraySize(g_allSetups); i++) {
         string dateTime = TimeToString(g_allSetups[i].engulfingTime, TIME_DATE|TIME_MINUTES);
         string direction = g_allSetups[i].isBullish ? "BULLISH" : "BEARISH";
         string status = GetStateName(g_allSetups[i].state);
         
         if(g_allSetups[i].state == SETUP_TAPPED) {
            status += " (" + GetTradeStatusName(g_allSetups[i].tradeStatus) + ")";
         }
         
         Print(StringFormat("%-25s | %-19s | %-8s | %-10s",
                           g_allSetups[i].setupID, dateTime, direction, status));
      }
   }
   
   Print("═══════════════════════════════════════════════════════════════════");
   Print(StringFormat("Total Patterns: %d", ArraySize(g_allSetups)));
   Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Log New Bar Alert                                                |
//+------------------------------------------------------------------+
void LogNewBarAlert() {
   if(!InpEnableTableLogs) return;
   datetime barTime = iTime(_Symbol, PERIOD_H1, 0);
   Print("⏰ New H1 Bar: ", TimeToString(barTime, TIME_DATE|TIME_MINUTES));
}

//+------------------------------------------------------------------+
//| Simple Table Print Helper (for compatibility)                    |
//+------------------------------------------------------------------+
void TablePrint(string time, string bar, string datetime_str, string dir, 
                string body, string prices, string status) {
   string line = StringFormat("%-9s| %-4s| %-16s| %-8s| %-7s| %-18s| %s",
                              time, bar, datetime_str, dir, body, prices, status);
   Print(line);
}

//+------------------------------------------------------------------+