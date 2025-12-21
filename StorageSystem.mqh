//+------------------------------------------------------------------+
//|                                         StorageSystem.mqh         |
//|                 Gold Engulfing EA - File Storage System v3.0      |
//|                 ✅ TICKET-BASED PERSISTENT STORAGE                |
//+------------------------------------------------------------------+

// Global variable to track last saved state (for backup detection)
string g_lastSavedJSON = "";

//+------------------------------------------------------------------+
//| Initialize Storage System                                         |
//+------------------------------------------------------------------+
bool InitializeStorage() {
   // Check if files are accessible
   if(!FileIsExist(FILE_SETUPS)) {
      // Print("📁 Setup file doesn't exist, will be created on first save");
   } else {
      // Print("📁 Setup file found: ", FILE_SETUPS);
   }
   
   //WriteLog("Storage system v3.0 initialized - Ticket tracking enabled");
   return true;
}

//+------------------------------------------------------------------+
//| Save All Setups to JSON File (v3.0 with Tickets)                 |
//+------------------------------------------------------------------+
bool SaveSetupsToFile() {
   int totalSetups = ArraySize(g_allSetups);
   if(totalSetups == 0) {
      // DebugPrint("No setups to save");
      return true;
   }
   
   // Build JSON string from g_allSetups
   string json = BuildAllSetupsJSON();
   if(json == "") {
      Print("ERROR: Failed to build JSON string");
      WriteLog("ERROR: Failed to build JSON for save");
      return false;
   }
   
   // Write to main file
   if(!WriteJSONToFile(FILE_SETUPS, json)) {
      Print("ERROR: Failed to write to ", FILE_SETUPS);
      WriteLog("ERROR: Failed to save setups to file");
      return false;
   }
   
   // Append to backup file ONLY if data changed
   if(json != g_lastSavedJSON) {
      AppendToBackup(json);
      g_lastSavedJSON = json;
      
      // Print("💾 Saved ", totalSetups, " setups to file (backup created)");
      WriteLog(StringFormat("Saved %d setups to file with backup", totalSetups));
   } else {
      // Print("💾 Saved ", totalSetups, " setups to file (no backup - unchanged)");
      // WriteLog(StringFormat("Saved %d setups to file (no backup)", totalSetups));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Load Setups from JSON File                                       |
//+------------------------------------------------------------------+
bool LoadSetupsFromFile() {
   if(!FileIsExist(FILE_SETUPS)) {
      // Print("📂 No existing setup file found - starting fresh");
      WriteLog("No setup file found - fresh start");
      return true;
   }
   
   // Read file
   string json = ReadJSONFromFile(FILE_SETUPS);
   if(json == "") {
      Print("⚠️ Setup file is empty or couldn't be read");
      // WriteLog("WARNING: Setup file empty or unreadable");
      return true;
   }
   
   // Parse JSON and populate g_allSetups array
   if(!ParseAllSetupsJSON(json)) {
      Print("ERROR: Failed to parse setup file");
      WriteLog("ERROR: Failed to parse setup JSON");
      return false;
   }
   
   // Store last saved state
   g_lastSavedJSON = json;
   
   int totalSetups = ArraySize(g_allSetups);
   // Print("📂 Loaded ", totalSetups, " setups from file");
   WriteLog(StringFormat("Loaded %d setups from file", totalSetups));
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ Build JSON String with Ticket Arrays (v3.0)                   |
//+------------------------------------------------------------------+
string BuildAllSetupsJSON() {
   int totalSetups = ArraySize(g_allSetups);
   
   string json = "{\n";
   json += "  \"version\": \"3.0\",\n";
   json += "  \"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\",\n";
   json += "  \"setupCount\": " + IntegerToString(totalSetups) + ",\n";
   json += "  \"systemStats\": {\n";
   json += "    \"totalCreated\": " + IntegerToString(g_totalSetupsCreated) + ",\n";
   json += "    \"totalTraded\": " + IntegerToString(g_totalSetupsTraded) + ",\n";
   json += "    \"totalMissed\": " + IntegerToString(g_totalSetupsMissed) + "\n";
   json += "  },\n";
   json += "  \"setups\": [\n";
   
   for(int i = 0; i < totalSetups; i++) {
      json += "    {\n";
      
      // Identity
      json += "      \"setupID\": \"" + g_allSetups[i].setupID + "\",\n";
      json += "      \"magicNumber\": " + IntegerToString(g_allSetups[i].magicNumber) + ",\n";
      
      // ✅ NEW: Store order ticket arrays
      json += "      \"orderTickets\": [";
      for(int j = 0; j < ArraySize(g_allSetups[i].orderTickets); j++) {
         json += IntegerToString(g_allSetups[i].orderTickets[j]);
         if(j < ArraySize(g_allSetups[i].orderTickets) - 1) json += ",";
      }
      json += "],\n";
      
      json += "      \"filledTickets\": [";
      for(int j = 0; j < ArraySize(g_allSetups[i].filledTickets); j++) {
         json += IntegerToString(g_allSetups[i].filledTickets[j]);
         if(j < ArraySize(g_allSetups[i].filledTickets) - 1) json += ",";
      }
      json += "],\n";
      
      json += "      \"cancelledTickets\": [";
      for(int j = 0; j < ArraySize(g_allSetups[i].cancelledTickets); j++) {
         json += IntegerToString(g_allSetups[i].cancelledTickets[j]);
         if(j < ArraySize(g_allSetups[i].cancelledTickets) - 1) json += ",";
      }
      json += "],\n";
      
      // Time tracking
      json += "      \"engulfingTime\": " + IntegerToString((long)g_allSetups[i].engulfingTime) + ",\n";
      json += "      \"engulfedTime\": " + IntegerToString((long)g_allSetups[i].engulfedTime) + ",\n";
      json += "      \"tappedTime\": " + IntegerToString((long)g_allSetups[i].tappedTime) + ",\n";
      json += "      \"createdTime\": " + IntegerToString((long)g_allSetups[i].createdTime) + ",\n";
      json += "      \"firstOrderTime\": " + IntegerToString((long)g_allSetups[i].firstOrderTime) + ",\n";
      json += "      \"firstFillTime\": " + IntegerToString((long)g_allSetups[i].firstFillTime) + ",\n";
      json += "      \"lastActivityTime\": " + IntegerToString((long)g_allSetups[i].lastActivityTime) + ",\n";
      json += "      \"completedTime\": " + IntegerToString((long)g_allSetups[i].completedTime) + ",\n";
      
      // Price levels
      json += "      \"rangeHigh\": " + DoubleToString(g_allSetups[i].rangeHigh, _Digits) + ",\n";
      json += "      \"rangeLow\": " + DoubleToString(g_allSetups[i].rangeLow, _Digits) + ",\n";
      
      // Direction
      json += "      \"isBullish\": " + (g_allSetups[i].isBullish ? "true" : "false") + ",\n";
      
      // State tracking (2-STATE SYSTEM)
      json += "      \"state\": " + IntegerToString(g_allSetups[i].state) + ",\n";
      json += "      \"tradeStatus\": " + IntegerToString(g_allSetups[i].tradeStatus) + ",\n";
      json += "      \"isComplete\": " + (g_allSetups[i].isComplete ? "true" : "false") + ",\n";
      json += "      \"tapped\": " + (g_allSetups[i].tapped ? "true" : "false") + ",\n";
      json += "      \"firstTPHit\": " + (g_allSetups[i].firstTPHit ? "true" : "false") + ",\n";
      
      // Order placement tracking
      json += "      \"ordersPlacedFlag\": " + (g_allSetups[i].ordersPlacedFlag ? "true" : "false") + ",\n";
      json += "      \"ordersPlaced\": " + IntegerToString(g_allSetups[i].ordersPlaced) + ",\n";
      
      // Order execution tracking
      json += "      \"ordersFilled\": " + IntegerToString(g_allSetups[i].ordersFilled) + ",\n";
      json += "      \"ordersCancelled\": " + IntegerToString(g_allSetups[i].ordersCancelled) + ",\n";
      json += "      \"ordersExpired\": " + IntegerToString(g_allSetups[i].ordersExpired) + ",\n";
      
      // Position tracking
      json += "      \"positionsOpen\": " + IntegerToString(g_allSetups[i].positionsOpen) + ",\n";
      json += "      \"positionsClosed\": " + IntegerToString(g_allSetups[i].positionsClosed) + ",\n";
      
      // Close reason breakdown
      json += "      \"tpHits\": " + IntegerToString(g_allSetups[i].tpHits) + ",\n";
      json += "      \"slHits\": " + IntegerToString(g_allSetups[i].slHits) + ",\n";
      json += "      \"manualCloses\": " + IntegerToString(g_allSetups[i].manualCloses) + ",\n";
      json += "      \"breakEvenCloses\": " + IntegerToString(g_allSetups[i].breakEvenCloses) + ",\n";
      
      // Financial tracking
      json += "      \"totalProfit\": " + DoubleToString(g_allSetups[i].totalProfit, 2) + ",\n";
      json += "      \"grossProfit\": " + DoubleToString(g_allSetups[i].grossProfit, 2) + ",\n";
      json += "      \"grossLoss\": " + DoubleToString(g_allSetups[i].grossLoss, 2) + ",\n";
      json += "      \"largestWin\": " + DoubleToString(g_allSetups[i].largestWin, 2) + ",\n";
      json += "      \"largestLoss\": " + DoubleToString(g_allSetups[i].largestLoss, 2) + ",\n";
      
      // Performance metrics
      json += "      \"winRate\": " + DoubleToString(g_allSetups[i].winRate, 2) + ",\n";
      json += "      \"profitFactor\": " + DoubleToString(g_allSetups[i].profitFactor, 2) + ",\n";
      json += "      \"averageWin\": " + DoubleToString(g_allSetups[i].averageWin, 2) + ",\n";
      json += "      \"averageLoss\": " + DoubleToString(g_allSetups[i].averageLoss, 2) + ",\n";
      
      // Lifecycle flags
      json += "      \"wasTraded\": " + (g_allSetups[i].wasTraded ? "true" : "false") + ",\n";
      json += "      \"wasMissed\": " + (g_allSetups[i].wasMissed ? "true" : "false") + ",\n";
      json += "      \"hadFirstTP\": " + (g_allSetups[i].hadFirstTP ? "true" : "false") + "\n";
      
      json += "    }";
      
      if(i < totalSetups - 1) {
         json += ",";
      }
      json += "\n";
   }
   
   json += "  ]\n";
   json += "}\n";
   
   return json;
}

//+------------------------------------------------------------------+
//| ✅ Parse JSON String with Ticket Arrays (v3.0)                   |
//+------------------------------------------------------------------+
bool ParseAllSetupsJSON(string json) {
   // Clear existing array
   ArrayResize(g_allSetups, 0);
   
   // Extract version
   string version = ExtractStringValue(json, "version");
   // Print("Loading setup file version: ", version);
   
   // Extract system stats
   int systemStatsPos = StringFind(json, "\"systemStats\"");
   if(systemStatsPos >= 0) {
      g_totalSetupsCreated = (int)ExtractIntValue(json, "totalCreated");
      g_totalSetupsTraded = (int)ExtractIntValue(json, "totalTraded");
      g_totalSetupsMissed = (int)ExtractIntValue(json, "totalMissed");
      
      Print("System Stats: Created=", g_totalSetupsCreated, 
            " | Traded=", g_totalSetupsTraded, 
            " | Missed=", g_totalSetupsMissed);
   }
   
   // Extract setupCount
   int setupCountPos = StringFind(json, "\"setupCount\":");
   if(setupCountPos < 0) {
      Print("ERROR: Cannot find setupCount in JSON");
      return false;
   }
   
   int countStart = StringFind(json, ":", setupCountPos) + 1;
   int countEnd = StringFind(json, ",", countStart);
   string countStr = StringSubstr(json, countStart, countEnd - countStart);
   StringTrimLeft(countStr);
   StringTrimRight(countStr);
   
   int savedSetupCount = (int)StringToInteger(countStr);
   
   if(savedSetupCount == 0) {
      Print("No setups in file");
      return true;
   }
   
   // Find setups array start
   int setupsArrayStart = StringFind(json, "\"setups\": [");
   if(setupsArrayStart < 0) {
      Print("ERROR: Cannot find setups array in JSON");
      return false;
   }
   
   // Parse each setup
   int searchPos = setupsArrayStart;
   
   for(int i = 0; i < savedSetupCount; i++) {
      EngulfingSetup setup;
      
      // Find next setup object
      searchPos = StringFind(json, "{", searchPos + 1);
      if(searchPos < 0) break;
      
      int setupEnd = StringFind(json, "}", searchPos);
      if(setupEnd < 0) break;
      
      string setupJSON = StringSubstr(json, searchPos, setupEnd - searchPos + 1);
      
      // Extract ALL fields
      
      // Identity
      setup.setupID = ExtractStringValue(setupJSON, "setupID");
      setup.magicNumber = (int)ExtractIntValue(setupJSON, "magicNumber");
      
      // ✅ NEW: Parse ticket arrays
      string orderTicketsStr = ExtractArrayValue(setupJSON, "orderTickets");
      ParseUlongArray(orderTicketsStr, setup.orderTickets);
      
      string filledTicketsStr = ExtractArrayValue(setupJSON, "filledTickets");
      ParseUlongArray(filledTicketsStr, setup.filledTickets);
      
      string cancelledTicketsStr = ExtractArrayValue(setupJSON, "cancelledTickets");
      ParseUlongArray(cancelledTicketsStr, setup.cancelledTickets);
      
      // Time tracking
      setup.engulfingTime = (datetime)ExtractIntValue(setupJSON, "engulfingTime");
      setup.engulfedTime = (datetime)ExtractIntValue(setupJSON, "engulfedTime");
      setup.tappedTime = (datetime)ExtractIntValue(setupJSON, "tappedTime");
      setup.createdTime = (datetime)ExtractIntValue(setupJSON, "createdTime");
      setup.firstOrderTime = (datetime)ExtractIntValue(setupJSON, "firstOrderTime");
      setup.firstFillTime = (datetime)ExtractIntValue(setupJSON, "firstFillTime");
      setup.lastActivityTime = (datetime)ExtractIntValue(setupJSON, "lastActivityTime");
      setup.completedTime = (datetime)ExtractIntValue(setupJSON, "completedTime");
      
      // Price levels
      setup.rangeHigh = ExtractDoubleValue(setupJSON, "rangeHigh");
      setup.rangeLow = ExtractDoubleValue(setupJSON, "rangeLow");
      
      // Direction
      setup.isBullish = ExtractBoolValue(setupJSON, "isBullish");
      
      // State tracking (2-STATE)
      setup.state = (int)ExtractIntValue(setupJSON, "state");
      setup.tradeStatus = (int)ExtractIntValue(setupJSON, "tradeStatus");
      setup.isComplete = ExtractBoolValue(setupJSON, "isComplete");
      setup.tapped = ExtractBoolValue(setupJSON, "tapped");
      setup.firstTPHit = ExtractBoolValue(setupJSON, "firstTPHit");
      
      // Order placement tracking
      setup.ordersPlacedFlag = ExtractBoolValue(setupJSON, "ordersPlacedFlag");
      setup.ordersPlaced = (int)ExtractIntValue(setupJSON, "ordersPlaced");
      
      // Order execution tracking
      setup.ordersFilled = (int)ExtractIntValue(setupJSON, "ordersFilled");
      setup.ordersCancelled = (int)ExtractIntValue(setupJSON, "ordersCancelled");
      setup.ordersExpired = (int)ExtractIntValue(setupJSON, "ordersExpired");
      
      // Position tracking
      setup.positionsOpen = (int)ExtractIntValue(setupJSON, "positionsOpen");
      setup.positionsClosed = (int)ExtractIntValue(setupJSON, "positionsClosed");
      
      // Close reason breakdown
      setup.tpHits = (int)ExtractIntValue(setupJSON, "tpHits");
      setup.slHits = (int)ExtractIntValue(setupJSON, "slHits");
      setup.manualCloses = (int)ExtractIntValue(setupJSON, "manualCloses");
      setup.breakEvenCloses = (int)ExtractIntValue(setupJSON, "breakEvenCloses");
      
      // Financial tracking
      setup.totalProfit = ExtractDoubleValue(setupJSON, "totalProfit");
      setup.grossProfit = ExtractDoubleValue(setupJSON, "grossProfit");
      setup.grossLoss = ExtractDoubleValue(setupJSON, "grossLoss");
      setup.largestWin = ExtractDoubleValue(setupJSON, "largestWin");
      setup.largestLoss = ExtractDoubleValue(setupJSON, "largestLoss");
      
      // Performance metrics
      setup.winRate = ExtractDoubleValue(setupJSON, "winRate");
      setup.profitFactor = ExtractDoubleValue(setupJSON, "profitFactor");
      setup.averageWin = ExtractDoubleValue(setupJSON, "averageWin");
      setup.averageLoss = ExtractDoubleValue(setupJSON, "averageLoss");
      
      // Lifecycle flags
      setup.wasTraded = ExtractBoolValue(setupJSON, "wasTraded");
      setup.wasMissed = ExtractBoolValue(setupJSON, "wasMissed");
      setup.hadFirstTP = ExtractBoolValue(setupJSON, "hadFirstTP");
      
      // Generate line names
      setup.lineHighName = GenerateLineHighName(setup.setupID);
      setup.lineLowName = GenerateLineLowName(setup.setupID);
      
      // Add to g_allSetups array
      int size = ArraySize(g_allSetups);
      ArrayResize(g_allSetups, size + 1);
      g_allSetups[size] = setup;
      
      searchPos = setupEnd;
   }
   
   //Print("✅ Parsed ", ArraySize(g_allSetups), " setups from JSON (version ", version, ")");
   return true;
}

//+------------------------------------------------------------------+
//| ✅ NEW: Extract Array Value from JSON                            |
//+------------------------------------------------------------------+
string ExtractArrayValue(string json, string key) {
   string searchKey = "\"" + key + "\": [";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return "[]";
   
   int valueStart = keyPos + StringLen(searchKey) - 1;  // Include the '['
   int valueEnd = StringFind(json, "]", valueStart) + 1; // Include the ']'
   
   return StringSubstr(json, valueStart, valueEnd - valueStart);
}

//+------------------------------------------------------------------+
//| ✅ NEW: Parse Ulong Array from JSON String                       |
//+------------------------------------------------------------------+
void ParseUlongArray(string arrayStr, ulong &arr[]) {
   ArrayResize(arr, 0);
   
   // Remove brackets
   StringReplace(arrayStr, "[", "");
   StringReplace(arrayStr, "]", "");
   StringTrimLeft(arrayStr);
   StringTrimRight(arrayStr);
   
   if(arrayStr == "") return;
   
   // Split by comma
   string parts[];
   int count = StringSplit(arrayStr, ',', parts);
   
   if(count <= 0) return;
   
   ArrayResize(arr, count);
   for(int i = 0; i < count; i++) {
      StringTrimLeft(parts[i]);
      StringTrimRight(parts[i]);
      arr[i] = (ulong)StringToInteger(parts[i]);
   }
}

//+------------------------------------------------------------------+
//| Extract String Value from JSON                                    |
//+------------------------------------------------------------------+
string ExtractStringValue(string json, string key) {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return "";
   
   int valueStart = StringFind(json, "\"", keyPos + StringLen(searchKey)) + 1;
   int valueEnd = StringFind(json, "\"", valueStart);
   
   return StringSubstr(json, valueStart, valueEnd - valueStart);
}

//+------------------------------------------------------------------+
//| Extract Integer Value from JSON                                   |
//+------------------------------------------------------------------+
long ExtractIntValue(string json, string key) {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return 0;
   
   int valueStart = keyPos + StringLen(searchKey);
   int valueEnd = StringFind(json, ",", valueStart);
   if(valueEnd < 0) valueEnd = StringFind(json, "\n", valueStart);
   
   string valueStr = StringSubstr(json, valueStart, valueEnd - valueStart);
   StringTrimLeft(valueStr);
   StringTrimRight(valueStr);
   
   return StringToInteger(valueStr);
}

//+------------------------------------------------------------------+
//| Extract Double Value from JSON                                    |
//+------------------------------------------------------------------+
double ExtractDoubleValue(string json, string key) {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return 0;
   
   int valueStart = keyPos + StringLen(searchKey);
   int valueEnd = StringFind(json, ",", valueStart);
   if(valueEnd < 0) valueEnd = StringFind(json, "\n", valueStart);
   
   string valueStr = StringSubstr(json, valueStart, valueEnd - valueStart);
   StringTrimLeft(valueStr);
   StringTrimRight(valueStr);
   
   return StringToDouble(valueStr);
}

//+------------------------------------------------------------------+
//| Extract Boolean Value from JSON                                   |
//+------------------------------------------------------------------+
bool ExtractBoolValue(string json, string key) {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return false;
   
   int valueStart = keyPos + StringLen(searchKey);
   string remainder = StringSubstr(json, valueStart, 10);
   
   return (StringFind(remainder, "true") >= 0);
}

//+------------------------------------------------------------------+
//| Write JSON String to File                                         |
//+------------------------------------------------------------------+
bool WriteJSONToFile(string filename, string json) {
   int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) {
      int error = GetLastError();
      Print("ERROR: Cannot open file for writing: ", filename, " | Error: ", error);
      return false;
   }
   
   uint written = FileWriteString(handle, json);
   FileClose(handle);
   
   if(written == 0) {
      Print("ERROR: Failed to write to file: ", filename);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Read JSON String from File                                        |
//+------------------------------------------------------------------+
string ReadJSONFromFile(string filename) {
   int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) {
      int error = GetLastError();
      Print("ERROR: Cannot open file for reading: ", filename, " | Error: ", error);
      return "";
   }
   
   string json = "";
   while(!FileIsEnding(handle)) {
      json += FileReadString(handle);
   }
   
   FileClose(handle);
   return json;
}

//+------------------------------------------------------------------+
//| Append to Backup File (Only if data changed)                     |
//+------------------------------------------------------------------+
void AppendToBackup(string json) {
   string backupFile = "GoldEngulfing_backups.json";
   
   int handle = FileOpen(backupFile, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) {
      // File doesn't exist, create it
      handle = FileOpen(backupFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE) {
         Print("WARNING: Cannot create backup file");
         return;
      }
   }
   
   // Seek to end
   FileSeek(handle, 0, SEEK_END);
   
   // Write separator and timestamp
   string separator = "\n========================================\n";
   separator += "Backup v3.0: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
   separator += "========================================\n";
   
   FileWriteString(handle, separator);
   FileWriteString(handle, json);
   FileWriteString(handle, "\n");
   
   FileClose(handle);
   
   //DebugPrint("Backup appended successfully");
}

//+------------------------------------------------------------------+
//| Write Log Entry                                                   |
//+------------------------------------------------------------------+
void WriteLog(string message) {
   int handle = FileOpen(FILE_LOGS, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) {
      // Create new log file
      handle = FileOpen(FILE_LOGS, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE) {
         return; // Silently fail - logging is not critical
      }
   }
   
   // Seek to end
   FileSeek(handle, 0, SEEK_END);
   
   // Write log entry
   string logEntry = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " | " + message + "\n";
   FileWriteString(handle, logEntry);
   
   FileClose(handle);
}

//+------------------------------------------------------------------+