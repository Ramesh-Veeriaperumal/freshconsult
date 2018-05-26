module Cache::Memcache::Dashboard::Custom::MemcacheKeys
  
  CUSTOM_DASHBOARD_WIDGETS                        = 'v1/custom/CUSTOM_DASHBOARD_WIDGETS:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_SCORECARDS                     = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:0'
  CUSTOM_DASHBOARD_BAR_CHARTS                     = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:1'
  CUSTOM_DASHBOARD_CSATS                          = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:2'
  CUSTOM_DASHBOARD_LEADERBOARDS                   = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:3'
  CUSTOM_DASHBOARD_FORUM_MODERATIONS              = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:4'
  CUSTOM_DASHBOARD_TREND_CARDS					          = 'v1/custom/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}:5'
  
  CUSTOM_DASHBOARD                                = 'v1/CUSTOM_DASHBOARD:%{account_id}:%{dashboard_id}'

  CUSTOM_DASHBOARD_SCORECARD_DATA                 = 'v1/CUSTOM_DASHBOARD:SCORECARD_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_BAR_CHART_DATA                 = 'v1/CUSTOM_DASHBOARD:BAR_CHART_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_CSAT_DATA                 	    = 'v1/CUSTOM_DASHBOARD:CSAT_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_LEADERBOARD_DATA               = 'v1/CUSTOM_DASHBOARD:LEADERBOARD_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_FORUM_MODERATION_DATA          = 'v1/CUSTOM_DASHBOARD:FORUM_MODERATION_DATA:%{account_id}:%{dashboard_id}'
  CUSTOM_DASHBOARD_TREND_CARD_DATA                = 'v1/CUSTOM_DASHBOARD:TREND_CARD_DATA:%{account_id}:%{dashboard_id}'
end
