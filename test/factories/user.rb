Factory.define :user do |f|
  f.sequence(:name) { |n| "foo#{n}" } 
  f.password "foobar"
  f.password_confirmation { |u| u.password }
  f.sequence(:email) { |n| "foo#{n}@example.com" }
  f.time_zone 'Chennai'
  f.language 'en'
  f.association :customer, :factory => :customer
  f.active 1
end

Factory.define :poweruser, :parent => :user do |u|
  u.user_role 2
  u.association :customer, :factory => :article_customer
end

Factory.define :poweruser_1, :parent => :user do |u|
  u.user_role 2
  u.association :customer, :factory => :article_customer_1
end


Factory.define :admin, :parent => :user do |u|
  u.user_role 1
  u.account_id 1
  u.after_create { |l| Factory(:all_ticket_permission, :user => l)  }
end

Factory.define :account_admin, :parent => :user do |u|
  u.user_role 4
  u.after_create { |l| Factory(:all_ticket_permission, :user => l)  }
end