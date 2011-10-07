account = Account.current

Survey.seed(:account_id) do |s|
  s.account_id = account.id
  s.link_text = 'Please take a minute to rate your customer support experience'
  s.send_while = Survey::RESOLVED_NOTIFICATION
end

ScoreboardRating.seed_many(:account_id, :resolution_speed, [
    [ ScoreboardRating::FAST_RESOLUTION, 3 ],
    [ ScoreboardRating::ON_TIME_RESOLUTION, 1 ],
    [ ScoreboardRating::LATE_RESOLUTION, -1 ],
    [ ScoreboardRating::HAPPY_CUSTOMER, 3 ]
  ].map do |f|
    {
      :account_id => account.id,
      :resolution_speed => f[0],
      :score => f[1]
    }
  end  
)
