//+------------------------------------------------------------------+
//|                                               SetupHelpers.mqh    |
//|                    Gold Engulfing EA - Setup Helper Functions     |
//|                    v2.1 - 2-State System Compatible               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Count Total Fills (from history + current positions)             |
//+------------------------------------------------------------------+
int CountTotalFills(EngulfingSetup &setup) {
   int fillCount = 0;
   
   // Count from history (closed positions)
   if(HistorySelect(setup.createdTime, TimeCurrent())) {
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket <= 0) continue;
         
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != setup.magicNumber) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         
         // Count entry deals (BUY or SELL)
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
            fillCount++;
         }
      }
   }
   
   // Add current open positions
   fillCount += CountExecutedPositions(setup.setupID, setup.magicNumber);
   
   return fillCount;
}

//+------------------------------------------------------------------+
//| Validate Setup Before Processing                                 |
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
//| Get Setup Age in Days                                            |
//+------------------------------------------------------------------+
int GetSetupAge(EngulfingSetup &setup) {
   datetime currentTime = TimeCurrent();
   return (int)((currentTime - setup.createdTime) / 86400);
}

//+------------------------------------------------------------------+
//| Get Setup Direction String                                       |
//+------------------------------------------------------------------+
string GetSetupDirection(EngulfingSetup &setup) {
   return setup.isBullish ? "BULLISH" : "BEARISH";
}

//+------------------------------------------------------------------+
//| Get Setup Range Size in Pips                                     |
//+------------------------------------------------------------------+
double GetSetupRangePips(EngulfingSetup &setup) {
   return PointsToPips(setup.rangeHigh - setup.rangeLow);
}

//+------------------------------------------------------------------+
//| Check if Setup Has Any Active Trades                             |
//+------------------------------------------------------------------+
bool SetupHasActiveTrades(EngulfingSetup &setup) {
   int pendingCount = CountPendingOrders(setup.setupID);
   int positionCount = CountExecutedPositions(setup.setupID, setup.magicNumber);
   
   return (pendingCount > 0 || positionCount > 0);
}

//+------------------------------------------------------------------+
//| Get Setup Summary String (one-liner)                             |
//+------------------------------------------------------------------+
string GetSetupSummary(EngulfingSetup &setup) {
   return StringFormat("%s | %s | %s | Age:%dd | Orders:%d/%d | P/L:$%.2f",
                      setup.setupID,
                      GetSetupDirection(setup),
                      GetStateName(setup.state),
                      GetSetupAge(setup),
                      setup.ordersFilled,
                      setup.ordersPlaced,
                      setup.totalProfit);
}

//+------------------------------------------------------------------+
//| Check if Setup is Profitable                                     |
//+------------------------------------------------------------------+
bool IsSetupProfitable(EngulfingSetup &setup) {
   return setup.totalProfit > 0;
}

//+------------------------------------------------------------------+
//| Get Setup Win Rate (TP vs SL)                                    |
//+------------------------------------------------------------------+
double GetSetupWinRate(EngulfingSetup &setup) {
   int totalClosed = setup.tpHits + setup.slHits;
   if(totalClosed == 0) return 0;
   
   return ((double)setup.tpHits / totalClosed) * 100.0;
}

//+------------------------------------------------------------------+
//| Check if Setup is Complete (no pending/open trades)              |
//+------------------------------------------------------------------+
bool IsSetupComplete(EngulfingSetup &setup) {
   int pendingCount = CountPendingOrders(setup.setupID);
   int executedCount = CountExecutedPositions(setup.setupID, setup.magicNumber);
   
   return (pendingCount == 0 && executedCount == 0);
}

//+------------------------------------------------------------------+
//| Get Setup State Description                                      |
//+------------------------------------------------------------------+
string GetSetupStateDescription(EngulfingSetup &setup) {
   string desc = GetStateName(setup.state);
   
   if(setup.state == SETUP_TAPPED) {
      desc += " (" + GetTradeStatusName(setup.tradeStatus) + ")";
      if(setup.isComplete) {
         desc += " [COMPLETE]";
      }
   }
   
   return desc;
}

//+------------------------------------------------------------------+
//| Calculate Setup Statistics                                       |
//+------------------------------------------------------------------+
void CalculateSetupStatistics(EngulfingSetup &setup) {
   // Win rate
   if(setup.tpHits + setup.slHits > 0) {
      setup.winRate = ((double)setup.tpHits / (setup.tpHits + setup.slHits)) * 100.0;
   }
   
   // Profit factor
   if(setup.grossLoss != 0) {
      setup.profitFactor = MathAbs(setup.grossProfit / setup.grossLoss);
   }
   
   // Average win
   if(setup.tpHits > 0) {
      setup.averageWin = setup.grossProfit / setup.tpHits;
   }
   
   // Average loss
   if(setup.slHits > 0) {
      setup.averageLoss = setup.grossLoss / setup.slHits;
   }
}

//+------------------------------------------------------------------+
//| Count Setups by State                                            |
//+------------------------------------------------------------------+
void CountSetupsByState(int &untappedCount, int &tappedCount, int &completeCount) {
   untappedCount = 0;
   tappedCount = 0;
   completeCount = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      switch(g_allSetups[i].state) {
         case SETUP_UNTAPPED:
            untappedCount++;
            break;
            
         case SETUP_TAPPED:
            tappedCount++;
            if(g_allSetups[i].isComplete) {
               completeCount++;
            }
            break;
      }
   }
}

//+------------------------------------------------------------------+
//| Count Setups by Trade Status                                     |
//+------------------------------------------------------------------+
void CountSetupsByTradeStatus(int &missedCount, int &tradedCount) {
   missedCount = 0;
   tradedCount = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_TAPPED) {
         if(g_allSetups[i].tradeStatus == TRADE_STATUS_MISSED) {
            missedCount++;
         } else if(g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED) {
            tradedCount++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Total Profit from All Setups                                 |
//+------------------------------------------------------------------+
double GetTotalProfit() {
   double totalProfit = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      totalProfit += g_allSetups[i].totalProfit;
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Get Total Orders Statistics                                      |
//+------------------------------------------------------------------+
void GetTotalOrderStats(int &totalPlaced, int &totalFilled, int &totalTP, int &totalSL) {
   totalPlaced = 0;
   totalFilled = 0;
   totalTP = 0;
   totalSL = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED) {
         totalPlaced += g_allSetups[i].ordersPlaced;
         totalFilled += g_allSetups[i].ordersFilled;
         totalTP += g_allSetups[i].tpHits;
         totalSL += g_allSetups[i].slHits;
      }
   }
}

//+------------------------------------------------------------------+
//| Find Setup by ID                                                 |
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
//| Check if Setup Index is Valid                                    |
//+------------------------------------------------------------------+
bool IsValidSetupIndex(int index) {
   return (index >= 0 && index < ArraySize(g_allSetups));
}

//+------------------------------------------------------------------+
//| Get Most Recent Setup                                            |
//+------------------------------------------------------------------+
int GetMostRecentSetupIndex() {
   int count = ArraySize(g_allSetups);
   if(count == 0) return -1;
   
   datetime latestTime = 0;
   int latestIndex = -1;
   
   for(int i = 0; i < count; i++) {
      if(g_allSetups[i].createdTime > latestTime) {
         latestTime = g_allSetups[i].createdTime;
         latestIndex = i;
      }
   }
   
   return latestIndex;
}

//+------------------------------------------------------------------+
//| Get Active Untapped Setups Count                                 |
//+------------------------------------------------------------------+
int GetActiveUntappedCount() {
   int count = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get Active Traded Setups Count (tapped but not complete)         |
//+------------------------------------------------------------------+
int GetActiveTradedCount() {
   int count = 0;
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_TAPPED && 
         g_allSetups[i].tradeStatus == TRADE_STATUS_TRADED &&
         !g_allSetups[i].isComplete) {
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+