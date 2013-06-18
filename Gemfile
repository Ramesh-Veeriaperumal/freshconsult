# source :gemcutter
source 'https://rubygems.org'

gem "rake", "0.8.7"
gem "rack", "~> 1.1.6"
gem "rails","2.3.18"

gem "json", "~> 1.5.5"
gem "mysql", "2.8.1"
gem "i18n", "0.4.2"

gem "RedCloth", "4.2.9"
gem "authlogic", "2.1.6"
gem "httparty", "0.10.0"
gem "omniauth", "1.0"
gem "omniauth-oauth"
gem "tzinfo"
gem "ruby-debug", "0.10.3", :platforms => :ruby_18
gem 'debugger', :platforms => :ruby_19
gem 'test-unit', '1.2.3', :platforms => :ruby_19
gem "omniauth-oauth2", "1.0"
gem "omniauth-openid"
gem "omniauth-google"
gem "omniauth-google-oauth2"
gem "omniauth-facebook"
gem "omniauth-salesforce"
gem "omniauth-mailchimp", "~> 1.0.3"
gem "omniauth-constantcontact2", "~> 1.0.4"
gem "nori", "1.1.4"
gem "google-api-client", "~> 0.6.3"

gem "soap4r-ruby1.9", "~> 2.0.5", :platforms => :ruby_19
gem "jira4r", "0.3.0"
gem "ruby-openid", :git => "git://github.com/freshdesk/ruby-openid.git", :require => "openid"
gem "ruby-openid-apps-discovery", "1.2.0"

gem "aws-s3", "0.6.2", :require => "aws/s3"
gem "arel", "2.0.7"
gem "map-fields", "1.0.0", :require => "map_fields"

gem "rubyzip", "0.9.4" , :require => "zip/zip"

gem "http_accept_language", "1.0.1"

gem "riddle", "1.2.2"
gem "thinking-sphinx", "1.4.3", :require => "thinking_sphinx"
gem "delayed_job", "1.8.4"
#gem "ts-delayed-delta", "1.1.0", :require => "thinking_sphinx/deltas/delayed_delta"

gem "net-dns", "0.6.1"


gem "jammit", "0.6.5"
gem "yui-compressor", :git => "git://github.com/freshdesk/ruby-yui-compressor.git"
# gem "zendesk-features", :require => "features"

gem "braintree","2.10.0"
gem "lockfile","1.4.3"
gem "newrelic_rpm","3.5.3.25"

gem "twitter", "~> 4.6.2"
gem "sanitize", "2.0.3"
gem "koala", "~> 1.0.0"
gem "spreadsheet", "0.6.8"

gem "sax-machine", "~> 0.1.0"

gem "insensitive_hash", "0.2.3"

gem "SystemTimer", "1.2.3", :platforms => :ruby_18
gem "redis","2.2.2"
gem "resque","1.22.0"
gem "resque-status", "0.4.1"

gem 'marketo', :git => "git://github.com/freshdesk/Marketo.git"
gem 'rforce'

gem 'after_commit', "1.0.11"

gem 'chargebee', "~> 1.1.7"

gem 'memcache-client', '1.8.5'
gem "deadlock_retry", :git => "git://github.com/freshdesk/deadlock_retry.git"
gem "lhm", :git => "git://github.com/freshdesk/large-hadron-migrator.git"
gem "rinku", :git => "git://github.com/freshdesk/rinku.git"

gem "people", '0.2.1' #https://github.com/mericson/people/tree/master/lib
gem "useragent", "~> 0.4.16"

gem "active_record_shards","2.7.0", :require => 'active_record_shards'
gem "rack-throttle", "~> 0.3.0"
gem "static_model", "~> 1.0.4"

gem 'clockwork', '0.4.1'
gem "wkhtmltopdf-binary", "~> 0.9.9.1"
gem "wicked_pdf", "~> 0.9.2"
gem "pg"

gem "cloudfront_asset_host", :git => "git://github.com/freshdesk/cloudfront_asset_host.git"

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
   gem "mocha", "~> 0.13.3"
   gem "rr", "1.1.0"
   gem "ZenTest", "4.4.1"
   gem "autotest-fsevent", "0.1.1"
   gem "autotest-growl", "0.2.0"
   gem "autotest-rails", "4.1.0"
end

group :assets do
   gem "sass", "3.2.1"
   gem "compass-rails"
   # Portal grid system is done using susy grids
   gem "susy" 
   # To optimize sprite generation
   gem "oily_png"
end