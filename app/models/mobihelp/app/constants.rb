class Mobihelp::App < ActiveRecord::Base

  PLATFORMS = [
    [:android,  "Android"],
    [:ios,      "iOS"]
  ]

  PLATFORM_NAMES_BY_ID = Hash[(1..PLATFORMS.size).zip(PLATFORMS.map{ |p| p[1] })]
  PLATFORM_ID_BY_KEY = Hash[PLATFORMS.map{ |p| p[0]}.zip(1..PLATFORMS.size)]

  DEFAULT_BREADCRUMBS_COUNT = 50
  DEFAULT_LOGS_COUNT = 400
  DEFAULT_APP_REVIEW_LAUNCH_COUNT = 0

  API_VERSIONS = [
    [:v_1, "1", "Default version"],
    [:v_2, "2", "Supports multiple solution categories"]
  ]

  API_VERSIONS_BY_NAME = Hash[API_VERSIONS.map{|v| v[0]}.zip(API_VERSIONS.map{|v| v[1]})]
end