# source :gemcutter
source 'http://rubygems.org'

gem "rake", "0.8.7"
gem "rack", "~> 1.1.6"
gem "rails","2.3.18"

gem "json", "~> 1.8"
gem "json-compare", "0.1.8"

gem "mysql2", "0.2.18"

gem "rate-limiting", :git =>"git://github.com/freshdesk/rate-limiting.git"
gem "white_list", :git =>"git://github.com/neubloc/white_list.git"
gem "will_paginate", "~> 2.3.16"
gem "country_select", :git => "git://github.com/stefanpenner/country_select", :tag => 'v1.1.2'
gem "activemerchant", :git => "git://github.com/Shopify/active_merchant", :tag => 'v1.7.0'
gem "acts_as_list", "0.1.4"
gem 'rack-ssl', :require => 'rack/ssl', :git => 'git://github.com/sumakumardey/rack-ssl',:branch => 'ssl'
gem "statsd-ruby", :git => 'git://github.com/sumakumardey/statsd-ruby', :branch =>'custom_stats', :require => 'statsd'

group :development do
  gem 'rails-dev-boost', :git => 'git://github.com/thedarkone/rails-dev-boost.git', :branch => "rails-2-3"
end

gem "mail"
gem "i18n", "0.4.2"
gem "RedCloth", "4.2.9"
gem "authlogic", "2.1.6"
gem "httparty", "0.10.0"
gem "omniauth", "1.0"
gem "omniauth-oauth"
gem "tzinfo"


gem 'test-unit', '1.2.3'

gem "omniauth-oauth2", "1.0"
gem "omniauth-openid"
gem "omniauth-google"
gem "omniauth-google-oauth2"
gem "omniauth-facebook"
gem "omniauth-salesforce", :git => "git://github.com/sathishfreshdesk/omniauth-salesforce.git", :branch => "master"
gem "omniauth-mailchimp", "~> 1.0.3"
gem "omniauth-constantcontact2", "~> 1.0.4"
gem "omniauth-surveymonkey", "1.0.0"
gem "nori", "1.1.4"
gem "google-api-client", "~> 0.6.3"
gem "ipaddress", "0.8.0"
gem 'omniauth-shopify-oauth2', "1.0.0"

gem "sidekiq", :git => "git://github.com/PratheepV/sidekiq.git", :branch => "master"

gem "soap4r-ruby1.9", "~> 2.0.5"
gem "jira4r", "0.3.0"
gem "ruby-openid", :git => "git://github.com/freshdesk/ruby-openid.git", :require => "openid"
gem "ruby-openid-apps-discovery", "1.2.0"
gem "twilio-ruby"
gem "carmen", :git => "git://github.com/jim/carmen.git", :tag => "ruby-18"

gem "ruby-saml", "0.8.1"

gem "arel", "2.0.7"
gem "map-fields", "1.0.0", :require => "map_fields"

gem "rubyzip", "0.9.4" , :require => "zip/zip"
gem "riak-client", "1.4.2"

gem "http_accept_language", "1.0.1"

gem "riddle", "1.2.2"

gem "jammit", "0.6.5"
gem "uglifier", "~> 2.1.2"
gem "yui-compressor", :git => "git://github.com/freshdesk/ruby-yui-compressor.git"

gem "braintree","2.10.0"
gem "lockfile","1.4.3"

gem "newrelic_rpm","3.8.0.218"

gem "faraday" , "0.8.7"
gem "twitter", "~> 5.5.1"
gem "gnip-rule", "0.4.1"
gem "curb", "~> 0.8.4"
gem "sanitize", "2.0.3"
gem "koala", "~> 1.6.0"
gem "spreadsheet", "0.6.8"

gem "sax-machine", "~> 0.1.0"

gem "insensitive_hash", "0.2.3"

gem "redis","3.0.7"
gem "resque","1.22.0"
gem "resque-status", "0.4.1"
gem 'resque-scheduler', :require => 'resque_scheduler'

gem 'marketo', :git => "git://github.com/freshdesk/Marketo.git"
gem 'rforce'

gem 'after_commit', "1.0.11"

gem 'chargebee', "~> 1.2.9"

gem 'encryptor', '1.1.3'
gem "dalli"
#gem 'memcache-client', '1.8.5', :git => "git://github.com/mperham/memcache-client.git"
gem "deadlock_retry", :git => "git://github.com/freshdesk/deadlock_retry.git"
gem "lhm", :git => "git://github.com/freshdesk/large-hadron-migrator.git"
gem "rinku", :git => "git://github.com/freshdesk/rinku.git"

gem "namae", '0.8.4'
gem 'ancestry', '1.3'
gem 'rubytree'
gem 'global_phone'
# gem "global_phone_dbgen", "~> 1.0.0"
gem "useragent", "~> 0.4.16"

gem "active_record_shards","2.7.0", :require => 'active_record_shards'
gem "rack-throttle", "~> 0.3.0"
gem "static_model", "~> 1.0.4"

gem 'clockwork', '0.4.1'
gem 'wkhtmltopdf-binary', :git => "git://github.com/freshdesk/wkhtmltopdf_binary_gem.git"
gem "wicked_pdf", "~> 0.9.10"
gem "pg"
gem "routing-filter", "~> 0.3.1"

gem "cloudfront_asset_host", :git => "git://github.com/freshdesk/cloudfront_asset_host.git"

# Please do not update Paperclip unless you can get it Monkey Patched for Imagemagick DoS Bug.
# Please see https://hackerone.com/reports/390 
gem "paperclip", "~> 2.8.0"

gem "aws-sdk", "~> 1.11.3"
gem "xml-simple", "~> 1.1.2"

gem "erubis", "2.7.0"
gem "rails_xss", "0.4.0"


gem "ey_config"
gem "therubyracer"
gem "premailer", "~> 1.8.0"

gem "akismetor", :git => "git://github.com/freshdesk/akismetor.git"

gem "bunny", "1.2.1"

gem "custom_fields", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/custom_fields-0.1"

group :production,:test,:staging do
  gem 'tire', :git => "git://github.com/freshdesk/tire.git", :branch => "multi_match"
end

gem "freshdesk_authority", :path => "#{File.expand_path(__FILE__)}/../vendor/gems/freshdesk_authority-0.1"
gem "active_presenter", "1.4.0"

group :development,:test do
  gem "forgery","0.5.0"
  gem "factory_girl", "1.2.3"
  gem "mongrel",  '>= 1.2.0.pre2'
end

group :test do
  gem "rspec", "1.3.1"
  gem "rspec-rails", "1.3.3"
  gem "spork", "~> 0.8.0"
  gem "mocha", "~> 0.12.8"
  gem 'rack-test', '~> 0.6.2'
  gem "rr", "1.1.1"
  gem "ZenTest", "4.4.1"
  gem "autotest-fsevent", "0.1.1"
  gem "autotest-growl", "0.2.0"
  gem "autotest-rails", "4.1.0"
  gem "faker", "~> 1.0.1"
  gem "simplecov", "~> 0.7.1"
  gem "simplecov-csv"
  gem "database_cleaner"
end

group :assets do
  gem "sass",          "3.2.19"
  gem "compass-rails", "1.0.3"

  # Portal grid system is done using susy grids
  gem "susy",          "1.0.9"

  # To optimize sprite generation
  gem "oily_png",     "1.1.1"

  # Building custom font icons inside the application
  gem "fontcustom",   "1.3.3"
end
