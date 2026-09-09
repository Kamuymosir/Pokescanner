#property copyright "OpenAI"
#property version   "1.00"
#property strict
#property description "Reference MT5 EA inspired by public descriptions of Trader X's fast range scalping style."

#include <Trade/Trade.mqh>

enum BiasFilterMode
  {
   BIAS_FILTER_OFF = 0,
   BIAS_FILTER_EMA = 1
  };

input string           InpTradeSymbol            = "";
input ENUM_TIMEFRAMES  InpRangeTimeframe         = PERIOD_M1;
input int              InpRangeLookbackBars      = 20;
input double           InpMinRangeWidthPoints    = 100.0;
input double           InpMaxRangeWidthPoints    = 600.0;
input int              InpATRPeriod              = 14;
input double           InpMaxATRPoints           = 120.0;
input double           InpEdgeZonePercent        = 0.18;
input int              InpCooldownSeconds        = 15;
input int              InpTimeExitSeconds        = 20;
input bool             InpUseMidlineExit         = true;

input bool             InpUseRiskPercent         = true;
input double           InpRiskPercentPerCycle    = 0.50;
input double           InpFixedLotPerOrder       = 0.01;
input int              InpBurstOrders            = 3;
input double           InpMaxCycleExposureLots   = 0.30;
input double           InpStopLossPoints         = 280.0;
input double           InpTakeProfitPoints       = 160.0;

input int              InpMaxSpreadPoints        = 80;
input int              InpMaxSlippagePoints      = 30;
input ulong            InpMagicNumber            = 20260411;
input int              InpSessionStartHour       = 7;
input int              InpSessionEndHour         = 23;
input double           InpMaxDailyLossPercent    = 3.0;

input BiasFilterMode   InpBiasFilter             = BIAS_FILTER_EMA;
input ENUM_TIMEFRAMES  InpBiasTimeframe          = PERIOD_M5;
input int              InpBiasEmaPeriod          = 50;

CTrade   g_trade;
int      g_atr_handle        = INVALID_HANDLE;
int      g_bias_ema_handle   = INVALID_HANDLE;
datetime g_last_cycle_time   = 0;
int      g_day_anchor        = -1;
double   g_day_start_equity  = 0.0;

string TradeSymbol()
  {
   if(StringLen(InpTradeSymbol) > 0)
      return InpTradeSymbol;
   return _Symbol;
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

double NormalizeVolume(const string symbol, double volume)
  {
   if(volume <= 0.0)
      return 0.0;

   double min_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(step <= 0.0)
      step = min_volume;

   volume = MathMax(min_volume, MathMin(max_volume, volume));
   volume = min_volume + MathFloor((volume - min_volume) / step + 1e-8) * step;
   volume = MathMax(min_volume, MathMin(max_volume, volume));

   return NormalizeDouble(volume, VolumeDigits(step));
  }

double PointValuePerLot(const string symbol)
  {
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(tick_value <= 0.0 || tick_size <= 0.0 || point <= 0.0)
      return 0.0;

   return tick_value * point / tick_size;
  }

void ResetDailyAnchorIfNeeded()
  {
   datetime now = TimeCurrent();
   MqlDateTime stamp;
   TimeToStruct(now, stamp);
   int day_key = stamp.year * 10000 + stamp.mon * 100 + stamp.day;

   if(day_key != g_day_anchor)
     {
      g_day_anchor = day_key;
      g_day_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
     }
  }

bool DailyLossLimitHit()
  {
   ResetDailyAnchorIfNeeded();

   if(InpMaxDailyLossPercent <= 0.0 || g_day_start_equity <= 0.0)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown_pct = ((g_day_start_equity - equity) / g_day_start_equity) * 100.0;
   return drawdown_pct >= InpMaxDailyLossPercent;
  }

bool IsTradingWindow()
  {
   if(InpSessionStartHour == InpSessionEndHour)
      return true;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   if(InpSessionStartHour < InpSessionEndHour)
      return (now.hour >= InpSessionStartHour && now.hour < InpSessionEndHour);

   return (now.hour >= InpSessionStartHour || now.hour < InpSessionEndHour);
  }

bool IsCooldownActive()
  {
   if(g_last_cycle_time <= 0 || InpCooldownSeconds <= 0)
      return false;

   return (TimeCurrent() - g_last_cycle_time) < InpCooldownSeconds;
  }

double CurrentSpreadPoints(const string symbol)
  {
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return DBL_MAX;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return DBL_MAX;

   return (tick.ask - tick.bid) / point;
  }

bool SpreadAllowed(const string symbol)
  {
   return CurrentSpreadPoints(symbol) <= InpMaxSpreadPoints;
  }

int CountManagedPositions(const string symbol)
  {
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      count++;
     }

   return count;
  }

bool BuildRangeSnapshot(const string symbol,
                        double &range_low,
                        double &range_high,
                        double &range_mid,
                        double &range_width_points)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(symbol, InpRangeTimeframe, 1, InpRangeLookbackBars, rates);
   if(copied < InpRangeLookbackBars)
      return false;

   range_high = rates[0].high;
   range_low = rates[0].low;

   for(int i = 1; i < copied; ++i)
     {
      if(rates[i].high > range_high)
         range_high = rates[i].high;
      if(rates[i].low < range_low)
         range_low = rates[i].low;
     }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0 || range_high <= range_low)
      return false;

   range_mid = (range_high + range_low) * 0.5;
   range_width_points = (range_high - range_low) / point;
   return true;
  }

double CurrentATRPoints()
  {
   if(g_atr_handle == INVALID_HANDLE)
      return DBL_MAX;

   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);

   if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_buffer) != 1)
      return DBL_MAX;

   double point = SymbolInfoDouble(TradeSymbol(), SYMBOL_POINT);
   if(point <= 0.0)
      return DBL_MAX;

   return atr_buffer[0] / point;
  }

int CurrentBias(const string symbol)
  {
   if(InpBiasFilter == BIAS_FILTER_OFF)
      return 0;

   if(g_bias_ema_handle == INVALID_HANDLE)
      return 0;

   double ema_buffer[];
   ArraySetAsSeries(ema_buffer, true);

   if(CopyBuffer(g_bias_ema_handle, 0, 0, 1, ema_buffer) != 1)
      return 0;

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return 0;

   if(tick.bid > ema_buffer[0])
      return 1;

   if(tick.ask < ema_buffer[0])
      return -1;

   return 0;
  }

bool IsRangeRegime(const double range_width_points, const double atr_points)
  {
   if(range_width_points < InpMinRangeWidthPoints)
      return false;

   if(range_width_points > InpMaxRangeWidthPoints)
      return false;

   if(atr_points > InpMaxATRPoints)
      return false;

   return true;
  }

int EntrySignal(const string symbol,
                const double range_low,
                const double range_high,
                const double range_width_points)
  {
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return 0;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0;

   double edge_distance = range_width_points * InpEdgeZonePercent * point;
   int bias = CurrentBias(symbol);

   if(tick.bid <= range_low + edge_distance)
     {
      if(bias < 0)
         return 0;
      return 1;
     }

   if(tick.ask >= range_high - edge_distance)
     {
      if(bias > 0)
         return 0;
      return -1;
     }

   return 0;
  }

double VolumePerOrder(const string symbol)
  {
   if(InpBurstOrders <= 0)
      return 0.0;

   double volume = InpFixedLotPerOrder;

   if(InpUseRiskPercent)
     {
      double point_value = PointValuePerLot(symbol);
      if(point_value <= 0.0 || InpStopLossPoints <= 0.0)
         return 0.0;

      double cycle_risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercentPerCycle / 100.0);
      double risk_per_order = cycle_risk_money / (double)InpBurstOrders;
      volume = risk_per_order / (InpStopLossPoints * point_value);
     }

   if(InpMaxCycleExposureLots > 0.0)
     {
      double per_order_cap = InpMaxCycleExposureLots / (double)InpBurstOrders;
      volume = MathMin(volume, per_order_cap);
     }

   return NormalizeVolume(symbol, volume);
  }

bool SubmitMarketOrder(const string symbol, const int direction, const double volume, const int order_index)
  {
   if(volume <= 0.0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || digits < 0)
      return false;

   double entry_price = (direction > 0) ? tick.ask : tick.bid;
   double sl = 0.0;
   double tp = 0.0;

   if(InpStopLossPoints > 0.0)
     {
      sl = (direction > 0) ? entry_price - (InpStopLossPoints * point)
                           : entry_price + (InpStopLossPoints * point);
      sl = NormalizeDouble(sl, digits);
     }

   if(InpTakeProfitPoints > 0.0)
     {
      tp = (direction > 0) ? entry_price + (InpTakeProfitPoints * point)
                           : entry_price - (InpTakeProfitPoints * point);
      tp = NormalizeDouble(tp, digits);
     }

   string comment = StringFormat("TraderXBurst#%d", order_index + 1);
   bool ok = false;

   if(direction > 0)
      ok = g_trade.Buy(volume, symbol, 0.0, sl, tp, comment);
   else
      ok = g_trade.Sell(volume, symbol, 0.0, sl, tp, comment);

   if(!ok)
      PrintFormat("Order send failed: retcode=%u order_index=%d volume=%.2f", g_trade.ResultRetcode(), order_index, volume);

   return ok;
  }

bool ExecuteBurst(const string symbol, const int direction)
  {
   if(InpBurstOrders <= 0)
      return false;

   double volume = VolumePerOrder(symbol);
   if(volume <= 0.0)
     {
      Print("Calculated volume is zero; burst skipped.");
      return false;
     }

   int success_count = 0;
   for(int i = 0; i < InpBurstOrders; ++i)
     {
      if(SubmitMarketOrder(symbol, direction, volume, i))
         success_count++;
     }

   if(success_count > 0)
     {
      g_last_cycle_time = TimeCurrent();
      PrintFormat("Burst executed: direction=%d success=%d/%d volume=%.2f", direction, success_count, InpBurstOrders, volume);
      return true;
     }

   return false;
  }

void ManageOpenPositions(const string symbol, const double range_mid, const bool has_range)
  {
   MqlTick tick;
   bool has_tick = SymbolInfoTick(symbol, tick);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      bool should_close = false;
      datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      long position_type = PositionGetInteger(POSITION_TYPE);

      if(InpTimeExitSeconds > 0 && (TimeCurrent() - opened_at) >= InpTimeExitSeconds)
         should_close = true;

      if(InpUseMidlineExit && has_range && has_tick)
        {
         if(position_type == POSITION_TYPE_BUY && tick.bid >= range_mid)
            should_close = true;
         if(position_type == POSITION_TYPE_SELL && tick.ask <= range_mid)
            should_close = true;
        }

      if(should_close && !g_trade.PositionClose(ticket))
         PrintFormat("Position close failed: retcode=%u ticket=%I64u", g_trade.ResultRetcode(), ticket);
     }
  }

int OnInit()
  {
   string symbol = TradeSymbol();

   if(InpRangeLookbackBars < 5 ||
      InpBurstOrders < 1 ||
      InpMinRangeWidthPoints <= 0.0 ||
      InpMaxRangeWidthPoints < InpMinRangeWidthPoints ||
      InpATRPeriod < 2 ||
      InpEdgeZonePercent <= 0.0 ||
      InpEdgeZonePercent >= 0.50 ||
      InpStopLossPoints <= 0.0 ||
      InpTakeProfitPoints < 0.0)
      return INIT_PARAMETERS_INCORRECT;

   if(!SymbolSelect(symbol, true))
      return INIT_FAILED;

   g_trade.SetExpertMagicNumber((long)InpMagicNumber);
   g_trade.SetDeviationInPoints(InpMaxSlippagePoints);
   g_trade.SetTypeFillingBySymbol(symbol);
   g_trade.SetAsyncMode(false);

   g_atr_handle = iATR(symbol, InpRangeTimeframe, InpATRPeriod);
   if(g_atr_handle == INVALID_HANDLE)
      return INIT_FAILED;

   if(InpBiasFilter == BIAS_FILTER_EMA)
     {
      g_bias_ema_handle = iMA(symbol, InpBiasTimeframe, InpBiasEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_bias_ema_handle == INVALID_HANDLE)
         return INIT_FAILED;
     }

   ResetDailyAnchorIfNeeded();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);

   if(g_bias_ema_handle != INVALID_HANDLE)
      IndicatorRelease(g_bias_ema_handle);
  }

void OnTick()
  {
   string symbol = TradeSymbol();

   ResetDailyAnchorIfNeeded();

   double range_low = 0.0;
   double range_high = 0.0;
   double range_mid = 0.0;
   double range_width_points = 0.0;
   bool has_range = BuildRangeSnapshot(symbol, range_low, range_high, range_mid, range_width_points);

   ManageOpenPositions(symbol, range_mid, has_range);

   if(CountManagedPositions(symbol) > 0)
      return;

   if(DailyLossLimitHit())
      return;

   if(!IsTradingWindow())
      return;

   if(IsCooldownActive())
      return;

   if(!SpreadAllowed(symbol))
      return;

   if(!has_range)
      return;

   double atr_points = CurrentATRPoints();
   if(!IsRangeRegime(range_width_points, atr_points))
      return;

   int signal = EntrySignal(symbol, range_low, range_high, range_width_points);
   if(signal == 0)
      return;

   ExecuteBurst(symbol, signal);
  }
