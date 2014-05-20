class Mobihelp::App < ActiveRecord::Base

  PLATFORMS = [
    [:android,  "Android"],
    [:ios,      "iOS"]
  ]

  PLATFORM_NAMES_BY_ID = Hash[(1..PLATFORMS.size).zip(PLATFORMS.map{ |p| p[1] })]
  PLATFORM_ID_BY_KEY = Hash[PLATFORMS.map{ |p| p[0]}.zip(1..PLATFORMS.size)]

  CONFIGURATIONS = {
    :bread_crumbs => ["10", "15", "20", "50", "90", "100"],
    :debug_log_count => ["50", "100", "150", "200"],
    :app_review_launches => ["0", "10", "20", "30", "40"]
  }
  
  DEFAULT_BREADCRUMBS_COUNT = CONFIGURATIONS[:bread_crumbs][0]
  DEFAULT_LOGS_COUNT = CONFIGURATIONS[:debug_log_count][0]
  DEFAULT_APP_REVIEW_LAUNCH_COUNT = CONFIGURATIONS[:app_review_launches][0]

end