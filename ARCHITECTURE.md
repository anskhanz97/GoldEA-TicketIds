**`ARCHITECTURE.md`** (File structure, data flow)


MQL5/
├── Experts/
│   └── GoldEngulfing_Main.mq5          # Main orchestrator (NEW NAME)
│
└── Include/
    ├── Config.mqh                        # Inputs, constants, EngulfingSetup struct
    ├── Utils.mqh                         # ID generation, pip value, price checks
    ├── EngulfingDetector.mqh             # Pattern detection & historical scanning
    ├── VisualManager.mqh                 # Line drawing, updating, cleanup
    ├── OrderManager.mqh                  # ✅ DIAGNOSTIC VERSION - Tracks ticket flow
    ├── SetupManager.mqh                  # ✅ TICKET-BASED VALIDATION SYSTEM
    ├── SetupHelpers.mqh                  # ✅ COMPLETE IMPLEMENTATION with MT5 recovery
    ├── StorageSystem.mqh                 # ✅ TICKET-BASED PERSISTENT STORAGE
    └── TableLogger.mqh                   # Simplified logger for 2-STATE system

Files/ (auto-created by EA)
├── GoldEngulfing_setups.json            # ✅ Stores ACTUAL TICKETS (ulong arrays)
├── GoldEngulfing_backups.json           # Append-only backup history
└── GoldEngulfing_logs.json              # Event log