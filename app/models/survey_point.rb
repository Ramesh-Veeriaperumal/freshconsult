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
  
  CUSTOMER_RATINGS = {
    HAPPY => 'happy',
    NEUTRAL => 'neutral',
    UNHAPPY => 'unhappy'
  }
  
  CUSTOMER_RATINGS_BY_TOKEN = CUSTOMER_RATINGS.invert
  
  belongs_to :survey
end
