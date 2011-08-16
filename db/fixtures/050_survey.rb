account = Account.current

survey = Survey.seed(:account_id) do |s|
  s.account_id = account.id
  s.link_text = 'Please take a minute to rate your customer support experience'
  s.send_while = Survey::RESOLVED_NOTIFICATION
end

SurveyPoint.seed_many(:survey_id, :resolution_speed, :customer_mood, [
    [ SurveyPoint::FAST_RESOLUTION, SurveyPoint::HAPPY, 5 ],
    [ SurveyPoint::FAST_RESOLUTION, SurveyPoint::NEUTRAL, 3 ],
    [ SurveyPoint::FAST_RESOLUTION, SurveyPoint::UNHAPPY, 0 ],
    [ SurveyPoint::ON_TIME_RESOLUTION, SurveyPoint::HAPPY, 3 ],
    [ SurveyPoint::ON_TIME_RESOLUTION, SurveyPoint::NEUTRAL, 1 ],
    [ SurveyPoint::ON_TIME_RESOLUTION, SurveyPoint::UNHAPPY, -1 ],
    [ SurveyPoint::LATE_RESOLUTION, SurveyPoint::HAPPY, 1 ],
    [ SurveyPoint::LATE_RESOLUTION, SurveyPoint::NEUTRAL, 0 ],
    [ SurveyPoint::LATE_RESOLUTION, SurveyPoint::UNHAPPY, -3 ],
    [ SurveyPoint::REGULAR_EMAIL, SurveyPoint::HAPPY, 5 ],
    [ SurveyPoint::REGULAR_EMAIL, SurveyPoint::NEUTRAL, 3 ],
    [ SurveyPoint::REGULAR_EMAIL, SurveyPoint::UNHAPPY, 0 ]
  ].map do |f|
    {
      :survey_id => survey.id,
      :resolution_speed => f[0],
      :customer_mood => f[1],
      :score => f[2]
    }
  end
)
