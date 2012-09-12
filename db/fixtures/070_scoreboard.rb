account = Account.current

ScoreboardRating.seed_many(:account_id, :resolution_speed, [
    [ Gamification::Scoreboard::Constants::FAST_RESOLUTION, 10 ],
    [ Gamification::Scoreboard::Constants::ON_TIME_RESOLUTION, 5 ],
    [ Gamification::Scoreboard::Constants::LATE_RESOLUTION, -5 ],
    [ Gamification::Scoreboard::Constants::FIRST_CALL_RESOLUTION, 5 ],
    [ Gamification::Scoreboard::Constants::HAPPY_CUSTOMER, 10 ],
    [ Gamification::Scoreboard::Constants::UNHAPPY_CUSTOMER, -10 ]
  ].map do |f|
    {
      :account_id => account.id,
      :resolution_speed => f[0],
      :score => f[1]
    }
  end
)

ScoreboardLevel.seed_many(:account_id, :name, :points,  
    ScoreboardLevel::LEVELS_SEED_DATA.map do |level|
    {
      :account_id => account.id,
      :name => level[0],
      :points => level[1]
    }
    end 
)