class PopulateScoreboardData < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      account.scoreboard_ratings.create(
      [
        { :resolution_speed => ScoreboardRating::FAST_RESOLUTION, :score => 3 },
        { :resolution_speed => ScoreboardRating::ON_TIME_RESOLUTION, :score => 1 },
        { :resolution_speed => ScoreboardRating::LATE_RESOLUTION, :score => -1 },
        { :resolution_speed => ScoreboardRating::HAPPY_CUSTOMER, :score => 3 }
      ])
    end
  end

  def self.down
  end
end
