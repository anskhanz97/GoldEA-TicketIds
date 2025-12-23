//+------------------------------------------------------------------+
//|                                            OrderManager.mqh       |
//|                    Gold Engulfing EA - Order Management v4.0      |
//|                    ✅ DIAGNOSTIC VERSION - TRACKS TICKET FLOW     |
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
   Print("╠════════════════════════════════════════════════════════════════╣");
   
   // Divide range into 3 zones
   double zoneSize = rangeSize / 3.0;
   double topZoneStart = setup.rangeHigh;
   double topZoneEnd = setup.rangeHigh - zoneSize;
   double midZoneStart = topZoneEnd;
   double midZoneEnd = topZoneEnd - zoneSize;
   double bottomZoneStart = midZoneEnd;
   double bottomZoneEnd = setup.rangeLow;
   
   int totalOrders = 0;
   int successCount = 0;
   
   // ✅ DIAGNOSTIC: Show ticket array state BEFORE placing orders
   Print("║  🔍 DIAGNOSTIC: Tickets BEFORE placing orders: ", ArraySize(setup.orderTickets));
   
   // ✅ Clear ticket arrays before placing new orders
   ArrayResize(setup.orderTickets, 0);
   ArrayResize(setup.filledTickets, 0);
   ArrayResize(setup.cancelledTickets, 0);
   
   Print("║  🔍 DIAGNOSTIC: Tickets after clearing: ", ArraySize(setup.orderTickets));
   
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
   
   // ✅ DIAGNOSTIC: Show ticket array state AFTER placing orders
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print("║  🔍 DIAGNOSTIC: Tickets AFTER placing orders: ", ArraySize(setup.orderTickets));
   Print("║  ✅ Orders Placed: ", successCount, "/", totalOrders);
   
   // ✅ DIAGNOSTIC: Print each stored ticket
   if(ArraySize(setup.orderTickets) > 0) {
      Print("║  📝 Stored Tickets:");
      for(int i = 0; i < ArraySize(setup.orderTickets); i++) {
         Print("║     #", setup.orderTickets[i]);
      }
   } else {
      Print("║  ⚠️ WARNING: NO TICKETS STORED!");
   }
   
   Print("╚════════════════════════════════════════════════════════════════╝\n");
   
   // Update setup tracking
   setup.ordersPlaced = successCount;
   setup.ordersPlacedFlag = true;
   setup.firstOrderTime = TimeCurrent();
   setup.lastActivityTime = TimeCurrent();
   
   // ✅ DIAGNOSTIC: Check ticket array RIGHT BEFORE saving
   Print("🔍 DIAGNOSTIC: Tickets in setup RIGHT BEFORE SaveSetupsToFile(): ", 
         ArraySize(setup.orderTickets));
   
   // Save to file immediately (persistent storage)
   Print("💾 Calling SaveSetupsToFile()...");
   bool saveResult = SaveSetupsToFile();
   
   if(saveResult) {
      Print("✅ SaveSetupsToFile() returned TRUE");
   } else {
      Print("❌ SaveSetupsToFile() returned FALSE - FILE WRITE FAILED!");
   }
   
   // ✅ DIAGNOSTIC: Verify tickets are still there after save
   Print("🔍 DIAGNOSTIC: Tickets in setup AFTER SaveSetupsToFile(): ", 
         ArraySize(setup.orderTickets));
   
   return (successCount > 0);
}

//+------------------------------------------------------------------+
//| ✅ Place Single Order with Ticket Storage                        |
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
      // ✅ CRITICAL: Store the ticket immediately
      int beforeSize = ArraySize(setup.orderTickets);
      int idx = ArraySize(setup.orderTickets);
      ArrayResize(setup.orderTickets, idx + 1);
      setup.orderTickets[idx] = result.order;
      int afterSize = ArraySize(setup.orderTickets);
      
      // ✅ DIAGNOSTIC: Verify ticket was stored
      Print("   ✅ Order #", result.order, " placed @ ", DoubleToString(entryPrice, 3));
      Print("      🔍 Ticket array: ", beforeSize, " → ", afterSize, 
            " (stored in index ", idx, ")");
      
      // ✅ VERIFY: Can we read it back?
      if(afterSize > 0 && setup.orderTickets[idx] == result.order) {
         Print("      ✅ VERIFIED: Ticket successfully stored and readable");
      } else {
         Print("      ❌ ERROR: Ticket storage verification FAILED!");
         Print("         Expected: ", result.order);
         Print("         Got: ", afterSize > 0 ? IntegerToString(setup.orderTickets[idx]) : "Array empty!");
      }
      
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
//| ✅ Update Order Status Using Stored Tickets                      |
//+------------------------------------------------------------------+
void UpdateOrderStatus(EngulfingSetup &setup) {
   // ✅ DIAGNOSTIC: Show what we're working with
   if(InpDebugMode) {
      Print("🔍 UpdateOrderStatus for ", setup.setupID, 
            " | Stored tickets: ", ArraySize(setup.orderTickets));
   }
   
   // If no tickets stored, fall back to old method
   if(ArraySize(setup.orderTickets) == 0) {
      UpdateOrderStatusLegacy(setup);
      return;
   }
   
   // Reset counters
   int pendingCount = 0;
   int filledCount = 0;
   int cancelledCount = 0;
   
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
   setup.positionsOpen = pendingCount;
   
   if(InpDebugMode) {
      Print("📊 ", setup.setupID, ": ", pendingCount, " pending | ", 
            filledCount, " filled | ", cancelledCount, " cancelled");
   }
}

//+------------------------------------------------------------------+
//| ✅ Legacy: Old method for backwards compatibility                |
//+------------------------------------------------------------------+
void UpdateOrderStatusLegacy(EngulfingSetup &setup) {
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
//| ✅ Calculate Profit Using Stored Tickets                         |
//+------------------------------------------------------------------+
void CalculateSetupProfit(EngulfingSetup &setup) {
   // If no filled tickets, fall back to old method
   if(ArraySize(setup.filledTickets) == 0) {
      CalculateSetupProfitLegacy(setup);
      return;
   }
   
   double totalProfit = 0;
   double grossProfit = 0;
   double grossLoss = 0;
   double largestWin = 0;
   double largestLoss = 0;
   int tpCount = 0;
   int slCount = 0;
   int manualCount = 0;
   
   if(!HistorySelect(setup.createdTime, TimeCurrent())) return;
   
   // Only check OUR stored filled tickets
   for(int i = 0; i < ArraySize(setup.filledTickets); i++) {
      ulong orderTicket = setup.filledTickets[i];
      
      if(!HistoryOrderSelect(orderTicket)) continue;
      
      // Find the position that this order created
      for(int j = 0; j < HistoryDealsTotal(); j++) {
         ulong dealTicket = HistoryDealGetTicket(j);
         
         if(HistoryDealGetInteger(dealTicket, DEAL_ORDER) == orderTicket &&
            HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
            
            // Found entry deal - now find exit
            ulong positionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            
            for(int k = 0; k < HistoryDealsTotal(); k++) {
               ulong exitDeal = HistoryDealGetTicket(k);
               
               if(HistoryDealGetInteger(exitDeal, DEAL_POSITION_ID) == positionID &&
                  HistoryDealGetInteger(exitDeal, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                  
                  double profit = HistoryDealGetDouble(exitDeal, DEAL_PROFIT);
                  double commission = HistoryDealGetDouble(exitDeal, DEAL_COMMISSION);
                  double swap = HistoryDealGetDouble(exitDeal, DEAL_SWAP);
                  
                  double netProfit = profit + commission + swap;
                  totalProfit += netProfit;
                  
                  if(netProfit > 0) {
                     grossProfit += netProfit;
                     if(netProfit > largestWin) largestWin = netProfit;
                  } else {
                     grossLoss += netProfit;
                     if(netProfit < largestLoss) largestLoss = netProfit;
                  }
                  
                  // Detect TP/SL by profit amount
                  if(netProfit > 6.0) {
                     tpCount++;
                  } else if(netProfit < -2.0) {
                     slCount++;
                  } else {
                     manualCount++;
                  }
                  
                  break;
               }
            }
            break;
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
//| ✅ Legacy: Old profit calculation                                |
//+------------------------------------------------------------------+
void CalculateSetupProfitLegacy(EngulfingSetup &setup) {
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
   Print("║  Tickets Stored:    ", ArraySize(setup.orderTickets));
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
