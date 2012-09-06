account = Account.current

ScoreboardRating.seed_many(:account_id, :resolution_speed, [
    [ Scoreboard::Constants::FAST_RESOLUTION, 3 ],
    [ Scoreboard::Constants::ON_TIME_RESOLUTION, 1 ],
    [ Scoreboard::Constants::LATE_RESOLUTION, -1 ],
    [ Scoreboard::Constants::FIRST_CALL_RESOLUTION, 3 ],
    [ Scoreboard::Constants::HAPPY_CUSTOMER, 3 ],
    [ Scoreboard::Constants::UNHAPPY_CUSTOMER, -1 ]
  ].map do |f|
    {
      :account_id => account.id,
      :resolution_speed => f[0],
      :score => f[1]
    }
  end
)

ScoreboardLevel.seed(:account_id) do |s|
  s.account_id = Account.current.id
  s.levels_data = ScoreboardLevel::LEVELS
end