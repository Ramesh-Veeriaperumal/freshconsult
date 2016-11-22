# source :gemcutter
Encoding.default_external = Encoding::UTF_8
source 'https://rubygems.org'

gem "rake", "~> 10.4.0"
gem "rails","3.2.22.3"

gem "freemail", "0.2.0", :require => false 

gem 'rack-cors', '~> 0.3.1'
gem "syck",'1.0.5'

gem "json", "1.8.3"
gem 'jbuilder', "2.2.13"
gem 'strong_parameters', "0.2.3" # Used for API params validation

gem "mysql2", "~> 0.3.0"

gem "rate-limiting", :git =>"git://github.com/freshdesk/rate-limiting.git"
gem 'fd_rate_limiter', :git => 'git@github.com:freshdesk/fd_rate_limiter.git', :branch => 'dynamic_rules'
gem "white_list", :git =>"git://github.com/neubloc/white_list.git"
gem "will_paginate", "3.0.6"
gem "country_select", :git => "git://github.com/stefanpenner/country_select", :tag => 'v1.1.2'
gem "activemerchant", :git => "git://github.com/Shopify/active_merchant", :tag => 'v1.43.1'
# Please do not update acts_as_list unless this issue is resolved https://github.com/swanandp/acts_as_list/issues/137
gem "acts_as_list", "0.1.4"
gem "prototype-rails", '~> 3.2.0'
gem "dynamic_form"
gem "prototype_legacy_helper", '0.0.0', :git => "git://github.com/rails/prototype_legacy_helper.git"
gem 'rack-ssl', :require => 'rack/ssl', :git => 'git://github.com/freshdesk/rack-ssl',:branch => 'ssl'
gem "rack-cache", "~> 1.2"
gem "statsd-ruby", :git => 'git://github.com/sumakumardey/statsd-ruby', :branch =>'custom_stats', :require => 'statsd'

gem 'sneaky-save', :git => 'git://github.com/partyearth/sneaky-save.git'
gem 'fresh_request', :git => 'git@github.com:freshdesk/fresh_request.git', :branch => 'v10'

#for ruby ~> 2.1.0 upgrade
gem 'iconv', '~> 1.0.4'
gem 'thrift', '~> 0.9.2.0'
gem 'charlock_holmes', "0.7.3"

group :development, :test do
  gem 'rails-dev-boost', :git => 'git://github.com/thedarkone/rails-dev-boost.git'
  gem 'better_errors', '~> 1.1.0'
  # Commenting out for ruby ~> 2.1.0 upgrade
  # gem "debugger", "~> 1.6.8"
  gem 'pry'
  gem 'pry-byebug'
  gem 'pry-nav'
  gem 'binding_of_caller'
  gem 'meta_request'
  gem 'fake_sqs'
  gem 'fake_dynamo'
end

gem "rack-mini-profiler", :group => [:development]
gem "brakeman", :require => false, :group => [:development]
gem "bullet", :group => [:development, :test, :staging]
gem "mail"
gem "i18n", "~> 0.6.0"
gem "i18n-js", "3.0.0.rc11"
gem "RedCloth", "4.2.9"
gem "authlogic", "~> 3.4.2"
gem "request_store", "~> 1.0"
gem "httparty", "0.10.0"
gem "omniauth", "1.2.2"
gem "omniauth-oauth", "1.1.0"
gem "oauth", "0.4.5"
gem "tzinfo", "~> 0.3.29"
gem 'rails_autolink', '1.1.6'

gem "omniauth-oauth2", "1.0"
gem "omniauth-openid", "1.0.1"
# TODO-RAILS3 need check are we still using this
gem "omniauth-google", "1.0.2"
gem "omniauth-google-oauth2", "0.1.13"
gem "omniauth-facebook", "1.2.0"
gem "omniauth-quickbooks", "0.0.2"
gem "omniauth-salesforce", :git => "git://github.com/sathishfreshdesk/omniauth-salesforce.git", :branch => "master"
gem "omniauth-mailchimp", "1.0.3"
gem "omniauth-constantcontact2", "1.0.4"

gem "dynamics_crm", :git => 'git@github.com:TinderBox/dynamics_crm.git', :branch => "master"
gem "google-api-client", "~> 0.7.0"
gem "ipaddress", "0.8.0"

gem 'sidekiq', "3.4.1"
# This needs bundler 1.7.2 or 1.10.6 as other version has problem in resolving.
source "https://690a8c5e:5d9334f0@gems.contribsys.com/" do
  gem 'sidekiq-pro' 
end 
gem 'shoryuken', '2.0.4'

gem "soap4r-ruby1.9", "~> 2.0.5"
gem "jira4r", "0.3.0"
gem "ruby-openid", :git => "git://github.com/freshdesk/ruby-openid.git", :require => "openid"
gem "ruby-openid-apps-discovery", "1.2.0"
gem "twilio-ruby", :git => "git://github.com/freshdesk/twilio-ruby.git", :branch => "master"
gem "carmen", :git => "git://github.com/jim/carmen.git", :tag => "ruby-18"
gem 'postoffice', :git => "git://github.com/chrisbutcher/postoffice.git", :branch => "master"

gem "ruby-saml", "0.8.1"

gem 'xeroizer', :git => "git@github.com:freshdesk/xeroizer.git"
gem "rubyzip", "0.9.4" , :require => "zip/zip"
gem "riak-client", "1.4.2"

gem "http_accept_language", "~> 2.0.1"

gem "riddle", "1.2.2"

gem "braintree","2.10.0"
gem "lockfile","1.4.3"

gem "newrelic_rpm","3.9.9.275"

gem "faraday" , "0.9"
gem 'faraday_middleware', '~> 0.10.0'
gem "twitter", "~> 5.16.0"
gem "gnip-rule", "0.4.1"
gem "curb", "~> 0.8.5"
gem "sanitize", "2.0.3"
gem "koala", "1.10.1"
gem "spreadsheet", "0.6.8"

gem "sax-machine", "~> 0.1.0"

gem "insensitive_hash", "0.2.3"

gem "redis","3.0.7"
gem "resque","~> 1.24.0"
gem "resque-status", "0.4.1"
gem 'resque-scheduler', "2.2.0", :require => 'resque_scheduler'

gem 'marketo', :git => "git://github.com/freshdesk/Marketo.git"
gem 'rforce'


gem 'chargebee', "~> 1.5.1"

gem 'encryptor', '1.1.3'
gem "dalli", :git => "git://github.com/freshdesk/dalli.git", :branch => "fd_master"
#gem 'memcache-client', '1.8.5', :git => "git://github.com/mperham/memcache-client.git"
gem "deadlock_retry", :git => "git://github.com/freshdesk/deadlock_retry.git"
gem "lhm", :git => "git://github.com/freshdesk/large-hadron-migrator.git"
gem "rinku", :git => "git://github.com/freshdesk/rinku.git"

gem "namae", '0.8.4'
gem 'ancestry', '1.3'
gem 'rubytree'
gem 'global_phone'
# gem "global_phone_dbgen", "~> 1.0.0"
gem "useragent", "~> 0.16.3"

gem 'active_record_shards', '~> 3.2.0', :require => 'active_record_shards'
gem "rack-throttle", "~> 0.3.0"
gem "omniauth-box2", '~> 0.0.1'
gem "static_model", "~> 1.0.4"

gem 'clockwork', '0.4.1'
gem 'wkhtmltopdf-binary', :git => "git://github.com/freshdesk/wkhtmltopdf_binary_gem.git"
gem "wicked_pdf", "~> 0.9.10"
gem "pg"
gem "routing-filter", "~> 0.3.1"
gem "gemoji-parser", "~> 1.3.1"

# TODO-RAILS3 need to change the assets to rails3 way
# gem "cloudfront_asset_host", github: "freshdesk/cloudfront_asset_host", branch: :rails3upgrade

# Please do not update Paperclip unless you can get it Monkey Patched for Imagemagick DoS Bug.
# Please see https://hackerone.com/reports/390 
gem "paperclip", "~> 2.8.0"

gem "aws-sdk", "~> 1.31.3"
gem "aws-sdk-resources", '~> 2'
gem "xml-simple", "1.1.4", :require => 'xmlsimple'


gem "therubyracer"
gem "premailer", "~> 1.8.0"

# Email Related Gems
gem 'html_to_plain_text', '1.0.5'
gem "akismetor", :git => "git://github.com/freshdesk/akismetor.git"
gem 'launchparty', :git => 'git@github.com:freshdesk/launch-party.git', :tag => 'v0.1.2'
gem 'binarize', "0.1.1", :git => 'git@github.com:freshdesk/binarize.git', :branch => 'master'


gem "bunny", "1.7.0"

gem "add_pod_support", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/add_pod_support-0.0.1"
gem "custom_fields", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/custom_fields-0.1"

gem "jwt", "1.5.4"

group :production, :test, :staging do
  gem "tire", :git => "git@github.com:freshdesk/retire.git"
end



gem "freshdesk_authority", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/freshdesk_authority-0.1"
gem "delayed_job", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/delayed_job"
gem "active_presenter", :git => "git://github.com/jorgevaldivia/active_presenter.git"
gem "facebook", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/facebook"
gem "acts_as_voteable", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/acts_as_voteable"
gem "ar_shards", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/ar_shards"
gem "text_data_store", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/text_data_store"
gem "xss", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/xss"
gem "has_no_table", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/has_no_table"
gem "features", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/zendesk-features-1.0.2"
gem "log_filter", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/log_filter"
gem "gnip", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/gnip"
gem "dev_notification", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/dev_notification"
gem "sharding", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/sharding"
gem "recaptcha", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/recaptcha"
gem "sentient_user", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/sentient_user"
gem "business_time", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/business_time"
gem "paperclip_ext", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/paperclip_ext"
gem "ssl_requirement", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/ssl_requirement"
gem "helpdesk_attachable", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/helpdesk_attachable"
gem "has_flexiblefields", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/has_flexiblefields"
gem "liquid", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/liquid"
gem "seed-fu", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/seed-fu"
gem "highcharts-rails", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/highcharts-rails"
gem "will_paginate-liquidized", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/will_paginate-liquidized"
gem "will_filter", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/will_filter"
gem "rack-openid", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/rack-openid"
gem "open_id_authentication", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/open_id_authentication"
gem "ebayr", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/ebayr"


group :development, :test do
  gem "forgery","0.5.0"
  gem 'factory_girl_rails', '4.4.0'
  gem 'webrick', '1.3.1'
  gem 'jasmine'
end

group :test do
  gem "rspec", '~> 3.0.0'
  gem "rspec-rails", '~> 3.0.0'
  gem "spork", "~> 0.9.0"
  gem "mocha", "~> 0.13.0", :require => false
  gem 'rspec-collection_matchers', '1.0.0'
  gem 'rack-test', '~> 0.6.2'
  gem "rr", "~> 1.1.0"
  gem "ZenTest", "4.4.1"
  gem "autotest-fsevent", "0.1.1"
  gem "autotest-growl", "0.2.0"
  gem "autotest-rails", "4.1.0"
  gem "faker", "~> 1.4.3"
  gem "simplecov", "~> 0.7.1"
  gem "simplecov-csv"
  gem "database_cleaner"
  gem "fuubar"
  gem "json-compare", "0.1.8"
  gem "rspec_junit_formatter" # Used by API
  gem "simplecov-rcov" 
  gem "rubocop-checkstyle_formatter" # Used by API
  gem "minitest-rails", "1.0.1" # Used by API
  gem "minitest-reporters", "0.14.24" # Used by API
  gem "minitest", "4.7.5"
  gem 'json_expressions' # Used by API
  gem "timecop" # Used by API
end

#ruby 2.2.3 expects tesst-unit to be available by default.
#http://stackoverflow.com/questions/28252036/how-to-run-existing-test-code-on-ruby-2-2
  gem 'test-unit', '3.1.7'
  gem 'test-unit-minitest'

# group :development, :assets do

  # TODO_RAILS3 Remove the default asset pipeline
  gem "jammit",         "0.6.5"
  gem "uglifier",         "~> 2.1.2"
  gem "yui-compressor",     :git => "git://github.com/freshdesk/ruby-yui-compressor.git"

  gem "sprockets",              "2.2.2"
  gem "asset_sync",             "1.1.0"
  gem "turbo-sprockets-rails3", "0.3.14"  
  gem "ejs",                    "1.1.1"

  # SASS and Compass gems
  gem "sass-rails",             "3.2.6"
  gem "compass-rails",          "2.0.0"
  gem "compass-blueprint",      "1.0.0"

  # Portal grid system is done using susy grids
  gem "susy",                   "2.1.3"

  # To optimize sprite generation
  gem "oily_png",               "1.1.1"
  
  # Building custom font icons inside the application
  gem "fontcustom",             "1.3.3"  

# end

# Marketplace
gem 'doorkeeper', '2.2.1'

# Search v2
gem 'typhoeus'

gem 'i18nema', :git => 'https://github.com/freshdesk/i18nema', :require => false

# For debugging app in staging/production
gem 'rbtrace', :require => false
