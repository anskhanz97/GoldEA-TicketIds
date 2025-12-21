//+------------------------------------------------------------------+
//|                                            VisualManager.mqh      |
//|                    Gold Engulfing EA - Visual Line Management     |
//|                    v2.1 - 2-STATE SYSTEM Compatible               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Range Lines for UNTAPPED Setup (YELLOW dotted lines)        |
//+------------------------------------------------------------------+
void DrawRangeLines(EngulfingSetup &setup) {
   datetime currentTime = iTime(_Symbol, PERIOD_H1, 0);

   // Draw HIGH line
   ObjectCreate(0, setup.lineHighName, OBJ_TREND, 0, 
                setup.engulfedTime, setup.rangeHigh, 
                currentTime, setup.rangeHigh);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_COLOR, InpUntappedLineColor);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_BACK, false);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_SELECTABLE, false);

   // Draw LOW line
   ObjectCreate(0, setup.lineLowName, OBJ_TREND, 0, 
                setup.engulfedTime, setup.rangeLow, 
                currentTime, setup.rangeLow);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_COLOR, InpUntappedLineColor);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_BACK, false);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_SELECTABLE, false);

   DebugPrint("Yellow lines drawn for setup: " + setup.setupID);
}

//+------------------------------------------------------------------+
//| Redraw Lines as TAPPED (RED) - Stop Extending at Tap Time        |
//+------------------------------------------------------------------+
void RedrawTappedLines(EngulfingSetup &setup) {
   // Delete old yellow lines
   ObjectDelete(0, setup.lineHighName);
   ObjectDelete(0, setup.lineLowName);

   // Determine end time for red lines
   datetime endTime = (setup.tappedTime > 0) ? setup.tappedTime : TimeCurrent();

   // Create RED lines that stop at tappedTime
   ObjectCreate(0, setup.lineHighName, OBJ_TREND, 0, 
                setup.engulfedTime, setup.rangeHigh, 
                endTime, setup.rangeHigh);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_COLOR, InpTappedLineColor);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_BACK, false);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_SELECTABLE, false);

   ObjectCreate(0, setup.lineLowName, OBJ_TREND, 0, 
                setup.engulfedTime, setup.rangeLow, 
                endTime, setup.rangeLow);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_COLOR, InpTappedLineColor);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_BACK, false);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_SELECTABLE, false);

   DebugPrint("Lines redrawn as RED (tapped) for setup: " + setup.setupID);
}

//+------------------------------------------------------------------+
//| Update UNTAPPED Lines to Current Time (Extend Yellow Lines)      |
//+------------------------------------------------------------------+
void UpdateUntappedLines(EngulfingSetup &setup, datetime currentTime) {
   // Only update if setup is still UNTAPPED
   if(setup.state != SETUP_UNTAPPED) return;
   
   if(ObjectFind(0, setup.lineHighName) >= 0) {
      ObjectSetInteger(0, setup.lineHighName, OBJPROP_TIME, 1, currentTime);
   }
   
   if(ObjectFind(0, setup.lineLowName) >= 0) {
      ObjectSetInteger(0, setup.lineLowName, OBJPROP_TIME, 1, currentTime);
   }
}

//+------------------------------------------------------------------+
//| Update All Untapped Lines to Current Time                        |
//+------------------------------------------------------------------+
void UpdateAllUntappedLines() {
   datetime currentTime = iTime(_Symbol, PERIOD_H1, 0);
   
   for(int i = 0; i < ArraySize(g_allSetups); i++) {
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         UpdateUntappedLines(g_allSetups[i], currentTime);
      }
   }
}

//+------------------------------------------------------------------+
//| Cleanup Old Lines (older than lookback days)                     |
//+------------------------------------------------------------------+
void CleanupOldLines() {
   datetime cutoffTime = TimeCurrent() - (InpLookbackDays * 86400);
   int deletedCount = 0;
   
   int totalObjects = ObjectsTotal(0);
   
   for(int i = totalObjects - 1; i >= 0; i--) {
      string objName = ObjectName(0, i);
      
      // Check if it's one of our setup lines
      if(StringFind(objName, "EngulfHigh_") == 0 || StringFind(objName, "EngulfLow_") == 0) {
         // Get line's start time
         datetime lineTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
         
         if(lineTime < cutoffTime) {
            ObjectDelete(0, objName);
            deletedCount++;
         }
      }
   }
   
   if(deletedCount > 0) {
      //Print("🧹 Cleaned up ", deletedCount, " old visual lines (older than ", InpLookbackDays, " days)");
   }
}

//+------------------------------------------------------------------+
//| Restore Lines on EA Restart (from g_allSetups array)             |
//+------------------------------------------------------------------+
void RestoreVisualLines() {
   int totalSetups = ArraySize(g_allSetups);
  // Print("🔄 Restoring visual lines for ", totalSetups, " setups...");
   
   int restoredCount = 0;
   
   for(int i = 0; i < totalSetups; i++) {
      // Check if lines already exist
      if(ObjectFind(0, g_allSetups[i].lineHighName) >= 0) {
         DebugPrint("Lines already exist for: " + g_allSetups[i].setupID);
         continue;
      }
      
      // Redraw based on state
      if(g_allSetups[i].state == SETUP_UNTAPPED) {
         // Yellow lines extending to current time
         DrawRangeLines(g_allSetups[i]);
         restoredCount++;
      } else if(g_allSetups[i].state == SETUP_TAPPED) {
         // Red lines stopped at tappedTime
         RedrawTappedLines(g_allSetups[i]);
         restoredCount++;
      }
   }
   
   //Print("✅ Restored ", restoredCount, " visual lines");
}

//+------------------------------------------------------------------+
//| Check if Lines Exist for Setup                                   |
//+------------------------------------------------------------------+
bool LinesExist(string setupID) {
   string lineHighName = GenerateLineHighName(setupID);
   string lineLowName = GenerateLineLowName(setupID);
   
   return (ObjectFind(0, lineHighName) >= 0 && ObjectFind(0, lineLowName) >= 0);
}

//+------------------------------------------------------------------+
//| Delete Lines for Specific Setup                                  |
//+------------------------------------------------------------------+
void DeleteSetupLines(EngulfingSetup &setup) {
   ObjectDelete(0, setup.lineHighName);
   ObjectDelete(0, setup.lineLowName);
   //DebugPrint("Deleted lines for setup: " + setup.setupID);
}

//+------------------------------------------------------------------+
//| Delete All EA Lines from Chart (For OnDeinit Cleanup)            |
//+------------------------------------------------------------------+
void DeleteAllEALines() {
   int totalObjects = ObjectsTotal(0);
   int deletedCount = 0;
   
   for(int i = totalObjects - 1; i >= 0; i--) {
      string objName = ObjectName(0, i);
      
      // Check if it's one of our setup lines
      if(StringFind(objName, "EngulfHigh_") == 0 || StringFind(objName, "EngulfLow_") == 0) {
         ObjectDelete(0, objName);
         deletedCount++;
      }
   }
   
   if(deletedCount > 0) {
      //Print("🧹 Deleted ", deletedCount, " EA lines from chart");
   }
}

//+------------------------------------------------------------------+
//| Count Visual Lines on Chart                                      |
//+------------------------------------------------------------------+
int CountEALines() {
   int count = 0;
   int totalObjects = ObjectsTotal(0);
   
   for(int i = 0; i < totalObjects; i++) {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "EngulfHigh_") == 0 || StringFind(objName, "EngulfLow_") == 0) {
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Update Line Color (for manual color changes if needed)           |
//+------------------------------------------------------------------+
void UpdateLineColor(EngulfingSetup &setup, color newColor) {
   if(ObjectFind(0, setup.lineHighName) >= 0) {
      ObjectSetInteger(0, setup.lineHighName, OBJPROP_COLOR, newColor);
   }
   
   if(ObjectFind(0, setup.lineLowName) >= 0) {
      ObjectSetInteger(0, setup.lineLowName, OBJPROP_COLOR, newColor);
   }
}

//+------------------------------------------------------------------+