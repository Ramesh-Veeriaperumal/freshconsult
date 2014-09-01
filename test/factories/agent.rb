Factory.define :agent do |p|
  p.association :user, :factory => :account_admin
  p.occasional 0
  p.ticket_permission 1
end


Factory.define :all_ticket_permission, :class => Agent do |p|
  p.occasional 0
  p.ticket_permission 1
end