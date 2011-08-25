class ScoreboardRating < ActiveRecord::Base
  
  #resolution speed
  FAST_RESOLUTION = 1
  ON_TIME_RESOLUTION = 2
  LATE_RESOLUTION = 3
  HAPPY_CUSTOMER = 4
  
  belongs_to :account
end
