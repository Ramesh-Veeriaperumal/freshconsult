class Social::TwitterHandle < ActiveRecord::Base
  DM_THREADTIME = [
    [ :never,    I18n.t('never'),      0 ],
    [ :one,      I18n.t('one'),      3600 ],
    [ :two,      I18n.t('two'),      7200 ],
    [ :four,     I18n.t('four'),     14400 ],
    [ :eight,    I18n.t('eight'),     28800 ],
    [ :twelve,   I18n.t('twelve'),    43200 ],
    [ :day,      I18n.t('day'),      86400 ],
    [ :twoday,   I18n.t('twoday'),     172800 ],
    [ :threeday, I18n.t('threeday'),     259200 ],
    [ :oneweek,  I18n.t('oneweek'),     604800 ]
  ]

  DM_THREADTIME_OPTIONS = DM_THREADTIME.map { |i| [i[1], i[2]] }
  DM_THREADTIME_NAMES_BY_KEY = Hash[*DM_THREADTIME.map { |i| [i[2], i[1]] }.flatten]
  DM_THREADTIME_KEYS_BY_TOKEN = Hash[*DM_THREADTIME.map { |i| [i[0], i[2]] }.flatten]

  TWITTER_STATES = [
    [:active,          "Active Account",           1],
    [:reauth_required, "Reauthorization Required", 2],
    [:disabled,        "Disabled Account",         3]
  ]

  TWITTER_STATE_KEYS_BY_TOKEN = Hash[*TWITTER_STATES.map { |i| [i[0], i[2]] }.flatten]
  TWITTER_NAMES_BY_STATE_KEYS = TWITTER_STATE_KEYS_BY_TOKEN.invert
end
