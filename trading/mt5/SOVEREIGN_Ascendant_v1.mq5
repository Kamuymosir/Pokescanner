#property strict
#property version   "3.00"
#property description "SOVEREIGN Ascendant v1: integrated successor of OMEGA / PHOENIX with safe legacy salvage."

#include <Trade/Trade.mqh>

enum TrendState
  {
   TREND_FLAT = 0,
   TREND_BULL = 1,
   TREND_BEAR = -1
  };

enum SignalMode
  {
   MODE_NONE      = 0,
   MODE_BANDWAGON = 1,
   MODE_STEALTH   = 2
  };

struct SignalInfo
  {
   bool       valid;
   SignalMode mode;
   string     submode;
   int        direction;
   double     fixed_lots;
   double     sl_atr;
   double     rr;
   double     trail_atr;
   double     be_atr;
   double     partial_rr;
   double     partial_close_pct;
   int        max_hold_bars;
   int        htf_score;
   int        htf_score_margin;
   int        htf_direction;
   string     entry_reason_code;
   string     entry_reason_text;
   double     breakout_distance_atr;
   double     body_ratio_entry;
   double     compression_score;
   double     release_strength_score;
  };

struct PositionState
  {
   ulong      position_id;
   string     symbol;
   SignalMode mode;
   string     submode;
   int        direction;
   datetime   entry_time;
   datetime   entry_bar_time;
   double     entry_price;
   double     spread_points_entry;
   double     atr_points_entry;
   string     session_bucket;
   string     volatility_bucket;
   int        htf_direction;
   int        htf_score;
   int        htf_score_margin;
   double     stop_loss_points;
   double     take_profit_points;
   double     risk_percent;
   double     size_lots;
   string     entry_reason_code;
   string     pending_exit_reason;
   double     breakout_distance_atr;
   double     body_ratio_entry;
   double     compression_score;
   double     release_strength_score;
   double     mae_points;
   double     mfe_points;
   int        consecutive_losses_before_entry;
   double     daily_dd_pct_before_entry;
   int        partial_close_count;
   double     first_partial_r;
   bool       trail_activated;
   bool       be_activated;
   double     realized_profit;
   double     realized_commission;
   double     realized_swap;
  };

input group "[Core]"
input long   InpMagicNumber               = 42033001;
input bool   InpAllowLong                 = true;
input bool   InpAllowShort                = true;
input int    InpTickIntervalMS            = 250;
input int    InpCooldownSec               = 60;
input bool   InpOnePositionPerSymbol      = true;

input group "[HTF Regime Engine]"
input bool   InpAutoHTF                   = true;
input ENUM_TIMEFRAMES InpManualHTF        = PERIOD_H1;
input int    InpHTFConfirmBars            = 3;
input int    InpEMAFast                   = 20;
input int    InpEMASlow                   = 50;
input int    InpADXPeriod                 = 14;
input double InpADXThreshold              = 18.0;
input int    InpMinTrendScore             = 4;
input int    InpMinScoreMargin            = 1;

input group "[Execution Filters]"
input int    InpSpreadMaxPoints           = 60;
input bool   InpSessionGuard              = false;
input int    InpSessionStartHour          = 7;
input int    InpSessionEndHour            = 22;
input int    InpATRPeriod                 = 14;

input group "[Price Action / Market Environment]"
input bool   InpEnablePriceActionContext  = true;
input double InpGlobalMinBodyRatio        = 0.20;
input int    InpEnvironmentLookbackBars   = 12;
input int    InpATRRegimeLookback         = 24;
input double InpBandwagonMinCloseLocation = 0.70;
input double InpBandwagonMaxExhaustionWickRatio = 0.18;
input double InpBandwagonMinEfficiencyRatio = 0.28;
input double InpBandwagonMinAtrRegimeRatio = 0.90;
input double InpBandwagonMaxAtrRegimeRatio = 1.80;
input double InpStealthMinCloseLocation   = 0.68;
input double InpStealthMaxExhaustionWickRatio = 0.22;
input double InpStealthMaxPreBreakEfficiencyRatio = 0.55;
input double InpStealthMinAtrRegimeRatio  = 0.80;
input double InpStealthMaxAtrRegimeRatio  = 1.60;

input group "[Bandwagon Alpha]"
input bool   InpEnableBandwagon           = true;
input double InpBandwagonFixedLots        = 0.05;
input int    InpSwingLookback             = 12;
input double InpBandwagonVolFactor        = 1.15;
input double InpBandwagonMinBodyRatio     = 0.55;
input double InpBandwagonMinBreakATR      = 0.15;
input double InpBandwagonMaxChaseATR      = 1.20;
input double InpBandwagonSL_ATR           = 1.30;
input double InpBandwagonTP_RR            = 1.40;
input double InpBandwagonTrailATR         = 1.60;
input double InpBandwagonBE_ATR           = 1.00;
input double InpBandwagonPartialRR        = 1.00;
input double InpBandwagonPartialClosePct  = 0.50;
input int    InpBandwagonMaxHoldBars      = 8;

input group "[Stealth Alpha]"
input bool   InpEnableStealth             = true;
input double InpStealthFixedLots          = 0.03;
input int    InpBBPeriod                  = 20;
input double InpBBDev                     = 2.0;
input int    InpSqueezeLookback           = 12;
input int    InpMinCompressedBars         = 6;
input double InpSqueezeWidthFactor        = 0.82;
input double InpStealthVolFloor           = 0.90;
input double InpStealthReleaseFactor      = 1.20;
input double InpStealthSL_ATR             = 1.60;
input double InpStealthTP_RR              = 2.20;
input double InpStealthTrailATR           = 2.40;
input double InpStealthBE_ATR             = 1.30;
input double InpStealthPartialRR          = 1.20;
input double InpStealthPartialClosePct    = 0.40;
input int    InpStealthMaxHoldBars        = 16;

input group "[Sizing Engine]"
input bool   InpUseRiskPercent            = true;
input double InpBaseRiskPercent           = 0.35;
input double InpRiskMultWeak              = 0.50;
input double InpRiskMultMedium            = 0.75;
input double InpRiskMultStrong            = 1.00;
input double InpRiskMultVeryStrong        = 1.20;
input double InpLossClusterRiskScale1     = 0.75;
input double InpLossClusterRiskScale2     = 0.50;
input double InpMaxLotsPerTrade           = 1.00;

input group "[Hard Risk Governance]"
input bool   InpEnableDailyDDGuard        = true;
input double InpDailyDDLimitPct           = 3.0;
input bool   InpEnableConsecLossGuard     = true;
input int    InpMaxConsecutiveLosses      = 3;
input bool   InpManualKillSwitch          = false;
input bool   InpCloseOpenOnRiskGuard      = false;
input bool   InpEnableDailySoftThrottle   = true;
input double InpDailySoftTargetPct        = 2.0;
input double InpDailySoftRiskScale        = 0.40;

input group "[Legacy Salvage Hooks]"
input bool   InpEnableNewsEventFilter     = false;
input string InpNewsEventFile             = "TE_Event.csv";
input int    InpNewsLookaheadMinutes      = 60;
input int    InpNewsMinImpact             = 2;

input group "[Audit]"
input bool   InpEnableAuditCSV            = true;
input string InpAuditFileName             = "SOVEREIGN_Ascendant_Audit.csv";

CTrade trade;
PositionState g_states[];

ENUM_TIMEFRAMES g_ltf = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_htf = PERIOD_H1;

datetime g_last_bar_time   = 0;
datetime g_last_trade_time = 0;
ulong    g_last_tick_ms    = 0;

int h_atr_ltf      = INVALID_HANDLE;
int h_ema_fast_ltf = INVALID_HANDLE;
int h_ema_fast_htf = INVALID_HANDLE;
int h_ema_slow_htf = INVALID_HANDLE;
int h_adx_htf      = INVALID_HANDLE;
int h_bands_ltf    = INVALID_HANDLE;

string g_last_panel          = "";
int    g_last_trend_score    = 0;
int    g_last_trend_dir      = 0;
int    g_last_trend_margin   = 0;
int    g_consecutive_losses  = 0;
int    g_day_key             = 0;
double g_day_start_equity    = 0.0;
bool   g_daily_guard_tripped = false;

string TFToString(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      default:         return "TF?";
     }
  }

ENUM_TIMEFRAMES AutoHigherTF(const ENUM_TIMEFRAMES ltf)
  {
   switch(ltf)
     {
      case PERIOD_M1:  return PERIOD_M3;
      case PERIOD_M2:  return PERIOD_M6;
      case PERIOD_M3:  return PERIOD_M10;
      case PERIOD_M4:  return PERIOD_M12;
      case PERIOD_M5:  return PERIOD_M15;
      case PERIOD_M6:  return PERIOD_M20;
      case PERIOD_M10: return PERIOD_M30;
      case PERIOD_M12: return PERIOD_M30;
      case PERIOD_M15: return PERIOD_H1;
      case PERIOD_M20: return PERIOD_H1;
      case PERIOD_M30: return PERIOD_H2;
      case PERIOD_H1:  return PERIOD_H3;
      case PERIOD_H2:  return PERIOD_H6;
      case PERIOD_H3:  return PERIOD_H8;
      case PERIOD_H4:  return PERIOD_H12;
      case PERIOD_H6:  return PERIOD_D1;
      case PERIOD_H8:  return PERIOD_D1;
      case PERIOD_H12: return PERIOD_D1;
      default:         return PERIOD_H1;
     }
  }

string TrendToText(const int trend)
  {
   if(trend > 0)
      return "BULL";
   if(trend < 0)
      return "BEAR";
   return "FLAT";
  }

string ModeToText(const SignalMode mode)
  {
   if(mode == MODE_BANDWAGON)
      return "Bandwagon";
   if(mode == MODE_STEALTH)
      return "Stealth";
   return "None";
  }

int CurrentDayKey()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return tm.year * 10000 + tm.mon * 100 + tm.day;
  }

bool ReadBufferValue(const int handle, const int buffer_index, const int shift, double &value)
  {
   if(handle == INVALID_HANDLE)
      return false;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, buffer_index, shift, 1, buf) != 1)
      return false;

   value = buf[0];
   return true;
  }

bool ReadRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, count, rates);
   return copied >= count;
  }

bool IsNewBar()
  {
   datetime current_bar = iTime(_Symbol, _Period, 0);
   if(current_bar == 0)
      return false;

   if(current_bar != g_last_bar_time)
     {
      g_last_bar_time = current_bar;
      return true;
     }
   return false;
  }

bool SessionOK()
  {
   if(!InpSessionGuard)
      return true;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   if(InpSessionStartHour <= InpSessionEndHour)
      return tm.hour >= InpSessionStartHour && tm.hour < InpSessionEndHour;

   return tm.hour >= InpSessionStartHour || tm.hour < InpSessionEndHour;
  }

string CurrentSessionBucket()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int hour = tm.hour;

   if(hour >= 0 && hour < 7)
      return "Asia";
   if(hour >= 7 && hour < 13)
      return "London";
   if(hour >= 13 && hour < 17)
      return "Overlap";
   if(hour >= 17 && hour < 22)
      return "NewYork";
   return "OffHours";
  }

bool HasOpenPosition()
  {
   if(!PositionSelect(_Symbol))
      return false;

   long magic = (long)PositionGetInteger(POSITION_MAGIC);
   return magic == InpMagicNumber;
  }

int VolumeDigits(const double step)
  {
   if(step <= 0.0)
      return 2;

   double probe = step;
   int digits = 0;
   while(digits < 8 && MathAbs(probe - MathRound(probe)) > 1e-8)
     {
      probe *= 10.0;
      digits++;
     }
   return digits;
  }

double NormalizeVolume(const double volume)
  {
   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step_lot <= 0.0)
      step_lot = min_lot;

   double value = MathMax(min_lot, MathMin(max_lot, volume));
   value = min_lot + MathFloor((value - min_lot) / step_lot + 1e-8) * step_lot;
   value = MathMax(min_lot, MathMin(max_lot, value));
   return NormalizeDouble(value, VolumeDigits(step_lot));
  }

double PointValuePerLot()
  {
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tick_value <= 0.0 || tick_size <= 0.0 || point <= 0.0)
      return 0.0;
   return tick_value * point / tick_size;
  }

double CurrentSpreadPoints()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return DBL_MAX;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return DBL_MAX;

   return (tick.ask - tick.bid) / point;
  }

bool SpreadOK()
  {
   return CurrentSpreadPoints() <= InpSpreadMaxPoints;
  }

double CurrentATR(const int shift=1)
  {
   double atr = 0.0;
   if(!ReadBufferValue(h_atr_ltf, 0, shift, atr))
      return 0.0;
   return atr;
  }

double CandleRange(const MqlRates &rate)
  {
   return rate.high - rate.low;
  }

double CandleBodyRatio(const MqlRates &rate)
  {
   double range = CandleRange(rate);
   if(range <= 0.0)
      return 0.0;
   return MathAbs(rate.close - rate.open) / range;
  }

double CandleCloseLocation(const MqlRates &rate, const int direction)
  {
   double range = CandleRange(rate);
   if(range <= 0.0)
      return 0.0;

   if(direction > 0)
      return (rate.close - rate.low) / range;

   if(direction < 0)
      return (rate.high - rate.close) / range;

   return 0.0;
  }

double DirectionalExhaustionWickRatio(const MqlRates &rate, const int direction)
  {
   double range = CandleRange(rate);
   if(range <= 0.0)
      return 0.0;

   if(direction > 0)
      return (rate.high - MathMax(rate.open, rate.close)) / range;

   if(direction < 0)
      return (MathMin(rate.open, rate.close) - rate.low) / range;

   return 0.0;
  }

double AvgRange(MqlRates &rates[], const int start_shift, const int bars)
  {
   if(bars <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = start_shift; i < start_shift + bars; i++)
      sum += CandleRange(rates[i]);

   return sum / (double)bars;
  }

double EfficiencyRatio(MqlRates &rates[], const int start_shift, const int bars)
  {
   int total = ArraySize(rates);
   if(bars < 2 || total <= 0 || start_shift < 0 || (start_shift + bars - 1) >= total)
      return 0.0;

   double directional_move = MathAbs(rates[start_shift].close - rates[start_shift + bars - 1].close);
   double traveled = 0.0;
   for(int i = start_shift; i < start_shift + bars - 1; i++)
      traveled += MathAbs(rates[i].close - rates[i + 1].close);

   if(traveled <= 0.0)
      return 0.0;

   return directional_move / traveled;
  }

double AtrRegimeRatio(const int shift, const int lookback)
  {
   if(lookback <= 1)
      return 1.0;

   double current_atr = CurrentATR(shift);
   if(current_atr <= 0.0)
      return 0.0;

   double sum = 0.0;
   int count = 0;
   for(int i = shift + 1; i <= shift + lookback; i++)
     {
      double value = 0.0;
      if(ReadBufferValue(h_atr_ltf, 0, i, value) && value > 0.0)
        {
         sum += value;
         count++;
        }
     }

   if(count <= 0 || sum <= 0.0)
      return 0.0;

   return current_atr / (sum / (double)count);
  }

string BuildModeComment(const SignalInfo &sig)
  {
   return StringFormat("SOVA|%s|%s|S%d", ModeToText(sig.mode), sig.submode, sig.htf_score);
  }

bool ParseModeFromComment(const string comment, SignalMode &mode)
  {
   mode = MODE_NONE;
   if(StringFind(comment, "Bandwagon") >= 0)
     {
      mode = MODE_BANDWAGON;
      return true;
     }
   if(StringFind(comment, "Stealth") >= 0)
     {
      mode = MODE_STEALTH;
      return true;
     }
   return false;
  }

string ParseSubmodeFromComment(const string comment)
  {
   if(StringFind(comment, "DirectBreak") >= 0)
      return "DirectBreak";
   if(StringFind(comment, "CompressionRelease") >= 0)
      return "CompressionRelease";
   return "Unknown";
  }

void UpdateTimeframes()
  {
   g_ltf = (ENUM_TIMEFRAMES)_Period;
   g_htf = InpAutoHTF ? AutoHigherTF(g_ltf) : InpManualHTF;
  }

bool RebuildHandles()
  {
   if(h_atr_ltf      != INVALID_HANDLE) IndicatorRelease(h_atr_ltf);
   if(h_ema_fast_ltf != INVALID_HANDLE) IndicatorRelease(h_ema_fast_ltf);
   if(h_ema_fast_htf != INVALID_HANDLE) IndicatorRelease(h_ema_fast_htf);
   if(h_ema_slow_htf != INVALID_HANDLE) IndicatorRelease(h_ema_slow_htf);
   if(h_adx_htf      != INVALID_HANDLE) IndicatorRelease(h_adx_htf);
   if(h_bands_ltf    != INVALID_HANDLE) IndicatorRelease(h_bands_ltf);

   h_atr_ltf      = iATR(_Symbol, g_ltf, InpATRPeriod);
   h_ema_fast_ltf = iMA(_Symbol, g_ltf, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_fast_htf = iMA(_Symbol, g_htf, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_slow_htf = iMA(_Symbol, g_htf, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   h_adx_htf      = iADX(_Symbol, g_htf, InpADXPeriod);
   h_bands_ltf    = iBands(_Symbol, g_ltf, InpBBPeriod, 0, InpBBDev, PRICE_CLOSE);

   if(h_atr_ltf == INVALID_HANDLE || h_ema_fast_ltf == INVALID_HANDLE || h_ema_fast_htf == INVALID_HANDLE ||
      h_ema_slow_htf == INVALID_HANDLE || h_adx_htf == INVALID_HANDLE || h_bands_ltf == INVALID_HANDLE)
     {
      Print("[SOV ASCENDANT] ERROR: failed to create indicator handles.");
      return false;
     }

   return true;
  }

void UpdateRiskGuards()
  {
   int day_key = CurrentDayKey();
   if(day_key != g_day_key)
     {
      g_day_key = day_key;
      g_day_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_daily_guard_tripped = false;
      g_consecutive_losses = 0;
     }

   if(!InpEnableDailyDDGuard || g_day_start_equity <= 0.0)
      return;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd_pct = ((g_day_start_equity - equity) / g_day_start_equity) * 100.0;
   if(dd_pct >= InpDailyDDLimitPct)
      g_daily_guard_tripped = true;
  }

double CurrentDailyPnLPct()
  {
   if(g_day_start_equity <= 0.0)
      return 0.0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return ((equity - g_day_start_equity) / g_day_start_equity) * 100.0;
  }

double CurrentDailyDDPct()
  {
   if(g_day_start_equity <= 0.0)
      return 0.0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return ((g_day_start_equity - equity) / g_day_start_equity) * 100.0;
  }

bool TradingAllowedByGuards(string &why)
  {
   why = "";

   if(InpManualKillSwitch)
     {
      why = "Manual kill switch";
      return false;
     }

   if(g_daily_guard_tripped)
     {
      why = "Daily DD guard";
      return false;
     }

   if(InpEnableConsecLossGuard && g_consecutive_losses >= InpMaxConsecutiveLosses)
     {
      why = "Consecutive loss guard";
      return false;
     }

   return true;
  }

bool CheckUpcomingEvent()
  {
   if(!InpEnableNewsEventFilter)
      return false;

   int file = FileOpen(InpNewsEventFile, FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON);
   if(file == INVALID_HANDLE)
      return false;

   datetime now = TimeCurrent();
   bool blocked = false;

   while(!FileIsEnding(file))
     {
      string time_str = FileReadString(file);
      if(FileIsEnding(file))
         break;
      double impact_value = FileReadNumber(file);

      datetime event_time = StringToTime(time_str);
      if(event_time <= 0)
         continue;

      long lead = (long)(event_time - now);
      if(lead >= 0 && lead <= InpNewsLookaheadMinutes * 60 && (int)impact_value >= InpNewsMinImpact)
        {
         blocked = true;
         break;
        }
     }

   FileClose(file);
   return blocked;
  }

double ScoreRiskMultiplier(const int score)
  {
   if(score <= InpMinTrendScore)
      return InpRiskMultWeak;
   if(score == InpMinTrendScore + 1)
      return InpRiskMultMedium;
   if(score == InpMinTrendScore + 2)
      return InpRiskMultStrong;
   return InpRiskMultVeryStrong;
  }

double LossClusterRiskMultiplier()
  {
   if(g_consecutive_losses >= 2)
      return InpLossClusterRiskScale2;
   if(g_consecutive_losses == 1)
      return InpLossClusterRiskScale1;
   return 1.0;
  }

double DailySoftRiskMultiplier()
  {
   if(!InpEnableDailySoftThrottle)
      return 1.0;
   if(CurrentDailyPnLPct() >= InpDailySoftTargetPct)
      return InpDailySoftRiskScale;
   return 1.0;
  }

double CalcRiskPercent(const SignalInfo &sig)
  {
   double risk_pct = InpBaseRiskPercent;
   risk_pct *= ScoreRiskMultiplier(sig.htf_score);
   risk_pct *= LossClusterRiskMultiplier();
   risk_pct *= DailySoftRiskMultiplier();
   return MathMax(0.0, risk_pct);
  }

string ScoreBucketLabel(const int score)
  {
   if(score <= InpMinTrendScore)
      return "Weak";
   if(score == InpMinTrendScore + 1)
      return "Medium";
   if(score == InpMinTrendScore + 2)
      return "Strong";
   return "VeryStrong";
  }

string DetermineVolatilityBucket(const double atr_points)
  {
   double atr_values[40];
   ArrayInitialize(atr_values, 0.0);
   int valid = 0;
   for(int i = 1; i <= 30; i++)
     {
      double value = 0.0;
      if(ReadBufferValue(h_atr_ltf, 0, i, value) && value > 0.0)
        {
         atr_values[valid] = value;
         valid++;
        }
     }

   if(valid < 10)
      return "Unknown";

   double sum = 0.0;
   for(int i = 0; i < valid; i++)
      sum += atr_values[i];

   double avg_atr = sum / (double)valid;
   if(avg_atr <= 0.0)
      return "Unknown";

   double ratio = atr_points / avg_atr;
   if(ratio < 0.80)
      return "Low";
   if(ratio > 1.20)
      return "High";
   return "Normal";
  }

double LotsByRisk(const double stop_loss_points, const double risk_pct)
  {
   if(stop_loss_points <= 0.0 || risk_pct <= 0.0)
      return 0.0;

   double point_value = PointValuePerLot();
   if(point_value <= 0.0)
      return 0.0;

   double risk_money = AccountInfoDouble(ACCOUNT_EQUITY) * (risk_pct / 100.0);
   double lots = risk_money / (stop_loss_points * point_value);
   lots = MathMin(lots, InpMaxLotsPerTrade);
   return NormalizeVolume(lots);
  }

bool EvalHTFState(const int shift, int &dir, int &score, int &margin, string &why)
  {
   dir = TREND_FLAT;
   score = 0;
   margin = 0;
   why = "";

   double ema_fast = 0.0;
   double ema_slow = 0.0;
   double ema_fast_prev = 0.0;
   double adx = 0.0;
   double plus_di = 0.0;
   double minus_di = 0.0;

   if(!ReadBufferValue(h_ema_fast_htf, 0, shift, ema_fast)) { why = "No HTF EMA fast"; return false; }
   if(!ReadBufferValue(h_ema_slow_htf, 0, shift, ema_slow)) { why = "No HTF EMA slow"; return false; }
   if(!ReadBufferValue(h_ema_fast_htf, 0, shift + 1, ema_fast_prev)) { why = "No HTF EMA fast prev"; return false; }
   if(!ReadBufferValue(h_adx_htf, 0, shift, adx)) { why = "No HTF ADX"; return false; }
   if(!ReadBufferValue(h_adx_htf, 1, shift, plus_di)) { why = "No +DI"; return false; }
   if(!ReadBufferValue(h_adx_htf, 2, shift, minus_di)) { why = "No -DI"; return false; }

   MqlRates rates[];
   if(!ReadRates(g_htf, shift + 3, rates))
     {
      why = "No HTF rates";
      return false;
     }

   int bull = 0;
   int bear = 0;

   if(ema_fast > ema_slow)
      bull += 2;
   if(ema_fast < ema_slow)
      bear += 2;

   if(ema_fast > ema_fast_prev)
      bull += 1;
   if(ema_fast < ema_fast_prev)
      bear += 1;

   if(adx >= InpADXThreshold)
     {
      if(plus_di > minus_di)
        {
         bull += 2;
        }
      else if(minus_di > plus_di)
        {
         bear += 2;
        }
     }

   if(rates[shift].close > ema_fast)
      bull += 1;
   if(rates[shift].close < ema_fast)
      bear += 1;

   margin = MathAbs(bull - bear);
   if(bull >= InpMinTrendScore && bull >= bear + InpMinScoreMargin)
     {
      dir = TREND_BULL;
      score = bull;
      return true;
     }

   if(bear >= InpMinTrendScore && bear >= bull + InpMinScoreMargin)
     {
      dir = TREND_BEAR;
      score = bear;
      return true;
     }

   why = StringFormat("Weak HTF bull=%d bear=%d", bull, bear);
   dir = TREND_FLAT;
   score = MathMax(bull, bear);
   return true;
  }

int EvalHTFTrend(const int shift=1)
  {
   int dir = TREND_FLAT;
   int score = 0;
   int margin = 0;
   string why = "";
   if(!EvalHTFState(shift, dir, score, margin, why))
      return TREND_FLAT;
   return dir;
  }

bool GetSwingHL(const int lookback, double &swing_high, double &swing_low)
  {
   MqlRates rates[];
   if(!ReadRates(g_ltf, lookback + 5, rates))
      return false;

   swing_high = -DBL_MAX;
   swing_low  = DBL_MAX;

   for(int i = 2; i < lookback + 2; i++)
     {
      if(rates[i].high > swing_high)
         swing_high = rates[i].high;
      if(rates[i].low < swing_low)
         swing_low = rates[i].low;
     }

   return swing_high > -DBL_MAX / 2.0 && swing_low < DBL_MAX / 2.0;
  }

bool VolumeConfirmNow(const double factor, const int shift=1, const int avg_bars=20)
  {
   MqlRates rates[];
   if(!ReadRates(g_ltf, avg_bars + shift + 2, rates))
      return false;

   double avg_volume = 0.0;
   int count = 0;
   for(int i = shift + 1; i <= shift + avg_bars; i++)
     {
      avg_volume += (double)rates[i].tick_volume;
      count++;
     }

   if(count <= 0)
      return false;

   avg_volume /= (double)count;
   double current_volume = (double)rates[shift].tick_volume;
   return current_volume >= avg_volume * factor;
  }

bool Trigger_Bandwagon(const int trend, const int htf_score, const int htf_margin, SignalInfo &sig)
  {
   if(!InpEnableBandwagon)
      return false;

   double swing_high = 0.0;
   double swing_low = 0.0;
   if(!GetSwingHL(InpSwingLookback, swing_high, swing_low))
      return false;

   MqlRates rates[];
   if(!ReadRates(g_ltf, MathMax(InpSwingLookback + 5, 30), rates))
      return false;

   double atr = CurrentATR(1);
   if(atr <= 0.0)
      return false;

   if(!VolumeConfirmNow(InpBandwagonVolFactor, 1, 20))
      return false;

   double ema_fast = 0.0;
   if(!ReadBufferValue(h_ema_fast_ltf, 0, 1, ema_fast))
      return false;

   double breakout_min = atr * InpBandwagonMinBreakATR;
   double distance_from_ema = MathAbs(rates[1].close - ema_fast);
   if(distance_from_ema > atr * InpBandwagonMaxChaseATR)
      return false;

   double body_ratio = CandleBodyRatio(rates[1]);
   if(body_ratio < MathMax(InpBandwagonMinBodyRatio, InpGlobalMinBodyRatio))
      return false;

   if(InpEnablePriceActionContext)
     {
      double close_location = CandleCloseLocation(rates[1], trend);
      double exhaustion_wick = DirectionalExhaustionWickRatio(rates[1], trend);
      double efficiency_ratio = EfficiencyRatio(rates, 2, InpEnvironmentLookbackBars);
      double atr_regime_ratio = AtrRegimeRatio(1, InpATRRegimeLookback);

      if(close_location < InpBandwagonMinCloseLocation)
         return false;
      if(exhaustion_wick > InpBandwagonMaxExhaustionWickRatio)
         return false;
      if(efficiency_ratio < InpBandwagonMinEfficiencyRatio)
         return false;
      if(atr_regime_ratio < InpBandwagonMinAtrRegimeRatio || atr_regime_ratio > InpBandwagonMaxAtrRegimeRatio)
         return false;
     }

   bool bull_break = rates[1].close > swing_high + breakout_min && rates[1].close > rates[1].open;
   bool bear_break = rates[1].close < swing_low - breakout_min && rates[1].close < rates[1].open;

   if(trend == TREND_BULL && InpAllowLong && bull_break)
     {
      sig.valid = true;
      sig.mode = MODE_BANDWAGON;
      sig.submode = "DirectBreak";
      sig.direction = +1;
      sig.fixed_lots = InpBandwagonFixedLots;
      sig.sl_atr = InpBandwagonSL_ATR;
      sig.rr = InpBandwagonTP_RR;
      sig.trail_atr = InpBandwagonTrailATR;
      sig.be_atr = InpBandwagonBE_ATR;
      sig.partial_rr = InpBandwagonPartialRR;
      sig.partial_close_pct = InpBandwagonPartialClosePct;
      sig.max_hold_bars = InpBandwagonMaxHoldBars;
      sig.htf_score = htf_score;
      sig.htf_score_margin = htf_margin;
      sig.htf_direction = trend;
      sig.entry_reason_code = "BW_DIRECT_BREAK";
      sig.entry_reason_text = "Bandwagon impulse breakout";
      sig.breakout_distance_atr = (rates[1].close - swing_high) / atr;
      sig.body_ratio_entry = body_ratio;
      sig.compression_score = 0.0;
      sig.release_strength_score = 0.0;
      return true;
     }

   if(trend == TREND_BEAR && InpAllowShort && bear_break)
     {
      sig.valid = true;
      sig.mode = MODE_BANDWAGON;
      sig.submode = "DirectBreak";
      sig.direction = -1;
      sig.fixed_lots = InpBandwagonFixedLots;
      sig.sl_atr = InpBandwagonSL_ATR;
      sig.rr = InpBandwagonTP_RR;
      sig.trail_atr = InpBandwagonTrailATR;
      sig.be_atr = InpBandwagonBE_ATR;
      sig.partial_rr = InpBandwagonPartialRR;
      sig.partial_close_pct = InpBandwagonPartialClosePct;
      sig.max_hold_bars = InpBandwagonMaxHoldBars;
      sig.htf_score = htf_score;
      sig.htf_score_margin = htf_margin;
      sig.htf_direction = trend;
      sig.entry_reason_code = "BW_DIRECT_BREAK";
      sig.entry_reason_text = "Bandwagon impulse breakout";
      sig.breakout_distance_atr = (swing_low - rates[1].close) / atr;
      sig.body_ratio_entry = body_ratio;
      sig.compression_score = 0.0;
      sig.release_strength_score = 0.0;
      return true;
     }

   return false;
  }

bool Trigger_Stealth(const int trend, const int htf_score, const int htf_margin, SignalInfo &sig)
  {
   if(!InpEnableStealth)
      return false;

   MqlRates rates[];
   int need_bars = MathMax(InpSqueezeLookback + 8, 40);
   if(!ReadRates(g_ltf, need_bars, rates))
      return false;

   double atr = CurrentATR(1);
   if(atr <= 0.0)
      return false;

   double avg_width = 0.0;
   int width_count = 0;
   int compressed_count = 0;

   for(int i = 2; i <= InpSqueezeLookback + 1; i++)
     {
      double upper = 0.0;
      double lower = 0.0;
      if(!ReadBufferValue(h_bands_ltf, 1, i, upper))
         return false;
      if(!ReadBufferValue(h_bands_ltf, 2, i, lower))
         return false;
      avg_width += upper - lower;
      width_count++;
     }

   if(width_count <= 0)
      return false;

   avg_width /= (double)width_count;

   for(int i = 2; i <= InpSqueezeLookback + 1; i++)
     {
      double upper = 0.0;
      double lower = 0.0;
      if(!ReadBufferValue(h_bands_ltf, 1, i, upper))
         return false;
      if(!ReadBufferValue(h_bands_ltf, 2, i, lower))
         return false;

      double width = upper - lower;
      if(width <= avg_width * InpSqueezeWidthFactor)
         compressed_count++;
     }

   if(compressed_count < InpMinCompressedBars)
      return false;

   double box_high = -DBL_MAX;
   double box_low = DBL_MAX;
   for(int i = 2; i <= InpSqueezeLookback + 1; i++)
     {
      if(rates[i].high > box_high)
         box_high = rates[i].high;
      if(rates[i].low < box_low)
         box_low = rates[i].low;
     }

   double avg_range = AvgRange(rates, 2, InpSqueezeLookback);
   if(avg_range <= 0.0)
      return false;

   if(!VolumeConfirmNow(InpStealthVolFloor, 1, 20))
      return false;

   double ema_fast = 0.0;
   if(!ReadBufferValue(h_ema_fast_ltf, 0, 1, ema_fast))
      return false;

   double current_range = CandleRange(rates[1]);
   double release_strength = current_range / avg_range;
   double compression_score = (double)compressed_count / (double)InpSqueezeLookback;
   double release_body_ratio = CandleBodyRatio(rates[1]);

   if(release_body_ratio < InpGlobalMinBodyRatio)
      return false;

   if(InpEnablePriceActionContext)
     {
      double close_location = CandleCloseLocation(rates[1], trend);
      double exhaustion_wick = DirectionalExhaustionWickRatio(rates[1], trend);
      double pre_break_efficiency = EfficiencyRatio(rates, 2, InpEnvironmentLookbackBars);
      double atr_regime_ratio = AtrRegimeRatio(1, InpATRRegimeLookback);

      if(close_location < InpStealthMinCloseLocation)
         return false;
      if(exhaustion_wick > InpStealthMaxExhaustionWickRatio)
         return false;
      if(pre_break_efficiency > InpStealthMaxPreBreakEfficiencyRatio)
         return false;
      if(atr_regime_ratio < InpStealthMinAtrRegimeRatio || atr_regime_ratio > InpStealthMaxAtrRegimeRatio)
         return false;
     }

   bool release_bull = rates[1].close > box_high && rates[1].close > ema_fast && current_range >= avg_range * InpStealthReleaseFactor;
   bool release_bear = rates[1].close < box_low && rates[1].close < ema_fast && current_range >= avg_range * InpStealthReleaseFactor;

   if(trend == TREND_BULL && InpAllowLong && release_bull)
     {
      sig.valid = true;
      sig.mode = MODE_STEALTH;
      sig.submode = "CompressionRelease";
      sig.direction = +1;
      sig.fixed_lots = InpStealthFixedLots;
      sig.sl_atr = InpStealthSL_ATR;
      sig.rr = InpStealthTP_RR;
      sig.trail_atr = InpStealthTrailATR;
      sig.be_atr = InpStealthBE_ATR;
      sig.partial_rr = InpStealthPartialRR;
      sig.partial_close_pct = InpStealthPartialClosePct;
      sig.max_hold_bars = InpStealthMaxHoldBars;
      sig.htf_score = htf_score;
      sig.htf_score_margin = htf_margin;
      sig.htf_direction = trend;
      sig.entry_reason_code = "ST_RELEASE_BOX";
      sig.entry_reason_text = "Stealth squeeze release";
      sig.breakout_distance_atr = (rates[1].close - box_high) / atr;
      sig.body_ratio_entry = release_body_ratio;
      sig.compression_score = compression_score;
      sig.release_strength_score = release_strength;
      return true;
     }

   if(trend == TREND_BEAR && InpAllowShort && release_bear)
     {
      sig.valid = true;
      sig.mode = MODE_STEALTH;
      sig.submode = "CompressionRelease";
      sig.direction = -1;
      sig.fixed_lots = InpStealthFixedLots;
      sig.sl_atr = InpStealthSL_ATR;
      sig.rr = InpStealthTP_RR;
      sig.trail_atr = InpStealthTrailATR;
      sig.be_atr = InpStealthBE_ATR;
      sig.partial_rr = InpStealthPartialRR;
      sig.partial_close_pct = InpStealthPartialClosePct;
      sig.max_hold_bars = InpStealthMaxHoldBars;
      sig.htf_score = htf_score;
      sig.htf_score_margin = htf_margin;
      sig.htf_direction = trend;
      sig.entry_reason_code = "ST_RELEASE_BOX";
      sig.entry_reason_text = "Stealth squeeze release";
      sig.breakout_distance_atr = (box_low - rates[1].close) / atr;
      sig.body_ratio_entry = release_body_ratio;
      sig.compression_score = compression_score;
      sig.release_strength_score = release_strength;
      return true;
     }

   return false;
  }

bool EvalModeAndArmed(SignalInfo &sig)
  {
   sig.valid = false;
   sig.mode = MODE_NONE;
   sig.submode = "Unknown";
   sig.direction = 0;
   sig.fixed_lots = 0.0;
   sig.sl_atr = 0.0;
   sig.rr = 0.0;
   sig.trail_atr = 0.0;
   sig.be_atr = 0.0;
   sig.partial_rr = 0.0;
   sig.partial_close_pct = 0.0;
   sig.max_hold_bars = 0;
   sig.htf_score = 0;
   sig.htf_score_margin = 0;
   sig.htf_direction = TREND_FLAT;
   sig.entry_reason_code = "";
   sig.entry_reason_text = "";
   sig.breakout_distance_atr = 0.0;
   sig.body_ratio_entry = 0.0;
   sig.compression_score = 0.0;
   sig.release_strength_score = 0.0;

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      sig.entry_reason_text = "Trade disabled";
      return false;
     }

   string guard_reason = "";
   if(!TradingAllowedByGuards(guard_reason))
     {
      sig.entry_reason_text = guard_reason;
      return false;
     }

   if(InpOnePositionPerSymbol && HasOpenPosition())
     {
      sig.entry_reason_text = "Position exists";
      return false;
     }

   if(TimeCurrent() - g_last_trade_time < InpCooldownSec)
     {
      sig.entry_reason_text = "Cooldown";
      return false;
     }

   if(!SessionOK())
     {
      sig.entry_reason_text = "Session blocked";
      return false;
     }

   if(!SpreadOK())
     {
      sig.entry_reason_text = "Spread blocked";
      return false;
     }

   if(CheckUpcomingEvent())
     {
      sig.entry_reason_text = "Upcoming TE event";
      return false;
     }

   int armed_trend = TREND_FLAT;
   int armed_score = 0;
   int armed_margin = 0;
   string armed_why = "";
   if(!EvalHTFState(1, armed_trend, armed_score, armed_margin, armed_why))
     {
      sig.entry_reason_text = armed_why;
      return false;
     }

   if(armed_trend == TREND_FLAT)
     {
      sig.entry_reason_text = armed_why;
      return false;
     }

   for(int i = 2; i <= InpHTFConfirmBars; i++)
     {
      int confirm_dir = TREND_FLAT;
      int confirm_score = 0;
      int confirm_margin = 0;
      string confirm_why = "";
      if(!EvalHTFState(i, confirm_dir, confirm_score, confirm_margin, confirm_why))
        {
         sig.entry_reason_text = confirm_why;
         return false;
        }
      if(confirm_dir != armed_trend)
        {
         sig.entry_reason_text = "HTF not armed";
         return false;
        }
     }

   g_last_trend_dir = armed_trend;
   g_last_trend_score = armed_score;
   g_last_trend_margin = armed_margin;

   if(Trigger_Bandwagon(armed_trend, armed_score, armed_margin, sig))
      return true;
   if(Trigger_Stealth(armed_trend, armed_score, armed_margin, sig))
      return true;

   sig.entry_reason_text = "No LTF trigger";
   return false;
  }

int FindStateIndex(const ulong position_id)
  {
   for(int i = 0; i < ArraySize(g_states); i++)
     {
      if(g_states[i].position_id == position_id)
         return i;
     }
   return -1;
  }

bool IsPositionIdStillOpen(const ulong position_id)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_id)
         return true;
     }
   return false;
  }

bool EnsureAuditHeader()
  {
   if(!InpEnableAuditCSV)
      return true;

   int file = FileOpen(InpAuditFileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON);
   if(file == INVALID_HANDLE)
      return false;

   if(FileSize(file) == 0)
     {
      FileWrite(file,
                "trade_id",
                "strategy_family",
                "strategy_version",
                "symbol",
                "timeframe",
                "session_bucket",
                "mode",
                "submode",
                "htf_direction",
                "htf_score",
                "htf_score_margin",
                "entry_bar_time",
                "entry_time",
                "entry_price",
                "spread_points_entry",
                "atr_points_entry",
                "volatility_bucket",
                "stop_loss_points",
                "take_profit_points",
                "risk_percent",
                "size_lots",
                "entry_reason_code",
                "breakout_distance_atr",
                "body_ratio_entry",
                "compression_score",
                "release_strength_score",
                "exit_time",
                "exit_price",
                "exit_reason",
                "gross_pnl",
                "net_pnl",
                "commission",
                "swap",
                "r_multiple",
                "mae_points",
                "mfe_points",
                "holding_seconds",
                "consecutive_losses_before_entry",
                "daily_dd_pct_before_entry",
                "partial_close_count",
                "first_partial_r",
                "trail_activated",
                "be_activated");
     }

   FileClose(file);
   return true;
  }

bool RegisterPositionState(const SignalInfo &sig,
                           const double entry_price,
                           const double stop_loss_points,
                           const double take_profit_points,
                           const double size_lots,
                           const double risk_percent)
  {
   if(!PositionSelect(_Symbol))
      return false;

   long magic = (long)PositionGetInteger(POSITION_MAGIC);
   if(magic != InpMagicNumber)
      return false;

   ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   int idx = FindStateIndex(position_id);
   if(idx < 0)
     {
      idx = ArraySize(g_states);
      ArrayResize(g_states, idx + 1);
     }

   PositionState state;
   state.position_id = position_id;
   state.symbol = _Symbol;
   state.mode = sig.mode;
   state.submode = sig.submode;
   state.direction = sig.direction;
   state.entry_time = (datetime)PositionGetInteger(POSITION_TIME);
   state.entry_bar_time = iTime(_Symbol, _Period, 1);
   state.entry_price = entry_price;
   state.spread_points_entry = CurrentSpreadPoints();
   state.atr_points_entry = CurrentATR(1) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   state.session_bucket = CurrentSessionBucket();
   state.volatility_bucket = DetermineVolatilityBucket(state.atr_points_entry);
   state.htf_direction = sig.htf_direction;
   state.htf_score = sig.htf_score;
   state.htf_score_margin = sig.htf_score_margin;
   state.stop_loss_points = stop_loss_points;
   state.take_profit_points = take_profit_points;
   state.risk_percent = risk_percent;
   state.size_lots = size_lots;
   state.entry_reason_code = sig.entry_reason_code;
   state.pending_exit_reason = "";
   state.breakout_distance_atr = sig.breakout_distance_atr;
   state.body_ratio_entry = sig.body_ratio_entry;
   state.compression_score = sig.compression_score;
   state.release_strength_score = sig.release_strength_score;
   state.mae_points = 0.0;
   state.mfe_points = 0.0;
   state.consecutive_losses_before_entry = g_consecutive_losses;
   state.daily_dd_pct_before_entry = CurrentDailyDDPct();
   state.partial_close_count = 0;
   state.first_partial_r = 0.0;
   state.trail_activated = false;
   state.be_activated = false;
   state.realized_profit = 0.0;
   state.realized_commission = 0.0;
   state.realized_swap = 0.0;

   g_states[idx] = state;
   return true;
  }

void ReconstructStateFromPosition()
  {
   if(!PositionSelect(_Symbol))
      return;

   long magic = (long)PositionGetInteger(POSITION_MAGIC);
   if(magic != InpMagicNumber)
      return;

   ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(FindStateIndex(position_id) >= 0)
      return;

   SignalMode mode = MODE_NONE;
   string comment = PositionGetString(POSITION_COMMENT);
   ParseModeFromComment(comment, mode);

   PositionState state;
   state.position_id = position_id;
   state.symbol = _Symbol;
   state.mode = mode;
   state.submode = ParseSubmodeFromComment(comment);
   state.direction = ((long)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
   state.entry_time = (datetime)PositionGetInteger(POSITION_TIME);
   state.entry_bar_time = state.entry_time;
   state.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
   state.spread_points_entry = CurrentSpreadPoints();
   state.atr_points_entry = CurrentATR(1) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   state.session_bucket = "Unknown";
   state.volatility_bucket = DetermineVolatilityBucket(state.atr_points_entry);
   state.htf_direction = g_last_trend_dir;
   state.htf_score = g_last_trend_score;
   state.htf_score_margin = g_last_trend_margin;
   state.stop_loss_points = MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_SL)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   state.take_profit_points = MathAbs(PositionGetDouble(POSITION_TP) - PositionGetDouble(POSITION_PRICE_OPEN)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   state.risk_percent = 0.0;
   state.size_lots = PositionGetDouble(POSITION_VOLUME);
   state.entry_reason_code = "UNKNOWN_RECONSTRUCTED";
   state.pending_exit_reason = "";
   state.breakout_distance_atr = 0.0;
   state.body_ratio_entry = 0.0;
   state.compression_score = 0.0;
   state.release_strength_score = 0.0;
   state.mae_points = 0.0;
   state.mfe_points = 0.0;
   state.consecutive_losses_before_entry = g_consecutive_losses;
   state.daily_dd_pct_before_entry = CurrentDailyDDPct();
   state.partial_close_count = 0;
   state.first_partial_r = 0.0;
   state.trail_activated = false;
   state.be_activated = false;
   state.realized_profit = 0.0;
   state.realized_commission = 0.0;
   state.realized_swap = 0.0;

   int new_idx = ArraySize(g_states);
   ArrayResize(g_states, new_idx + 1);
   g_states[new_idx] = state;
  }

void RemoveStateAt(const int idx)
  {
   int total = ArraySize(g_states);
   if(idx < 0 || idx >= total)
      return;
   for(int i = idx; i < total - 1; i++)
      g_states[i] = g_states[i + 1];
   ArrayResize(g_states, total - 1);
  }

string DetermineExitReason(const PositionState &state, const ulong deal_ticket)
  {
   if(StringLen(state.pending_exit_reason) > 0)
      return state.pending_exit_reason;

   long deal_reason = HistoryDealGetInteger(deal_ticket, DEAL_REASON);

   if(deal_reason == DEAL_REASON_TP)
      return "TakeProfit";

   if(deal_reason == DEAL_REASON_SL)
     {
      if(state.partial_close_count > 0 && state.trail_activated)
         return "PartialThenTrail";
      if(state.trail_activated)
         return "TrailingStop";
      if(state.be_activated)
         return "BreakEven";
      return "StopLoss";
     }

   if(state.partial_close_count > 0 && state.trail_activated)
      return "PartialThenTrail";

   return "Unknown";
  }

void WriteAuditRow(const PositionState &state, const ulong deal_ticket)
  {
   if(!InpEnableAuditCSV)
      return;
   if(!EnsureAuditHeader())
      return;

   double point_value = PointValuePerLot();
   double initial_risk_money = state.stop_loss_points * point_value * state.size_lots;
   double net_pnl = state.realized_profit + state.realized_commission + state.realized_swap;
   double gross_pnl = state.realized_profit;
   double r_multiple = 0.0;
   if(initial_risk_money > 0.0)
      r_multiple = net_pnl / initial_risk_money;

   datetime exit_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   double exit_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   string exit_reason = DetermineExitReason(state, deal_ticket);

   int file = FileOpen(InpAuditFileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON);
   if(file == INVALID_HANDLE)
      return;

   FileSeek(file, 0, SEEK_END);
   FileWrite(file,
             (string)state.position_id,
             "SOVEREIGN",
             "ASCENDANT_v1",
             state.symbol,
             TFToString(g_ltf),
             state.session_bucket,
             ModeToText(state.mode),
             state.submode,
             TrendToText(state.htf_direction),
             state.htf_score,
             state.htf_score_margin,
             TimeToString(state.entry_bar_time, TIME_DATE | TIME_MINUTES),
             TimeToString(state.entry_time, TIME_DATE | TIME_SECONDS),
             DoubleToString(state.entry_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
             DoubleToString(state.spread_points_entry, 2),
             DoubleToString(state.atr_points_entry, 2),
             state.volatility_bucket,
             DoubleToString(state.stop_loss_points, 2),
             DoubleToString(state.take_profit_points, 2),
             DoubleToString(state.risk_percent, 4),
             DoubleToString(state.size_lots, VolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))),
             state.entry_reason_code,
             DoubleToString(state.breakout_distance_atr, 4),
             DoubleToString(state.body_ratio_entry, 4),
             DoubleToString(state.compression_score, 4),
             DoubleToString(state.release_strength_score, 4),
             TimeToString(exit_time, TIME_DATE | TIME_SECONDS),
             DoubleToString(exit_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
             exit_reason,
             DoubleToString(gross_pnl, 2),
             DoubleToString(net_pnl, 2),
             DoubleToString(state.realized_commission, 2),
             DoubleToString(state.realized_swap, 2),
             DoubleToString(r_multiple, 4),
             DoubleToString(state.mae_points, 2),
             DoubleToString(state.mfe_points, 2),
             (int)(exit_time - state.entry_time),
             state.consecutive_losses_before_entry,
             DoubleToString(state.daily_dd_pct_before_entry, 2),
             state.partial_close_count,
             DoubleToString(state.first_partial_r, 4),
             state.trail_activated ? 1 : 0,
             state.be_activated ? 1 : 0);
   FileClose(file);
  }

void FinalizeStateOnClose(const ulong position_id, const ulong deal_ticket)
  {
   int idx = FindStateIndex(position_id);
   if(idx < 0)
      return;

   double net_pnl = g_states[idx].realized_profit + g_states[idx].realized_commission + g_states[idx].realized_swap;
   if(net_pnl < 0.0)
      g_consecutive_losses++;
   else if(net_pnl > 0.0)
      g_consecutive_losses = 0;

   WriteAuditRow(g_states[idx], deal_ticket);
   RemoveStateAt(idx);
  }

double MinVolume()
  {
   return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  }

bool TryPartialClose(PositionState &state, const double current_volume, const double current_r)
  {
   if(state.partial_close_count > 0)
      return false;

   double pct = (state.mode == MODE_BANDWAGON) ? InpBandwagonPartialClosePct : InpStealthPartialClosePct;
   if(pct <= 0.0 || pct >= 1.0)
      return false;

   double close_volume = NormalizeVolume(current_volume * pct);
   double min_volume = MinVolume();

   if(close_volume < min_volume)
      return false;
   if((current_volume - close_volume) < min_volume)
      close_volume = NormalizeVolume(current_volume - min_volume);
   if(close_volume < min_volume || close_volume >= current_volume)
      return false;

   if(trade.PositionClosePartial(_Symbol, close_volume))
     {
      state.partial_close_count = 1;
      state.first_partial_r = current_r;
      return true;
     }
   return false;
  }

void UpdateStateExcursions(PositionState &state, const double current_price)
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   double favorable = 0.0;
   double adverse = 0.0;
   if(state.direction > 0)
     {
      favorable = (current_price - state.entry_price) / point;
      adverse = (state.entry_price - current_price) / point;
     }
   else
     {
      favorable = (state.entry_price - current_price) / point;
      adverse = (current_price - state.entry_price) / point;
     }

   if(favorable > state.mfe_points)
      state.mfe_points = favorable;
   if(adverse > state.mae_points)
      state.mae_points = adverse;
  }

void CloseManagedPosition(PositionState &state, const string reason)
  {
   state.pending_exit_reason = reason;
   trade.PositionClose(_Symbol);
  }

void ManageOpenPosition()
  {
   ReconstructStateFromPosition();

   if(!PositionSelect(_Symbol))
      return;

   long magic = (long)PositionGetInteger(POSITION_MAGIC);
   if(magic != InpMagicNumber)
      return;

   ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   int idx = FindStateIndex(position_id);
   if(idx < 0)
      return;

   SignalMode state_mode = g_states[idx].mode;
   int state_direction = g_states[idx].direction;
   datetime state_entry_time = g_states[idx].entry_time;
   double state_stop_loss_points = g_states[idx].stop_loss_points;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   long type = (long)PositionGetInteger(POSITION_TYPE);
   double current_price = (type == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
   UpdateStateExcursions(g_states[idx], current_price);

   string guard_reason = "";
   if(InpCloseOpenOnRiskGuard && !TradingAllowedByGuards(guard_reason))
     {
      CloseManagedPosition(g_states[idx], "RiskGuardClose");
      return;
     }

   double atr = CurrentATR(1);
   if(atr <= 0.0)
      return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double current_volume = PositionGetDouble(POSITION_VOLUME);
   int stops_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_stop_distance = stops_level_points * point;

   double trail_atr = (state_mode == MODE_STEALTH) ? InpStealthTrailATR : InpBandwagonTrailATR;
   double be_atr = (state_mode == MODE_STEALTH) ? InpStealthBE_ATR : InpBandwagonBE_ATR;
   double partial_rr = (state_mode == MODE_STEALTH) ? InpStealthPartialRR : InpBandwagonPartialRR;
   int max_hold_bars = (state_mode == MODE_STEALTH) ? InpStealthMaxHoldBars : InpBandwagonMaxHoldBars;

   double profit_distance = (state_direction > 0) ? (tick.bid - open_price) : (open_price - tick.ask);
   double current_r = 0.0;
   if(state_stop_loss_points > 0.0)
      current_r = (profit_distance / point) / state_stop_loss_points;

   if(max_hold_bars > 0)
     {
      int max_hold_seconds = PeriodSeconds(g_ltf) * max_hold_bars;
      if(max_hold_seconds > 0 && (int)(TimeCurrent() - state_entry_time) >= max_hold_seconds)
        {
         CloseManagedPosition(g_states[idx], "TimeStop");
         return;
        }
     }

   if(current_r >= partial_rr)
      TryPartialClose(g_states[idx], current_volume, current_r);

   double new_sl = current_sl;

   if(type == POSITION_TYPE_BUY)
     {
      if(profit_distance <= 0.0)
         return;

      if(profit_distance >= atr * be_atr)
        {
         double be_sl = NormalizeDouble(open_price + point, digits);
         if((current_sl == 0.0 || be_sl > new_sl) && (tick.bid - be_sl) >= min_stop_distance)
           {
            new_sl = be_sl;
            g_states[idx].be_activated = true;
           }
        }

      double trail_sl = NormalizeDouble(tick.bid - atr * trail_atr, digits);
      if((tick.bid - trail_sl) >= min_stop_distance && trail_sl > new_sl)
        {
         new_sl = trail_sl;
         g_states[idx].trail_activated = true;
        }

      if(new_sl > current_sl)
         trade.PositionModify(_Symbol, new_sl, current_tp);
     }
   else if(type == POSITION_TYPE_SELL)
     {
      if(profit_distance <= 0.0)
         return;

      if(profit_distance >= atr * be_atr)
        {
         double be_sl = NormalizeDouble(open_price - point, digits);
         if((current_sl == 0.0 || be_sl < new_sl) && (be_sl - tick.ask) >= min_stop_distance)
           {
            new_sl = be_sl;
            g_states[idx].be_activated = true;
           }
        }

      double trail_sl = NormalizeDouble(tick.ask + atr * trail_atr, digits);
      if((trail_sl - tick.ask) >= min_stop_distance && (current_sl == 0.0 || trail_sl < new_sl))
        {
         new_sl = trail_sl;
         g_states[idx].trail_activated = true;
        }

      if(current_sl == 0.0 || new_sl < current_sl)
         trade.PositionModify(_Symbol, new_sl, current_tp);
     }
  }

bool PlaceOrder(const SignalInfo &sig)
  {
   if(!sig.valid || sig.direction == 0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return false;

   double atr = CurrentATR(1);
   if(atr <= 0.0)
      return false;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int stops_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_stop_distance = stops_level_points * point;

   double sl_distance = MathMax(atr * sig.sl_atr, min_stop_distance + point);
   double tp_distance = sl_distance * sig.rr;
   double stop_loss_points = sl_distance / point;
   double take_profit_points = tp_distance / point;

   double risk_percent = 0.0;
   double lots = sig.fixed_lots;
   if(InpUseRiskPercent)
     {
      risk_percent = CalcRiskPercent(sig);
      lots = LotsByRisk(stop_loss_points, risk_percent);
     }

   lots = NormalizeVolume(lots);
   if(lots <= 0.0)
      return false;

   double entry = (sig.direction > 0) ? tick.ask : tick.bid;
   double sl = 0.0;
   double tp = 0.0;
   string comment = BuildModeComment(sig);

   bool ok = false;
   if(sig.direction > 0)
     {
      sl = NormalizeDouble(entry - sl_distance, digits);
      tp = NormalizeDouble(entry + tp_distance, digits);
      ok = trade.Buy(lots, _Symbol, 0.0, sl, tp, comment);
     }
   else
     {
      sl = NormalizeDouble(entry + sl_distance, digits);
      tp = NormalizeDouble(entry - tp_distance, digits);
      ok = trade.Sell(lots, _Symbol, 0.0, sl, tp, comment);
     }

   if(!ok)
     {
      Print("[SOV ASCENDANT] order failed. ret=", trade.ResultRetcode(), " msg=", trade.ResultRetcodeDescription());
      return false;
     }

   g_last_trade_time = TimeCurrent();
   RegisterPositionState(sig, entry, stop_loss_points, take_profit_points, lots, risk_percent);

   Print("[SOV ASCENDANT] Order placed. mode=", ModeToText(sig.mode),
         " submode=", sig.submode,
         " dir=", sig.direction > 0 ? "BUY" : "SELL",
         " score=", sig.htf_score,
         " risk%=", DoubleToString(risk_percent, 3),
         " lots=", DoubleToString(lots, 2),
         " reason=", sig.entry_reason_text);
   return true;
  }

void DrawPanel(const string extra="")
  {
   string guard_reason = "";
   bool guards_ok = TradingAllowedByGuards(guard_reason);

   string panel =
      "SOVEREIGN Ascendant v1\n" +
      "Symbol: " + _Symbol + "\n" +
      "LTF/HTF: " + TFToString(g_ltf) + " / " + TFToString(g_htf) + "\n" +
      "Trend: " + TrendToText(g_last_trend_dir) + " | Score: " + IntegerToString(g_last_trend_score) +
      " | Bucket: " + ScoreBucketLabel(g_last_trend_score) + "\n" +
      "SpreadOK: " + (SpreadOK() ? "YES" : "NO") + "\n" +
      "SessionOK: " + (SessionOK() ? "YES" : "NO") + " | EventOK: " + (CheckUpcomingEvent() ? "NO" : "YES") + "\n" +
      "Guards: " + (guards_ok ? "OK" : guard_reason) + "\n" +
      "DayPnL: " + DoubleToString(CurrentDailyPnLPct(), 2) + "% | DayDD: " + DoubleToString(CurrentDailyDDPct(), 2) + "%\n" +
      "LossStreak: " + IntegerToString(g_consecutive_losses) + "\n" +
      "Position: " + (HasOpenPosition() ? "OPEN" : "NONE") + "\n" +
      "Extra: " + extra;

   if(panel != g_last_panel)
     {
      Comment(panel);
      g_last_panel = panel;
     }
  }

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetAsyncMode(false);

   g_ltf = (ENUM_TIMEFRAMES)_Period;
   UpdateTimeframes();
   if(!RebuildHandles())
      return INIT_FAILED;

   if(InpEnableAuditCSV)
      EnsureAuditHeader();

   g_day_key = 0;
   UpdateRiskGuards();
   DrawPanel("Init OK");

   Print("[SOV ASCENDANT] Init complete. LTF=", TFToString(g_ltf), " HTF=", TFToString(g_htf));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(h_atr_ltf      != INVALID_HANDLE) IndicatorRelease(h_atr_ltf);
   if(h_ema_fast_ltf != INVALID_HANDLE) IndicatorRelease(h_ema_fast_ltf);
   if(h_ema_fast_htf != INVALID_HANDLE) IndicatorRelease(h_ema_fast_htf);
   if(h_ema_slow_htf != INVALID_HANDLE) IndicatorRelease(h_ema_slow_htf);
   if(h_adx_htf      != INVALID_HANDLE) IndicatorRelease(h_adx_htf);
   if(h_bands_ltf    != INVALID_HANDLE) IndicatorRelease(h_bands_ltf);
   Comment("");
   Print("[SOV ASCENDANT] Deinit. reason=", reason);
  }

void OnTick()
  {
   ulong now_ms = GetTickCount64();
   if(now_ms - g_last_tick_ms < (ulong)InpTickIntervalMS)
      return;
   g_last_tick_ms = now_ms;

   UpdateRiskGuards();
   ManageOpenPosition();

   if(!IsNewBar())
     {
      DrawPanel();
      return;
     }

   SignalInfo sig;
   if(EvalModeAndArmed(sig) && sig.valid)
      PlaceOrder(sig);

   DrawPanel(sig.entry_reason_text);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(!HistoryDealSelect(trans.deal))
      return;

   long deal_magic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(deal_magic != InpMagicNumber)
      return;

   long entry_type = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong position_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int idx = FindStateIndex(position_id);
   if(idx < 0)
      return;

   if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_OUT_BY)
     {
      g_states[idx].realized_profit += HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
      g_states[idx].realized_commission += HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      g_states[idx].realized_swap += HistoryDealGetDouble(trans.deal, DEAL_SWAP);

      if(!IsPositionIdStillOpen(position_id))
         FinalizeStateOnClose(position_id, trans.deal);
     }
  }
