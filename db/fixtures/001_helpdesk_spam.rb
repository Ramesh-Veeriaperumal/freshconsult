#Wherever this 'unless Account.current' used, it is meant for bootstrapping - 
#whereas others will be executed for account sign-up as well  
unless Account.current
  Helpdesk::Classifier.seed(:name) do |s|
    s.name = 'spam'
    s.categories = 'spam ham'
    s.data = nil
  end
end
