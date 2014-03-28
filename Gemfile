# source :gemcutter
source 'http://rubygems.org'

gem "rake", "0.8.7"
gem "rack", "~> 1.1.6"
gem "rails","2.3.18"

gem "json", "~> 1.7.7"
gem "mysql2", "~> 0.2.7"

gem "mail"
gem "i18n", "0.4.2"
gem "RedCloth", "4.2.9"
gem "authlogic", "2.1.6"
gem "httparty", "0.10.0"
gem "omniauth", "1.0"
gem "omniauth-oauth"
gem "tzinfo"

gem 'debugger', "1.6.6"
gem 'test-unit', '1.2.3'

gem "omniauth-oauth2", "1.0"
gem "omniauth-openid"
gem "omniauth-google"
gem "omniauth-google-oauth2"
gem "omniauth-facebook"
gem "omniauth-salesforce"
gem "omniauth-mailchimp", "~> 1.0.3"
gem "omniauth-constantcontact2", "~> 1.0.4"
gem "omniauth-surveymonkey", "1.0.0"
gem "nori", "1.1.4"
gem "google-api-client", "~> 0.6.3"
gem "ipaddress", "0.8.0"

gem "soap4r-ruby1.9", "~> 2.0.5"
gem "jira4r", "0.3.0"
gem "ruby-openid", :git => "git://github.com/freshdesk/ruby-openid.git", :require => "openid"
gem "ruby-openid-apps-discovery", "1.2.0"
gem "twilio-ruby"
gem "carmen", :git => "git://github.com/jim/carmen.git", :tag => "ruby-18"

gem "ruby-saml", "0.7.2"

gem "arel", "2.0.7"
gem "map-fields", "1.0.0", :require => "map_fields"

gem "rubyzip", "0.9.4" , :require => "zip/zip"
gem "riak-client", "1.4.2"

gem "http_accept_language", "1.0.1"

gem "riddle", "1.2.2"
gem "delayed_job", "1.8.4"

gem "jammit", "0.6.5"
gem "uglifier", "~> 2.1.2"
gem "yui-compressor", :git => "git://github.com/freshdesk/ruby-yui-compressor.git"

gem "braintree","2.10.0"
gem "lockfile","1.4.3"

gem "newrelic_rpm","3.5.8.72"

gem "faraday" , "0.8.7"
gem "twitter" , "~> 4.6.2"
gem "gnip-rule", "~> 0.4.0"
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

gem "people", '0.2.1' #https://github.com/mericson/people/tree/master/lib
gem 'ancestry', '1.3'
gem 'rubytree'
gem 'global_phone'
# gem "global_phone_dbgen", "~> 1.0.0"
gem "useragent", "~> 0.4.16"

gem "active_record_shards","2.7.0", :require => 'active_record_shards'
gem "rack-throttle", "~> 0.3.0"
gem "static_model", "~> 1.0.4"

gem 'clockwork', '0.4.1'
gem "wkhtmltopdf-binary", "~> 0.9.9.1"
gem "wicked_pdf", "~> 0.9.2"
gem "pg"
gem "routing-filter", "~> 0.3.1"

gem "cloudfront_asset_host", :git => "git://github.com/freshdesk/cloudfront_asset_host.git"
gem "paperclip", "~> 2.8.0"
gem "aws-sdk", "~> 1.11.3"
gem "xml-simple", "~> 1.1.2"

gem "erubis", "2.7.0"
gem "rails_xss", "0.4.0"

gem "ey_config"
gem "therubyracer"
gem "premailer", "~> 1.8.0"

gem "akismetor", :git => "git://github.com/freshdesk/akismetor.git"

group :production,:test,:staging do
  gem 'tire', :git => "git://github.com/freshdesk/tire.git"
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
  gem "rr", "1.1.1"
  gem "ZenTest", "4.4.1"
  gem "autotest-fsevent", "0.1.1"
  gem "autotest-growl", "0.2.0"
  gem "autotest-rails", "4.1.0"
  gem "faker", "~> 1.0.1"
  gem "simplecov", "~> 0.7.1"
end

group :assets do
   gem "sass", "3.2.1"
   gem "compass-rails", "1.0.3"
   gem "susy"  # Portal grid system is done using susy grids
   gem "oily_png" # To optimize sprite generation
end
