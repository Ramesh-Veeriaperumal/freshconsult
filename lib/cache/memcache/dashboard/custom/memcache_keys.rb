module Cache::Memcache::Dashboard::Custom::MemcacheKeys
  
  CUSTOM_DASHBOARD_WIDGETS                        = 'v1/custom/CUSTOM_DASHBOARD_WIDGETS:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_SCORECARDS                     = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:0'
  CUSTOM_DASHBOARD_BAR_CHARTS                     = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:1'
  CUSTOM_DASHBOARD_CSATS                          = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:2'
  CUSTOM_DASHBOARD_LEADERBOARDS                   = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:3'
  CUSTOM_DASHBOARD_FORUM_MODERATIONS              = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:4'
  CUSTOM_DASHBOARD_TICKET_TREND_CARDS             = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:5'
  CUSTOM_DASHBOARD_TIME_TREND_CARDS               = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:6'
  CUSTOM_DASHBOARD_SLA_TREND_CARDS                = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:7'
  CUSTOM_DASHBOARD_MS_SCORECARDS                  = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:11'.freeze
  CUSTOM_DASHBOARD_MS_BAR_CHARTS                  = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:12'.freeze
  CUSTOM_DASHBOARD_MS_AVAILABILITYS               = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:13'.freeze
  CUSTOM_DASHBOARD_MS_CSATS                       = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:14'.freeze
  CUSTOM_DASHBOARD_MS_TIME_TRENDS                 = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:16'.freeze
  CUSTOM_DASHBOARD_MS_SLA_TRENDS                  = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:17'.freeze
  CUSTOM_DASHBOARD_MS_CALL_TRENDS                 = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:18'.freeze
  
  CUSTOM_DASHBOARD                                = 'v1/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_TICKET_FILTERS                 = 'v1/CUSTOM_DASHBOARD_TICKET_FILTERS:%{account_id}:%{dashboard_id}'

  CUSTOM_DASHBOARD_SCORECARD_DATA                 = 'v1/CUSTOM_DASHBOARD:SCORECARD_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_BAR_CHART_DATA                 = 'v1/CUSTOM_DASHBOARD:BAR_CHART_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_CSAT_DATA                      = 'v1/CUSTOM_DASHBOARD:CSAT_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_LEADERBOARD_DATA               = 'v1/CUSTOM_DASHBOARD:LEADERBOARD_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_FORUM_MODERATION_DATA          = 'v1/CUSTOM_DASHBOARD:FORUM_MODERATION_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_TICKET_TREND_CARD_DATA         = 'v1/CUSTOM_DASHBOARD:TICKET_TREND_CARD_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_TIME_TREND_CARD_DATA           = 'v1/CUSTOM_DASHBOARD:TIME_TREND_CARD_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_SLA_TREND_CARD_DATA            = 'v1/CUSTOM_DASHBOARD:SLA_TREND_CARD_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_MS_SCORECARD_DATA              = 'v1/CUSTOM_DASHBOARD:MS_SCORECARD_DATA:%{account_id}:%{dashboard_id}'.freeze
  CUSTOM_DASHBOARD_MS_BAR_CHART_DATA              = 'v1/CUSTOM_DASHBOARD:MS_BAR_CHART_DATA:%{account_id}:%{dashboard_id}'.freeze
  CUSTOM_DASHBOARD_MS_AVAILABILITY_DATA           = 'v1/CUSTOM_DASHBOARD:MS_AVAILABILITY_DATA:%{account_id}:%{dashboard_id}'.freeze
  CUSTOM_DASHBOARD_MS_CSAT_DATA                   = 'v1/CUSTOM_DASHBOARD:MS_CSAT_DATA:%{account_id}:%{dashboard_id}'.freeze
  CUSTOM_DASHBOARD_MS_TIME_TREND_DATA             = 'v1/CUSTOM_DASHBOARD:MS_TIME_TREND_DATA:%{account_id}:%{dashboard_id}'.freeze
  CUSTOM_DASHBOARD_MS_SLA_TREND_DATA              = 'v1/CUSTOM_DASHBOARD:MS_SLA_TREND_DATA:%{account_id}:%{dashboard_id}'.freeze
  CUSTOM_DASHBOARD_MS_CALL_TREND_DATA             = 'v1/CUSTOM_DASHBOARD:MS_CALL_TREND_DATA:%{account_id}:%{dashboard_id}'.freeze
end
