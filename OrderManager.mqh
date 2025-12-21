//+------------------------------------------------------------------+
//|                                            OrderManager.mqh       |
//|                    Gold Engulfing EA - Order Management v2.1      |
//|                    Complete order placement and monitoring        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Place All Orders for Setup (10 orders distributed)               |
//+------------------------------------------------------------------+
bool PlaceOrders(EngulfingSetup &setup) {
   if(setup.ordersPlacedFlag) {
      Print("⚠️ Orders already placed for setup: ", setup.setupID);
      return false;
   }
   
   if(setup.tapped) {
      Print("⚠️ Setup already tapped - cannot place orders: ", setup.setupID);
      return false;
   }
   
   Print("\n╔════════════════════════════════════════════════════════════════╗");
   Print("║  📋 PLACING ORDERS FOR SETUP: ", setup.setupID);
   Print("╠════════════════════════════════════════════════════════════════╣");
   
   // Calculate range size
   double rangeSize = setup.rangeHigh - setup.rangeLow;
   double pipValue = GetPipValue();
   
   Print("║  Direction: ", setup.isBullish ? "BULLISH 📈" : "BEARISH 📉");
   Print("║  Range High: ", DoubleToString(setup.rangeHigh, _Digits));
   Print("║  Range Low:  ", DoubleToString(setup.rangeLow, _Digits));
   //Print("║  Range Size: ", DoubleToString(PointsToPips(rangeSize), 1), " pips");
   Print("╠════════════════════════════════════════════════════════════════╣");
   
   // Divide range into 3 zones
   double zoneSize = rangeSize / 3.0;
   double topZoneStart = setup.rangeHigh;
   double topZoneEnd = setup.rangeHigh - zoneSize;
   double midZoneStart = topZoneEnd;
   double midZoneEnd = topZoneEnd - zoneSize;
   double bottomZoneStart = midZoneEnd;
   double bottomZoneEnd = setup.rangeLow;
   
  // Print("║  📍 TOP Zone:    ", DoubleToString(topZoneEnd, _Digits), " to ", DoubleToString(topZoneStart, _Digits));
  // Print("║  📍 MID Zone:    ", DoubleToString(midZoneEnd, _Digits), " to ", DoubleToString(midZoneStart, _Digits));
  // Print("║  📍 BOTTOM Zone: ", DoubleToString(bottomZoneEnd, _Digits), " to ", DoubleToString(bottomZoneStart, _Digits));
  // Print("╠════════════════════════════════════════════════════════════════╣");
   
   int totalOrders = 0;
   int successCount = 0;
   
   // Place TOP zone orders
   Print("║  Placing TOP zone orders (", InpTopZoneOrders, ")...");
   for(int i = 0; i < InpTopZoneOrders; i++) {
      double price = topZoneStart - (zoneSize / (InpTopZoneOrders + 1)) * (i + 1);
      if(PlaceSingleOrder(setup, price, setup.isBullish)) {
         successCount++;
      }
      totalOrders++;
   }
   
   // Place MID zone orders
   Print("║  Placing MID zone orders (", InpMidZoneOrders, ")...");
   for(int i = 0; i < InpMidZoneOrders; i++) {
      double price = midZoneStart - (zoneSize / (InpMidZoneOrders + 1)) * (i + 1);
      if(PlaceSingleOrder(setup, price, setup.isBullish)) {
         successCount++;
      }
      totalOrders++;
   }
   
   // Place BOTTOM zone orders
   Print("║  Placing BOTTOM zone orders (", InpBottomZoneOrders, ")...");
   for(int i = 0; i < InpBottomZoneOrders; i++) {
      double price = bottomZoneStart - (zoneSize / (InpBottomZoneOrders + 1)) * (i + 1);
      if(PlaceSingleOrder(setup, price, setup.isBullish)) {
         successCount++;
      }
      totalOrders++;
   }
   
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print("║  ✅ Orders Placed: ", successCount, "/", totalOrders);
   Print("╚════════════════════════════════════════════════════════════════╝\n");
   
   // Update setup tracking
   setup.ordersPlaced = successCount;
   setup.ordersPlacedFlag = true;
   setup.firstOrderTime = TimeCurrent();
   setup.lastActivityTime = TimeCurrent();
   
   // Save to file
   SaveSetupsToFile();
   
   return (successCount > 0);
}

//+------------------------------------------------------------------+
//| Place Single Order at Specific Price                             |
//+------------------------------------------------------------------+
bool PlaceSingleOrder(EngulfingSetup &setup, double entryPrice, bool isBullish) {
   // Normalize price
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   
   // Check if order already exists at this price
   if(OrderExistsAtPrice(entryPrice, setup.setupID)) {
      DebugPrint("Order already exists at price: " + DoubleToString(entryPrice, _Digits));
      return false;
   }
   
   // Determine order type
   ENUM_ORDER_TYPE orderType;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(isBullish) {
      orderType = (entryPrice < currentPrice) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;
   } else {
      orderType = (entryPrice > currentPrice) ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP;
   }
   
   // Calculate SL and TP
   double pipValue = GetPipValue();
   double slDistance = InpSLPips * pipValue;
   double tpDistance = InpTPPips * pipValue;
   
   double sl, tp;
   if(isBullish) {
      sl = entryPrice - slDistance;
      tp = entryPrice + tpDistance;
   } else {
      sl = entryPrice + slDistance;
      tp = entryPrice - tpDistance;
   }
   
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = InpLotSize;
   request.type = orderType;
   request.price = entryPrice;
   request.sl = sl;
   request.tp = tp;
   request.magic = setup.magicNumber;
   request.comment = setup.setupID;
   request.type_filling = ORDER_FILLING_IOC;
   
   // Send order
   if(!OrderSend(request, result)) {
      Print("❌ Order failed: ", result.retcode, " - ", ErrorDescription(result.retcode));
      Print("   Price: ", entryPrice, " | Type: ", EnumToString(orderType));
      return false;
   }
   
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
      DebugPrint(StringFormat("✅ Order placed: %s @ %.3f | SL:%.3f TP:%.3f | Ticket:%d", 
                             EnumToString(orderType), entryPrice, sl, tp, result.order));
      return true;
   }
   
   Print("⚠️ Order placement uncertain: ", result.retcode);
   return false;
}

//+------------------------------------------------------------------+
//| Cancel All Pending Orders for Setup                              |
//+------------------------------------------------------------------+
int CancelPendingOrders(string setupID) {
   int cancelledCount = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetString(ORDER_COMMENT) != setupID) continue;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_REMOVE;
      request.order = ticket;
      
      if(OrderSend(request, result)) {
         if(result.retcode == TRADE_RETCODE_DONE) {
            cancelledCount++;
            DebugPrint("Cancelled order: " + IntegerToString(ticket));
         }
      } else {
         Print("Failed to cancel order: ", ticket, " - Error: ", GetLastError());
      }
   }
   
   return cancelledCount;
}

//+------------------------------------------------------------------+
//| Update Order Status for Setup                                    |
//+------------------------------------------------------------------+
void UpdateOrderStatus(EngulfingSetup &setup) {
   // Count current pending orders
   int pendingCount = CountPendingOrders(setup.setupID);
   
   // Count current open positions
   int positionCount = CountExecutedPositions(setup.setupID, setup.magicNumber);
   setup.positionsOpen = positionCount;
   
   // Count total fills from history
   int totalFills = CountTotalFills(setup);
   setup.ordersFilled = totalFills;
   
   // Update activity time if positions changed
   if(positionCount != setup.positionsOpen) {
      setup.lastActivityTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Check if First TP Was Hit                                        |
//+------------------------------------------------------------------+
bool CheckFirstTPHit(EngulfingSetup &setup) {
   if(setup.firstTPHit) return true;
   
   // Check history for TP hits
   if(HistorySelect(setup.createdTime, TimeCurrent())) {
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket <= 0) continue;
         
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != setup.magicNumber) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         
         // Check if it's an exit deal
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            // Check if closed at TP
            string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
            if(StringFind(comment, "tp") >= 0 || StringFind(comment, "TP") >= 0) {
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if All Orders Are Handled (Complete)                       |
//+------------------------------------------------------------------+
bool AreAllOrdersHandled(EngulfingSetup &setup) {
   // Count remaining pending orders
   int pendingCount = CountPendingOrders(setup.setupID);
   
   // Count open positions
   int positionCount = CountExecutedPositions(setup.setupID, setup.magicNumber);
   
   // If no pending and no positions, setup is complete
   return (pendingCount == 0 && positionCount == 0);
}

//+------------------------------------------------------------------+
//| Calculate Setup Profit from History                              |
//+------------------------------------------------------------------+
void CalculateSetupProfit(EngulfingSetup &setup) {
   double totalProfit = 0;
   double grossProfit = 0;
   double grossLoss = 0;
   double largestWin = 0;
   double largestLoss = 0;
   int tpCount = 0;
   int slCount = 0;
   int manualCount = 0;
   
   if(HistorySelect(setup.createdTime, TimeCurrent())) {
      for(int i = 0; i < HistoryDealsTotal(); i++) {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket <= 0) continue;
         
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != setup.magicNumber) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         
         // Only count exit deals
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            
            double netProfit = profit + swap + commission;
            totalProfit += netProfit;
            
            if(netProfit > 0) {
               grossProfit += netProfit;
               if(netProfit > largestWin) largestWin = netProfit;
            } else {
               grossLoss += netProfit;
               if(netProfit < largestLoss) largestLoss = netProfit;
            }
            
            // Categorize close reason
            string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
            if(StringFind(comment, "tp") >= 0 || StringFind(comment, "TP") >= 0) {
               tpCount++;
            } else if(StringFind(comment, "sl") >= 0 || StringFind(comment, "SL") >= 0) {
               slCount++;
            } else {
               manualCount++;
            }
         }
      }
   }
   
   // Update setup financials
   setup.totalProfit = totalProfit;
   setup.grossProfit = grossProfit;
   setup.grossLoss = grossLoss;
   setup.largestWin = largestWin;
   setup.largestLoss = largestLoss;
   setup.tpHits = tpCount;
   setup.slHits = slCount;
   setup.manualCloses = manualCount;
   setup.positionsClosed = tpCount + slCount + manualCount;
   
   // Calculate metrics
   CalculateSetupStatistics(setup);
}

//+------------------------------------------------------------------+
//| Close All Positions for Setup                                    |
//+------------------------------------------------------------------+
int CloseAllPositions(string setupID, int magicNumber) {
   int closedCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.position = ticket;
      request.symbol = _Symbol;
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      request.magic = magicNumber;
      request.comment = setupID + "_manual_close";
      request.type_filling = ORDER_FILLING_IOC;
      
      if(OrderSend(request, result)) {
         if(result.retcode == TRADE_RETCODE_DONE) {
            closedCount++;
            DebugPrint("Closed position: " + IntegerToString(ticket));
         }
      } else {
         Print("Failed to close position: ", ticket, " - Error: ", GetLastError());
      }
   }
   
   return closedCount;
}

//+------------------------------------------------------------------+
//| Print Order Summary for Setup                                    |
//+------------------------------------------------------------------+
void PrintOrderSummary(EngulfingSetup &setup) {
   Print("\n╔════════════════════════════════════════════════════════════════╗");
   Print("║  ORDER SUMMARY: ", setup.setupID);
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print("║  Orders Placed:     ", setup.ordersPlaced);
   Print("║  Orders Filled:     ", setup.ordersFilled);
   Print("║  Orders Cancelled:  ", setup.ordersCancelled);
   Print("║  Positions Open:    ", setup.positionsOpen);
   Print("║  Positions Closed:  ", setup.positionsClosed);
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print("║  TP Hits:           ", setup.tpHits);
   Print("║  SL Hits:           ", setup.slHits);
   Print("║  Manual Closes:     ", setup.manualCloses);
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print("║  Total Profit:      $", DoubleToString(setup.totalProfit, 2));
   Print("║  Gross Profit:      $", DoubleToString(setup.grossProfit, 2));
   Print("║  Gross Loss:        $", DoubleToString(setup.grossLoss, 2));
   Print("╚════════════════════════════════════════════════════════════════╝\n");
}

//+------------------------------------------------------------------+