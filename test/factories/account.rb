Factory.define :account do |p|
  p.association :user, :factory => :account_admin
  p.occasional 0
  p.ticket_permission 1
end