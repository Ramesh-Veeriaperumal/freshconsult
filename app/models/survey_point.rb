class SurveyPoint < ActiveRecord::Base
  #response speed
  FAST_RESOLUTION = 1
  ON_TIME_RESOLUTION = 2
  LATE_RESOLUTION = 3
  REGULAR_EMAIL = 4
  
  #customer feedback/mode
  HAPPY = 1
  NEUTRAL = 2
  UNHAPPY = 3
  
  belongs_to :survey
end
