if ENV["RAILS_ENV"] == "test"
Factory.define :group do |g|
  g.name "group1"
  g.description "test group one"
end

Factory.define :ticket, :class => Helpdesk::Ticket do |t|
  t.description "test ticket"
  t.status 2
  t.urgent 0
  t.deleted 0
  t.to_email "test@testind.com"
  t.ticket_type "Question"
  t.description_html "<div>This is a sample ticket, feel free to delete it.</div>"
  t.display_id 1
  t.trained 0
  t.isescalated 0
  t.priority 1
  t.subject "sample ticket creation"
end

Factory.define :agent do |a|
  a.signature "Regards, agent1"
  a.available 1
end
  
Factory.define :portal_template, :class => Portal::Template do |p|
  p.preferences "something"
end

def create_subscriptions
    SubscriptionPlan.seed_many(:name, [
      { :name => 'Sprout', :amount => 15, :free_agents => 3, :day_pass_amount => 1.00 },
      { :name => 'Blossom', :amount => 19, :free_agents => 0, :day_pass_amount => 2.00 },
      { :name => 'Garden', :amount => 29, :free_agents => 0, :day_pass_amount => 2.00 },
      { :name => 'Estate', :amount => 49, :free_agents => 0, :day_pass_amount => 4.00 }
    ])
end

Factory.define :account do |p|
  create_subscriptions
  p.sequence(:name) { |n| "foo#{n}" }
  p.sequence(:full_domain) { |n| "foo#{n}.freshdesk.com" }
  p.time_zone "Chennai"
  p.sequence(:shared_secret) { |n| "f8c5eb47e87#{n}5f4ffcc19561503fa8d2" }
  p.sequence(:domain) { |n| "foo#{n}" }
  p.plan SubscriptionPlan.find_by_name("Estate")
end

Factory.define :primary_email_config, :class => EmailConfig do |p|
 p.sequence(:to_email) { |n| "support@foo#{n}.freshdesk.com" }
 p.sequence(:reply_email) { |n| "support@foo#{n}.freshdesk.com" }
 p.sequence(:name) { |n| "foo#{n}" }
 p.primary_role true
end

Factory.define :main_portal, :class => Portal do |p|
  default_preferences =  HashWithIndifferentAccess.new({:bg_color => "#efefef",:header_color => "#252525", :tab_color => "#006063"})
  locale =  I18n.default_locale
  p.sequence(:name) { |n| "foo#{n}" }
  p.language locale.to_s
  p.preferences default_preferences
  p.main_portal true
end

Factory.define :user do |f|
  f.sequence(:name) { |n| "foo#{n}" }
  f.sequence(:email) { |n| "venky#{n}@freshdesk.com" }
  f.time_zone "Chennai"
  f.active 1
  f.user_role 1
  f.crypted_password "8e24071f6bb54583777852f7a11ba7d4b41317629c8c07af44cf96a8562810a69fd660250821acac3e37f5cb286ae6c52e2fadac96035ade19bcb2f02771cf73"
  f.single_access_token "xtoQaHDQ7TtTLQ5OKt1"
  f.persistence_token "cf2e1c6adcad74585f3a9004b911da05c38dcbb2c6dacdfb326d9659aaada194308988bd93d8d398d3694c1b5b0f3197be49f03b696cf2d6b299356daafb3199"
  f.delta 1
  f.language "en"
end


Factory.define :subscription do |f|
  f.amount 49.00
end

Factory.define :freshfone_call, :class => Freshfone::Call do |f|
	f.call_sid "CA5129fa990bff042e3e83cdd8a53832ef"
	f.call_duration "59"
	f.recording_url
	f.call_status 1
	f.call_type 1
	f.customer_data HashWithIndifferentAccess.new({ :number => "+16617480240",:country => 'US',:state => 'CA',:city => 'BAKERSFIELD' })
	f.dial_call_sid "CA0e2ea89440bf032722ee2b09af410a3e"
	f.customer_number "+16617480240"
end

Factory.define :freshfone_account, :class => Freshfone::Account do |f|
	f.twilio_subaccount_id "AC7368db9093a016b0d4e92b1af6453107"
	f.twilio_subaccount_token "1657afcd82d749ca560fd5c0fdfe726e"
	f.twilio_application_id "AP7ebabc7868714420960a2dc8da9de95e"
end

Factory.define :freshfone_number, :class => Freshfone::Number do |f|
	f.number "+17274780266"
	f.region  "Pennsylvania"
	f.country "US"
	f.number_type 1
	f.queue_wait_time 2
	f.max_queue_length 3
end

end

