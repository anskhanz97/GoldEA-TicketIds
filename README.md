My Strategy is works only on H1 Timeframe works only on Gold/XAUUSD and is completely based on Engulfing Candles (two candles opposite in color), when Next Candles BODY/New Candles BODY / Fresh Candles BODY (Candle 1) totally engulfs the Body of Previous Candle (Candle 2) is creates an Engulfing Setup to trade.  Keeping the Opening and Closing in mind i also added a Gap Tolerance of 0.20 Points. And decided to set the Minimum Body size of Engulfed Candle to be 2 Pips. 
i use the SL of 4$ and TP of 8$. However, Once the Engulfing is Complete/ Setup is Created. 
We call it the UnTapped Setup as it was just completed/formed. And script automatically draws Yellow Dotted lines on top and bottom of Range of Engulfed Candles Body that extends with time towards right side only unless until price taps into this range. 
We place 10 limit orders of 0.01 lots throughout the Range/Body of the Engulfed Candle. Placing 3 on Range high, 3 on Midrange Range and 4 trades on Range Low in case of Bullish Engulfing. And opposite for Shorts in case of Bearish Engulfing.  
Once price taps into the yellow lines (the range/ the body of the engulfed candle), the yellow lines stop right there. And Limit Orders are Executed when price visits them accordingly in the range.. and the color of dotted lines is changed to red at bar close. now it is officially a TAPPED Setup which is of no use to us anymore. the limit orders executed will close at either TP or SL automatically or i will manually close them if i feel like it... and this setup will never be used again... no more limit orders will be applied for it again. now we wait for the next setup. 

 
my idea of the EA is not a simple one it has many features like Narrative Logging, 
Best Professional Grade Table Logging for ALL Candles (that scans and tells details about every last one of 336 Candles (= 14 days) :
with current time, Bar number, date+time of bar, direction, candle body size, open/close and 
Status as well:
Not Engulfing / Same Direction /Engulfing [Engulf_13122025-1000-B]  / TAPPED [Engulf_12122025-1000-S] 
 
and a one liner  summary at the end as well),
 Time-Based Deterministic IDs to keep all track and avoid duplication and better control, 
Detects both bullish and bearish engulfing patterns Perfectly = Yellow + Red Lines, 
Visual lines for untapped (yellow) and tapped (red) ranges,
 14-day cleanup of visual lines AND pending/limit orders,
Places 10 limit orders across the range (Engulfed Candles Body) for untapped/yellow setups,
High Speed 1:2 RR Unified TP/Dynamic SL Scalping Machine, 
Alerts when an Engulfing Candle is Found, when an H1 bar completes, Alerts for Trade Execution and Completion.

I used the open and close of candles to detect engulfing candles but i further more used the time of candle to avoid duplication for each setup to be unique... because price only tells if a candle is engulfing the previous or not , also many candles can appear at the same price range but only 1 candle appears at one time, hence the logic. 

I plan for my future script to have a Comprehensive File-Based Persistent Storage System with Complete Trade History Tracking, good debugging as well for which it creates files (not Directories) in the Folder/Path:  \MQL5\Files

Files to be Created for Proper Functioning of Storage System: 
1. `GoldEngulfing_setups.json` - Main setups file
2. `GoldEngulfing_backups.json` - Backup file (appends each save)
3. `GoldEngulfing_logs.json` - Log file

So the paths would be/must be: 
C:\Users\Dell\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files\GoldEngulfing_setups.json C:\Users\Dell\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files\GoldEngulfing_backups.json C:\Users\Dell\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files\GoldEngulfing_logs.json


The purpose of the File Storage System is to keep track of the states of trade setups:
Time-Based Deterministic IDs to provide Bulletproof Duplicate Prevention need this solid trade state tracking as well.
For example, once a trade setup is created. it goes through many stages. -
> first it is fresh/unexecuted/ untapped (Limit orders placed)
-> Tapped/ Limit orders executed (afew out 10 or all of them)
 -> now multiple scenarios arise:
- Either price taps into some of them and they get filled and other remain unfilled,  in such cases further scernarios appear:
 for example one situation can be the Script automatically Cancels all remaining pending orders from the same setup when first TP is hit, 
- or I manually close the running positions and it should still delete the remaining pending orders from that setup....  etc.
 Only then it is possible to see our progress and calculate.... if 100 setups appeared this week how many of them did we trade ? how many were already expired (we could not trade them) when we were busy/out. how many of them hit all TPS or how many of them hit all SLs or how many setups got completely filled (10 /10)or partially filled (5/10) if the executed setups were closed manually by me aur automatically by Script using TP or Trailing SL....

Moreover, some actions are to be perform after every bar close  (after every hour) while some features require immediate/quicker response for that too we need to use timer of specific functions to be called every few seconds, for example if our trades are running and few hit tp and the rest should be immediately cancelled for that we need quick tracking, tracking after h1 bar close would not do us any benefit right ?

The Persistent Memory will also help duplication as it would now that orders for that specific Setup lke : "Engulf_13122025-1000-B" have already been placed hours ago so it doesnot need to do anything. Orders are already placed so relax and wait for price to tap and execute them....

or in another scernario it know that Afew orders from "Engulf_13122025-1000-B" have already hit TP so it needs to cancel the remainging ones and relax. task completed on to the next one.

or in another scernario it know that some  orders from "Engulf_13122025-1000-B" have already hit TP amd the rest were Cancelled on Purpose to it has been Marked "COMPLETE" so it doesnot need to look into it anymore....

or in another scernario it know that some orders from "Engulf_12122025-1000-S" have already passed as i was not infront of my PC or was busy outside so, no limit orders was ever placed for it, none executed no TP no SL so it will mark that setup that was totally Missed as "Expired" Logically,  it doesnot need to look into it anymore aswell....


And that is why i chose the Modular Approach because all this cannot be done possibly/cleanly in a single file.....

that is all, i think you have all you need to know. i shared every little detail with you... hope you know what to make of it and how would you use it in a modular way.
