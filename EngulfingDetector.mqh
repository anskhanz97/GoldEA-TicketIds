//+------------------------------------------------------------------+
//| EngulfingDetector.mqh -                                         |
//| Fixed for v2.1 - Orders now placed for ALL untapped patterns    |
//+------------------------------------------------------------------+

void ScanHistoricalData() {
    int barsIn14Days = 336; // 14 days * 24 hours
    int totalBars = MathMin(Bars(_Symbol, PERIOD_H1), barsIn14Days);
    
    if(totalBars < 3) {
        Print("⚠️ Not enough bars for historical scan");
        return;
    }
    
    int patternsFound = 0;
    int tappedCount = 0;
    int activeCount = 0;
    
    // Scan from oldest to newest (now includes last 24h)
    for(int i = totalBars - 1; i >= 1; i--) { 
        datetime engulfing_time = iTime(_Symbol, PERIOD_H1, i);
        
        // Check if we have enough bars
        if(i + 1 >= totalBars) continue;
        
        // Get candle data
        double engulfing_open  = iOpen(_Symbol, PERIOD_H1, i);
        double engulfing_close = iClose(_Symbol, PERIOD_H1, i);
        double engulfing_high  = iHigh(_Symbol, PERIOD_H1, i);
        double engulfing_low   = iLow(_Symbol, PERIOD_H1, i);
        
        double engulfed_open  = iOpen(_Symbol, PERIOD_H1, i + 1);
        double engulfed_close = iClose(_Symbol, PERIOD_H1, i + 1);
        double engulfed_high  = iHigh(_Symbol, PERIOD_H1, i + 1);
        double engulfed_low   = iLow(_Symbol, PERIOD_H1, i + 1);
        datetime engulfed_time = iTime(_Symbol, PERIOD_H1, i + 1);
        
        // Calculate body sizes
        double pipValue = GetPipValue();
        double engulfed_body_pips = MathAbs(engulfed_close - engulfed_open) / pipValue;
        
        // Check minimum body size
        if(engulfed_body_pips < InpMinBodyPips) continue;
        
        // Check if candles are opposite colors
        bool engulfed_is_bullish  = (engulfed_close > engulfed_open);
        bool engulfing_is_bullish = (engulfing_close > engulfing_open);
        if(engulfed_is_bullish == engulfing_is_bullish) continue;
        
        // Calculate body boundaries
        double engulfed_body_high  = MathMax(engulfed_open, engulfed_close);
        double engulfed_body_low   = MathMin(engulfed_open, engulfed_close);
        double engulfing_body_high = MathMax(engulfing_open, engulfing_close);
        double engulfing_body_low  = MathMin(engulfing_open, engulfing_close);
        
        // Check if engulfing with tolerance
        bool is_engulfing = IsEngulfingWithTolerance(engulfing_body_high, engulfing_body_low,
                                                      engulfed_body_high, engulfed_body_low);
        
        if(!is_engulfing) continue;
        
        // Check if pattern already exists
        if(PatternAlreadyExists(engulfing_time, engulfed_time)) continue;
        
        // ✅ Valid engulfing pattern found
        patternsFound++;
        g_totalSetupsCreated++;
        
        string setupID = GenerateSetupID(engulfing_time, engulfed_time, engulfing_is_bullish);
        int magicNumber = GenerateMagicNumber(setupID);
        
        EngulfingSetup newSetup;
        newSetup.setupID = setupID;
        newSetup.magicNumber = magicNumber;
        newSetup.engulfedTime = engulfed_time;
        newSetup.engulfingTime = engulfing_time;
        newSetup.createdTime = TimeCurrent();
        newSetup.rangeHigh = engulfed_body_high;
        newSetup.rangeLow = engulfed_body_low;
        newSetup.isBullish = engulfing_is_bullish;
        newSetup.lineHighName = "EngulfHigh_" + setupID;
        newSetup.lineLowName = "EngulfLow_" + setupID;
        newSetup.state = SETUP_UNTAPPED;
        newSetup.tradeStatus = TRADE_STATUS_MISSED;
        newSetup.ordersPlacedFlag = false;
        newSetup.ordersPlaced = 0;
        newSetup.tapped = false;
        newSetup.tappedTime = 0;
        newSetup.ordersCancelled = 0;
        newSetup.isComplete = false;
        newSetup.firstTPHit = false;
        
        // Check if range was tapped after formation
        bool wasTapped = CheckIfRangeTapped(newSetup, TimeCurrent());
        newSetup.tapped = wasTapped;
        
        if(wasTapped) {
            newSetup.state = SETUP_TAPPED;
        }
        
        // Add to global array
        int size = ArraySize(g_allSetups);
        ArrayResize(g_allSetups, size + 1);
        g_allSetups[size] = newSetup;
        
        if(wasTapped) {
            tappedCount++;
            RedrawTappedLines(g_allSetups[size]);
            
            if(!InpEnableTableLogs) {
                Print("📍 ", TimeToString(engulfing_time, TIME_DATE|TIME_MINUTES), 
                      " | ", engulfing_is_bullish ? "BULLISH" : "BEARISH", 
                      " | TAPPED | ID: ", setupID);
            }
        } else {
            // ✅ UNTAPPED - Place orders immediately
            activeCount++;
            DrawRangeLines(g_allSetups[size]);
            
            // ✅ NEW: Place orders for untapped historical patterns
            bool canPlace = CanPlaceOrdersForSetup(g_allSetups[size]);
            if(canPlace) {
          //      Print("✅ Placing orders for untapped historical pattern - Setup ID: ", setupID);
                PlaceOrders(g_allSetups[size]);
                g_allSetups[size].ordersPlacedFlag = true;
            } else {
                Print("⚠️ Cannot place orders for setup: ", setupID);
            }
            
            if(!InpEnableTableLogs) {
                Print("✅ ", TimeToString(engulfing_time, TIME_DATE|TIME_MINUTES), 
                      " | ", engulfing_is_bullish ? "BULLISH" : "BEARISH", 
                      " | ACTIVE | ID: ", setupID);
            }
        }
    }
    
   // Print("\n╔════════════════════════════════════════════════════════════════╗");
  //  Print("║  📊 HISTORICAL SCAN COMPLETE (FULL 14 DAYS)                   ║");
  //  Print("╠════════════════════════════════════════════════════════════════╣");
  //  Print("║  Total Patterns Found: ", patternsFound);
  //  Print("║  Active (Untapped):    ", activeCount, " (Orders placed)");
  //  Print("║  Tapped:               ", tappedCount);
  //  Print("╚════════════════════════════════════════════════════════════════╝\n");
}

//+------------------------------------------------------------------+
//| Process Engulfing Pattern (Real-Time)                           |
//+------------------------------------------------------------------+
void ProcessEngulfingPattern(datetime engulfedTime, datetime engulfingTime,
                            double rangeHigh, double rangeLow, 
                            bool isBullish) {
    
    // Check if pattern already exists
    bool patternExists = false;
    for(int i = 0; i < ArraySize(g_allSetups); i++) {
        if(g_allSetups[i].engulfingTime == engulfingTime && g_allSetups[i].engulfedTime == engulfedTime) {
            patternExists = true;
            break;
        }
    }
    if(patternExists) return;
    
    g_totalSetupsCreated++;
    
    // Generate DETERMINISTIC ID
    string setupID = GenerateSetupID(engulfingTime, engulfedTime, isBullish);
    int magicNumber = GenerateMagicNumber(setupID);
    
    if(SetupHasExistingOrders(setupID)) {
        Print("⚠️ Setup ID ", setupID, " already has orders - SKIPPING duplicate");
        return;
    }
    
    EngulfingSetup newSetup;
    newSetup.setupID = setupID;
    newSetup.magicNumber = magicNumber;
    newSetup.engulfedTime = engulfedTime;
    newSetup.engulfingTime = engulfingTime;
    newSetup.createdTime = TimeCurrent();
    newSetup.rangeHigh = rangeHigh;
    newSetup.rangeLow = rangeLow;
    newSetup.isBullish = isBullish;
    newSetup.state = SETUP_UNTAPPED;
    newSetup.tradeStatus = TRADE_STATUS_MISSED;
    newSetup.ordersPlacedFlag = false;
    newSetup.ordersPlaced = 0;
    newSetup.tapped = false;
    newSetup.tappedTime = 0;
    newSetup.ordersCancelled = 0;
    newSetup.isComplete = false;
    newSetup.firstTPHit = false;
    newSetup.lineHighName = "EngulfHigh_" + setupID;
    newSetup.lineLowName  = "EngulfLow_"  + setupID;
    
    datetime currentTime = iTime(_Symbol, PERIOD_H1, 0);
    datetime currentTimeNow = TimeCurrent();
    bool wasTapped = CheckIfRangeTapped(newSetup, currentTimeNow);
    newSetup.tapped = wasTapped;
    
    if(wasTapped) {
        newSetup.state = SETUP_TAPPED;
    }
    
    int size = ArraySize(g_allSetups);
    ArrayResize(g_allSetups, size + 1);
    g_allSetups[size] = newSetup;
    
    if(!InpEnableTableLogs) {
        Print("=== NEW PATTERN DETECTED ===");
        Print("Setup ID: ", newSetup.setupID, " | Direction: ", newSetup.isBullish ? "BULLISH" : "BEARISH");
        Print("Range: ", newSetup.rangeHigh, " to ", newSetup.rangeLow);
        Print("Already Tapped: ", wasTapped ? "YES ❌" : "NO ✅");
    }
    
    if(wasTapped) {
        RedrawTappedLines(g_allSetups[size]);
    } else {
        DrawRangeLines(g_allSetups[size]);
    }
    
    if(!wasTapped) {
        bool canPlace = CanPlaceOrdersForSetup(g_allSetups[size]);
        if(canPlace) {
            if(!InpEnableTableLogs) {
                Print("✅ Placing orders for untapped pattern - Setup ID: ", newSetup.setupID);
            }
            PlaceOrders(g_allSetups[size]);
            g_allSetups[size].ordersPlacedFlag = true;
            Alert("🔔 ", newSetup.isBullish ? "BULLISH" : "BEARISH", 
                  " ENGULFING PATTERN DETECTED on XAUUSD H1!");
        } else if(!InpEnableTableLogs) {
            Print("⚠️ Skipping order placement - Setup ID: ", newSetup.setupID);
        }
    } else if(!InpEnableTableLogs) {
        Print("🚫 Pattern already tapped - NO orders placed");
    }
}

//+------------------------------------------------------------------+
//| Scan for NEW Engulfing Pattern (Real-Time Only)                  |
//+------------------------------------------------------------------+
void ScanForNewEngulfingPattern() {
    if(Bars(_Symbol, PERIOD_H1) < 3) return;
    
    double engulfed_open  = iOpen(_Symbol, PERIOD_H1, 2);
    double engulfed_close = iClose(_Symbol, PERIOD_H1, 2);
    datetime engulfed_time = iTime(_Symbol, PERIOD_H1, 2);
    
    double engulfing_open  = iOpen(_Symbol, PERIOD_H1, 1);
    double engulfing_close = iClose(_Symbol, PERIOD_H1, 1);
    datetime engulfing_time = iTime(_Symbol, PERIOD_H1, 1);
    
    double pipValue = GetPipValue();
    double engulfed_body_pips = MathAbs(engulfed_close - engulfed_open) / pipValue;
    if(engulfed_body_pips < InpMinBodyPips) return;
    
    bool engulfed_is_bullish  = (engulfed_close > engulfed_open);
    bool engulfing_is_bullish = (engulfing_close > engulfing_open);
    if(engulfed_is_bullish == engulfing_is_bullish) return;
    
    double engulfed_body_high    = MathMax(engulfed_open, engulfed_close);
    double engulfed_body_low     = MathMin(engulfed_open, engulfed_close);
    double engulfing_body_high   = MathMax(engulfing_open, engulfing_close);
    double engulfing_body_low    = MathMin(engulfing_open, engulfing_close);
    
    bool is_engulfing = IsEngulfingWithTolerance(engulfing_body_high, engulfing_body_low,
                                             engulfed_body_high, engulfed_body_low);
    
    if(InpEnableTableLogs && is_engulfing) {
        string currentTimeStr = TimeToString(TimeCurrent(), TIME_SECONDS);
        string barStr = "1";
        string timeStr = TimeToString(engulfing_time, TIME_DATE|TIME_MINUTES);
        string dirStr = engulfing_is_bullish ? "BULLISH" : "BEARISH";
        string bodyStr = DoubleToString(engulfed_body_pips, 1);
        string priceStr = DoubleToString(engulfing_open, 3) + "/" + DoubleToString(engulfing_close, 3);
        string statusReason = is_engulfing ? "REAL-TIME ENGULFING" : "NOT ENGULFING";
        
        Print("\n================================================================================");
        Print("TIME     | BAR | DATE/TIME       | DIR    | BODY(p)| OPEN/CLOSE        | STATUS/REASON");
        Print("================================================================================");
        TablePrint(currentTimeStr, barStr, timeStr, dirStr, bodyStr, priceStr, statusReason);
        Print("================================================================================");
    }
    
    if(!is_engulfing) return;

    // Check if pattern already exists
    bool patternExists = false;
    for(int i = 0; i < ArraySize(g_allSetups); i++) {
        if(g_allSetups[i].engulfingTime == engulfing_time && g_allSetups[i].engulfedTime == engulfed_time) {
            patternExists = true;
            break;
        }
    }
    if(patternExists) return;
    
    ProcessEngulfingPattern(engulfed_time, engulfing_time, engulfed_body_high, engulfed_body_low, engulfing_is_bullish);
}

//+------------------------------------------------------------------+
//| Collect All Candles for Analysis                                 |
//+------------------------------------------------------------------+
void CollectAllCandles(int startBar, int endBar) {
    ArrayResize(g_allCandles, 0);
    
    for(int i = startBar; i <= endBar; i++) {
        PatternData candle;
        candle.barIndex = i;
        candle.candleTime = iTime(_Symbol, PERIOD_H1, i);
        candle.open = iOpen(_Symbol, PERIOD_H1, i);
        candle.high = iHigh(_Symbol, PERIOD_H1, i);
        candle.low = iLow(_Symbol, PERIOD_H1, i);
        candle.close = iClose(_Symbol, PERIOD_H1, i);
        candle.status = "";
        candle.reason = "";
        candle.setupID = "";
        
        int size = ArraySize(g_allCandles);
        ArrayResize(g_allCandles, size + 1);
        g_allCandles[size] = candle;
    }
}

//+------------------------------------------------------------------+
//| Print Complete Candle Table                                      |
//+------------------------------------------------------------------+
void PrintCompleteCandleTable(string scanName) {
    if(!InpEnableTableLogs) return;
    
    Print("\n================================================================================");
    Print(scanName);
    Print("================================================================================");
    Print("TIME     | BAR | DATE/TIME       | DIR    | BODY(p)| OPEN/CLOSE        | STATUS/REASON");
    Print("================================================================================");
    
    for(int i = 0; i < ArraySize(g_allCandles); i++) {
        string currentTimeStr = TimeToString(TimeCurrent(), TIME_SECONDS);
        string barStr = IntegerToString(g_allCandles[i].barIndex);
        string timeStr = TimeToString(g_allCandles[i].candleTime, TIME_DATE|TIME_MINUTES);
        
        bool isBullish = (g_allCandles[i].close > g_allCandles[i].open);
        string dirStr = isBullish ? "BULLISH" : "BEARISH";
        
        double pipValue = GetPipValue();
        double bodyPips = MathAbs(g_allCandles[i].close - g_allCandles[i].open) / pipValue;
        string bodyStr = DoubleToString(bodyPips, 1);
        
        string priceStr = DoubleToString(g_allCandles[i].open, 3) + "/" + DoubleToString(g_allCandles[i].close, 3);
        
        string statusReason = g_allCandles[i].status;
        if(g_allCandles[i].reason != "") {
            if(statusReason != "") statusReason += " - ";
            statusReason += g_allCandles[i].reason;
        }
        if(g_allCandles[i].setupID != "") {
            if(statusReason != "") statusReason += " | ";
            statusReason += "ID:" + g_allCandles[i].setupID;
        }
        
        TablePrint(currentTimeStr, barStr, timeStr, dirStr, bodyStr, priceStr, statusReason);
    }
    
    Print("================================================================================");
}

//+------------------------------------------------------------------+
//| Scan ALL Candles with Complete Logging                           |
//+------------------------------------------------------------------+
void ScanAllCandlesWithLogging(int barsToScan, string scanName) {
    if(!InpEnableTableLogs) {
        Print("🔍 Scanning ", barsToScan, " bars for ", scanName, "...");
    } else {
        Print("\n", scanName);
    }
    
    int totalBars = MathMin(Bars(_Symbol, PERIOD_H1), barsToScan);
    if(totalBars < 3) return;
    
    CollectAllCandles(1, totalBars - 1);
    
    for(int i = 0; i < ArraySize(g_allCandles); i++) {
        int currentBar = g_allCandles[i].barIndex;
        
        if(currentBar >= totalBars - 1) continue;
        
        PatternData currentCandle = g_allCandles[i];
        PatternData previousCandle;
        bool foundPrevious = false;
        
        for(int j = 0; j < ArraySize(g_allCandles); j++) {
            if(g_allCandles[j].barIndex == currentBar + 1) {
                previousCandle = g_allCandles[j];
                foundPrevious = true;
                break;
            }
        }
        if(!foundPrevious) continue;
        
        double pipValue = GetPipValue();
        double engulfed_body_pips = MathAbs(previousCandle.close - previousCandle.open) / pipValue;
        
        if(engulfed_body_pips < InpMinBodyPips) {
            g_allCandles[i].reason = "Body too small: " + DoubleToString(engulfed_body_pips, 1) + " < " + DoubleToString(InpMinBodyPips, 1);
            continue;
        }
        
        bool engulfed_is_bullish  = (previousCandle.close > previousCandle.open);
        bool engulfing_is_bullish = (currentCandle.close > currentCandle.open);
        if(engulfed_is_bullish == engulfing_is_bullish) {
            g_allCandles[i].reason = "Same direction";
            continue;
        }
        
        double engulfed_body_high  = MathMax(previousCandle.open, previousCandle.close);
        double engulfed_body_low   = MathMin(previousCandle.open, previousCandle.close);
        double engulfing_body_high = MathMax(currentCandle.open, currentCandle.close);
        double engulfing_body_low  = MathMin(currentCandle.open, currentCandle.close);
        
        bool is_engulfing = IsEngulfingWithTolerance(engulfing_body_high, engulfing_body_low,
                                             engulfed_body_high, engulfed_body_low);
        
        if(!is_engulfing) {
            g_allCandles[i].reason = "Not engulfing";
            continue;
        }
        
        if(PatternAlreadyExists(currentCandle.candleTime, previousCandle.candleTime)) {
            // Find the setup and show its status
    string setupID = GenerateSetupID(currentCandle.candleTime, previousCandle.candleTime, engulfing_is_bullish);
    int setupIndex = FindSetupByID(setupID);
    
    if(setupIndex >= 0) {
        string status = (g_allSetups[setupIndex].state == SETUP_UNTAPPED) ? "UNTAPPED" : "TAPPED";
        g_allCandles[i].reason = status + " [" + setupID + "]";
    } else {
        g_allCandles[i].reason = "ENGULFING [" + setupID + "]";
    }
    continue;
        }
        
        string setupID = GenerateSetupID(currentCandle.candleTime, previousCandle.candleTime, engulfing_is_bullish);
        int magicNumber = GenerateMagicNumber(setupID);
        
        g_totalSetupsCreated++;
        
        EngulfingSetup newSetup;
        newSetup.setupID = setupID;
        newSetup.magicNumber = magicNumber;
        newSetup.engulfedTime = previousCandle.candleTime;
        newSetup.engulfingTime = currentCandle.candleTime;
        newSetup.createdTime = TimeCurrent();
        newSetup.rangeHigh = engulfed_body_high;
        newSetup.rangeLow = engulfed_body_low;
        newSetup.isBullish = engulfing_is_bullish;
        newSetup.lineHighName = "EngulfHigh_" + setupID;
        newSetup.lineLowName = "EngulfLow_" + setupID;
        newSetup.state = SETUP_UNTAPPED;
        newSetup.tradeStatus = TRADE_STATUS_MISSED;
        newSetup.ordersPlacedFlag = false;
        newSetup.ordersPlaced = 0;
        newSetup.tapped = false;
        newSetup.tappedTime = 0;
        newSetup.ordersCancelled = 0;
        newSetup.isComplete = false;
        newSetup.firstTPHit = false;
        
        bool wasTapped = CheckIfRangeTapped(newSetup, TimeCurrent());
        newSetup.tapped = wasTapped;
        
        if(wasTapped) {
            newSetup.state = SETUP_TAPPED;
        }
        
        int size = ArraySize(g_allSetups);
        ArrayResize(g_allSetups, size + 1);
        g_allSetups[size] = newSetup;
        
        if(wasTapped) {
            g_allCandles[i].status = "TAPPED";
            g_allCandles[i].reason = "Engulfing pattern (tapped)";
            g_allCandles[i].setupID = setupID;
            RedrawTappedLines(g_allSetups[size]);
        } else {
            g_allCandles[i].status = "UNTAPPED";
            g_allCandles[i].reason = "Engulfing pattern";
            g_allCandles[i].setupID = setupID;
            
            DrawRangeLines(g_allSetups[size]);
            
        }
    }
    
    if(InpEnableTableLogs) {
        PrintCompleteCandleTable(scanName);
    }
}

//+------------------------------------------------------------------+