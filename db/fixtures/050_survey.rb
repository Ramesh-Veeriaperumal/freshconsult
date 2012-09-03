account = Account.current

Survey.seed(:account_id) do |s|
  s.account_id = account.id
  s.link_text = 'Please let us know your opinion on our support experience.'
  s.send_while = Survey::RESOLVED_NOTIFICATION
end

ScoreboardRating.seed_many(:account_id, :resolution_speed, [
    [ ScoreboardRating::FAST_RESOLUTION, 3 ],
    [ ScoreboardRating::ON_TIME_RESOLUTION, 1 ],
    [ ScoreboardRating::LATE_RESOLUTION, -1 ],
    [ ScoreboardRating::FIRST_CALL_RESOLUTION, 3 ],
    [ ScoreboardRating::HAPPY_CUSTOMER, 3 ],
    [ ScoreboardRating::UNHAPPY_CUSTOMER, -1 ]
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
