Helpdesk::Classifier.seed(:name) do |s|
  s.name = 'spam'
  s.categories = 'spam ham'
  s.data = nil
end
