module Helpdesk::Email::OutgoingCategory
  CATEGORIES = [
    [:trial,      1],
    [:active,     2],
    [:premium,    3],
    [:free,       4],
    [:default,    5]  
  ]
  
  CATEGORY_BY_TYPE = Hash[*CATEGORIES.flatten]
  CATEGORY_SET = CATEGORIES.map{|a| a[0]}
  
  def get_subscription
    state = "premium" if Account.current.premium_email? 
    state ||= Account.current.subscription.state 
    state = "default" if !CATEGORY_SET.include?(state.to_sym)
    return state
  end

  def get_category_id
    key = get_subscription
    CATEGORY_BY_TYPE[key.to_sym]
  end
end