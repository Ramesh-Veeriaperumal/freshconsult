require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['account_test_helper.rb'].each {|file| require "#{Rails.root}/test/core/helpers/#{file}"}
require 'sidekiq/testing'
Sidekiq::Testing.fake!
class ContactEnrichmentTest < ActionView::TestCase 
  include UsersHelper
  include AccountTestHelper
  def setup
    @account = Account.first
    create_test_account if @account.nil?
    @account.make_current
  end

  def test_contact_enrichment
     args = { 'email_update' => 'sample@freshdesk.com' }
     clearbit_response = {"person"=>{"id"=>"d54c54ad-40be-4305-8a34-0ab44710b90d", 
     "name"=>{"fullName"=>"Alex MacCaw", "givenName"=>"Alex", "familyName"=>"MacCaw"}, 
     "email"=>"alex@alexmaccaw.com", "location"=>"San Francisco, CA, US", 
     "timeZone"=>"America/Los_Angeles", "utcOffset"=>-8, "geo"=>{"city"=>"San Francisco", 
     "state"=>"California", "stateCode"=>"CA", "country"=>"United States", 
     "countryCode"=>"US", "lat"=>37.7749295, "lng"=>-122.4194155}, "bio"=>
     "OReilly author, software engineer & traveller. Founder of https://clearbit.com",
     "site"=>"http://alexmaccaw.com", "avatar"=>"https://d1ts43dypk8bqh.cloudfront
     .net/v1/avatars/d54c54ad-40be-4305-8a34-0ab44710b90d", "employment"=>{
     "domain"=>"clearbit.com", "name"=>"Clearbit", "title"=>"Founder and CEO", 
     "role"=>"ceo", "seniority"=>"executive"}, "facebook"=>{"handle"=>"amaccaw"}, 
     "github"=>{"handle"=>"maccman", "avatar"=>"https://avatars.githubusercontent.
       com/u/2142?v=2", "company"=>"Clearbit", "blog"=>"http://alexmaccaw.com", 
     "followers"=>2932, "following"=>94}, "twitter"=>{"handle"=>"maccaw", "id"=>
     "2006261", "bio"=>"OReilly author, software engineer & traveller. Founder of 
     https://clearbit.com", "followers"=>15248, "following"=>1711, "location"=>
     "San Francisco", "site"=>"http://alexmaccaw.com", "avatar"=>"https://pbs.twi
     mg.com/profile_images/1826201101/297606_10150904890650705_570400704_21211347
     _1883468370_n.jpeg"}, "linkedin"=>{"handle"=>"pub/alex-maccaw/78/929/ab5"}, 
     "googleplus"=>{"handle"=>nil}, "gravatar"=>{"handle"=>"maccman", "urls"=>[{
     "value"=>"http://alexmaccaw.com", "title"=>"Personal Website"}], "avatar"=>
     "http://2.gravatar.com/avatar/994909da96d3afaf4daaf54973914b64", "avatars"=>
     [{"url"=>"http://2.gravatar.com/avatar/994909da96d3afaf4daaf54973914b64", 
       "type"=>"thumbnail"}]}, "fuzzy"=>false, "emailProvider"=>false, 
       "indexedAt" =>"2016-11-07T00:00:00.000Z"}, "company"=>{"id"=>"3f5d6a4e-c284
     -4f78-bfdf-7669b45af907", "name"=>"Uber", "legalName"=>"Uber Technologies, Inc.", 
     "domain"=>"uber.com", "domainAliases"=>["uber.org", "ubercab.com"], "site"=>
     {"phoneNumbers"=>[], "emailAddresses"=>["domains@uber.com"]}, "category"=>
     {"sector"=>"Information Technology", "industryGroup"=>"Software & Services", 
     "industry"=>"Internet Software & Services", "subIndustry"=>"Internet Software 
     & Services", "sicCode"=>"47", "naicsCode"=>"51"}, "tags"=>["Technology", 
     "Marketplace", "Mobile", "B2C", "Ground Transportation", "Transportation", 
     "Internet"], "description"=>"Get a taxi, private car or rideshare from your 
     mobile phone. Uber connects you with a driver in minutes. Use our app in cities 
     around the world.", "foundedYear"=>2009, "location"=>"1455 Market St, San 
     Francisco, CA 94103, USA", "timeZone"=>"America/Los_Angeles", "utcOffset"=>-7, 
     "geo"=>{"streetNumber"=>"1455", "streetName"=>"Market Street", "subPremise"=>nil, 
     "city"=>"San Francisco", "postalCode"=>"94103", "state"=>"California", 
     "stateCode"=>"CA", "country"=>"United States", "countryCode"=>"US", 
     "lat"=>37.7752315, "lng"=>-122.4175278}, "logo"=>"https://logo.clearbit.com/uber.com", 
     "facebook"=>{"handle"=>"uber"}, "linkedin"=>{"handle"=>"company/uber-com"}, 
     "twitter"=>{"handle"=>"Uber", "id"=>"19103481", "bio"=>"Evolving the way the 
     world moves by seamlessly connecting riders to drivers through our app. Question, 
     concern, or praise? Tweet at @Uber_Support.", "followers"=>570351, "following"=>377, 
     "location"=>"Global", "site"=>"http://t.co/11eIV5LX3Z", "avatar"=>"https://
     pbs.twimg.com/profile_images/697242369154940928/p9jxYqy5_normal.png"}, 
     "crunchbase"=>{"handle"=>"organization/uber"}, "emailProvider"=>false, 
     "type"=>"private", "ticker"=>nil, "identifiers"=>{"usEIN"=>"452647441"}, 
     "phone"=>nil, "indexedAt"=>"2016-11-07T00:00:00.000Z", "metrics"=>{
     "alexaUsRank"=>544, "alexaGlobalRank"=>943, "employees"=>20313, 
     "employeesRange"=>"10k-50k", "marketCap"=>nil, "raised"=>10610000000, 
     "annualRevenue"=>nil, "estimatedAnnualRevenue"=>"$1B-$10B", "fiscalYearEnd"=>12}, 
     "tech"=>["google_analytics", "double_click", "mixpanel", "optimizely", 
     "typekit_by_adobe", "android", "nginx", "ios", "mixpanel", "google_apps"], 
     "parent"=>{"domain"=>nil}}}
     expected_contact_info = {:first_name=>"Alex", :last_name=>"MacCaw", :email=>
     "sample@freshdesk.com", :full_name=>"Alex MacCaw", :email_provider=>"false", 
     :country=>"United States", :time_zone=>"America/Los_Angeles", 
     :employment_name=>"Clearbit", :job_title=>"Founder and CEO", :twitter=>"maccaw", 
     :facebook=>"amaccaw", :linkedin=>"pub/alex-maccaw/78/929/ab5"}
     Clearbit::Enrichment.stubs(:find).returns(clearbit_response)
     value = ContactEnrichment.new.perform(args)
     Account.current.reload
     assert_equal value, true
     assert_equal Account.current.account_configuration.contact_info, expected_contact_info
  end

  def test_contact_enrichment_with_error_in_contact_info
     assert_nothing_raised do
       ContactEnrichment.any_instance.stubs(:generate_clearbit_contact_info).raises(StandardError)
       ContactEnrichment.new.perform
     end
   ensure
     ContactEnrichment.unstub(:generate_clearbit_contact_info)
   end
 
   def test_contact_enrichment_without_email_update
     assert_nothing_raised do
       args = { 'email_update' => nil }
       Account.current.contact_info[:email] = ' '
       ContactEnrichment.new.perform(args)
     end
   end
 end
