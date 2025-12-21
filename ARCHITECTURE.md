**`ARCHITECTURE.md`** (File structure, data flow)


MQL5/
├── Experts/
│   └── GoldEngulfing_Main.mq5          ← Main EA file
│
└── Include/
    ├── Config.mqh                       ← Settings & structures
    ├── Utils.mqh                        ← Helper functions
    ├── EngulfingDetector.mqh           ← Pattern detection
    ├── VisualManager.mqh               ← Yellow/Red lines
    ├── OrderManager.mqh                ← 10-order placement
    ├── SetupManager.mqh                ← State machine
    ├── StorageSystem.mqh               ← JSON persistence
    └── TableLogger.mqh                 ← Professional logging
    |__ SetupHelper.mqh                 <- Helper Functions

Files/ (auto-created)
├── GoldEngulfing_setups.json           ← Current state
├── GoldEngulfing_backups.json          ← Backup history
└── GoldEngulfing_logs.json             ← Event log
