# source :gemcutter
ruby '2.3.8'
Encoding.default_external = Encoding::UTF_8
source 'https://rubygems.org'

gem 'rake', '~> 12.3.2'
gem 'rails','3.2.22.5'

gem 'freemail', '0.2.3', require: false 
gem 'rack-cors', '~> 0.4.1'
gem 'json', '1.8.6'
gem 'syck', '1.0.5'
gem 'oj'
gem 'jbuilder', '2.2.13'
gem 'strong_parameters', '0.2.3' # Used for API params validation
gem 'mysql2', '~> 0.3.0'
gem 'connection_pool'
gem 'sidekiq', '4.2.10'
# This needs bundler 1.7.2 or 1.10.6 as other version has problem in resolving.
source 'https://690a8c5e:5d9334f0@gems.contribsys.com/' do
  gem 'sidekiq-pro', '3.7.1'
end
gem 'shoryuken', '5.0.4'
# Redis::Client is patched in lib/redis/client_patch.rb
# Patch has to be removed before upgrading redis gem
gem 'redis','3.3.1'
gem 'redis-namespace'
gem 'dalli' #, git: 'git://github.com/freshdesk/dalli.git', branch: 'fd_master'
gem 'activemerchant', git: 'git://github.com/Shopify/active_merchant', tag: 'v1.43.1'
gem 'acts_as_list', '0.1.4'# Please do not update acts_as_list unless this issue is resolved https://github.com/swanandp/acts_as_list/issues/137
gem 'authlogic', '~> 3.4.2'
gem 'active_record_shards', '~> 3.2.0', require: 'active_record_shards'
gem 'active_presenter', git: 'git://github.com/jorgevaldivia/active_presenter.git'
gem 'acts_as_api', '1.0.1'
gem 'will_paginate', '3.3.0'
gem 'pg', '0.18.4' # PRE-RAILS: version exception in stack deployment, reset with old version
gem 'cld2', require: 'cld'
gem 'google-api-client', '~> 0.7.0'
gem 'mail', '2.5.5'
gem 'white_list', git:'git://github.com/neubloc/white_list.git'
gem 'country_select', git: 'git://github.com/stefanpenner/country_select', tag: 'v1.1.2'
gem 'prototype-rails', '~> 3.2.0'
gem 'dynamic_form'
gem 'prototype_legacy_helper', '0.0.0', git: 'git://github.com/rails/prototype_legacy_helper.git'
gem 'sneaky-save' #, git: 'git://github.com/partyearth/sneaky-save.git'
gem 'i18n', '0.9.5'
gem 'i18n-js', '3.2.1'
gem 'RedCloth', '4.3.2'
gem 'rails_autolink', '1.1.6'
gem 'ipaddress', '0.8.3'
gem 'ruby-openid-apps-discovery', '1.2.0'
gem 'ruby-saml', '1.7.0'
gem 'rubyzip', '1.3.0' # will load new rubyzip version
gem 'zip-zip' # will load compatibility for old rubyzip API.
gem 'http_accept_language', '~> 2.0.1'
gem 'insensitive_hash', '0.2.3'
gem 'encryptor', '1.1.3'
gem 'symmetric-encryption', '4.0.0'
gem 'namae', '1.0.1'
gem 'ancestry', '3.0.1' # Overriden unscoped_where method in social/fb_post.rb, take this into consideration this while upgrading the gem
gem 'useragent', '~> 0.16.3'
gem 'rack-throttle', '~> 0.5.0'
gem 'routing-filter', '~> 0.3.1'
gem 'gemoji-parser', '~> 1.3.1'
gem 'premailer', '1.11.1'
gem 'html_to_plain_text', '1.0.5'
gem 'recaptcha', '~> 4.14.0', require: 'recaptcha/rails'
gem 'gon', '~> 6.2.0' # For Passing Data to JavaScript
gem 'dnsruby', '1.60.2' # dkim to check dns records
gem 'rugged', '0.28.5'
gem 'clearbit'
gem 'nokogiri', '= 1.10.2'
gem 'therubyracer', '0.12.3' # required for execjs gem(uglifier dependency)
gem 'uglifier', '~> 2.7.2'
gem 'sprockets', '2.2.3'
gem 'safe_yaml', '1.0.5'
gem 'ejson', require: false
gem 'jwt', '1.5.4'
gem 'json-jwt', '1.9.4'
gem 'jwe', '0.3.0', git: 'git@github.com:freshdesk/ruby-jwe.git'
gem 'jose', '1.1.2'
gem 'has_scope', '0.6.0'
gem 'rack-protection', '1.5.5'
gem 'range_operators'

#Aws services
gem 'aws-sdk', '~> 1.31.3' # paperclip using aws-sdk v1, can updated after rails 4.
gem 'aws-sdk-dynamodb', '~> 1'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-sqs', '~> 1'
gem 'aws-sdk-cloudwatch', '~> 1'
gem 'aws-sdk-sns', '~> 1'
gem 'aws-sdk-route53','~> 1'
gem 'aws-sdk-cloudfront','~> 1'
# # PRE-RAILS: Need to check and cleanup
gem 'aws-sdk-swf', '~> 1'
gem 'aws-sdk-lambda', '~> 1'

gem 'omniauth', '1.3.2'
gem 'omniauth-oauth', '1.1.0'
gem 'oauth', '0.5.4'
gem 'omniauth-oauth2', '1.1.2'
gem 'omniauth-openid', '1.0.1'
# TODO-RAILS3 need check are we still using this
gem 'omniauth-google', '1.0.2'
gem 'omniauth-google-oauth2', '0.1.13'
gem 'omniauth-quickbooks', '0.0.2'
gem 'omniauth-mailchimp', '2.1.0'
gem 'omniauth-constantcontact2', '1.0.4'
gem 'doorkeeper', '2.2.1' # Marketplace
# To access Gmail IMAP and STMP via OAuth (XOAUTH2)
# using the standard Ruby Net libraries
gem 'gmail_xoauth', '~> 0.4.2'

# HTTP clients
gem 'rest-client', '1.8.0'
gem 'httparty', '0.11.0'
gem 'faraday' , '0.9'
gem 'faraday_middleware', '~> 0.10.0'
gem 'typhoeus' # Search v2
gem 'thrift', '~> 0.9.2.0'

# TODO_RAILS3 Remove the default asset pipeline
# gem 'jammit',         '0.6.5'
gem 'yui-compressor', git: 'git://github.com/freshdesk/ruby-yui-compressor.git', branch: 'fd_master'
gem 'asset_sync', '1.1.0'
gem 'turbo-sprockets-rails3', '0.3.14'
gem 'ejs', '1.1.1'
gem 'sass-rails', '3.2.6' # SASS and Compass gems
gem 'compass-rails', '2.0.0'
gem 'compass-blueprint', '1.0.0'
gem 'susy', '2.1.3' # Portal grid system is done using susy grids
gem 'oily_png', '1.1.1' # To optimize sprite generation
gem 'fontcustom', '1.3.3' # Building custom font icons inside the application

# Please do not update Paperclip unless you can get it Monkey Patched for Imagemagick DoS Bug.
# Please see https://hackerone.com/reports/390
gem 'cocaine', git: 'git@github.com:freshdesk/cocaine.git', tag: 'v0.5.8.1'
gem 'paperclip', '~> 4.2.2'

# email
gem 'charlock_holmes', '0.7.6'
gem 'tnef', '1.0.2'
gem 'iconv', '~> 1.0.4'
gem 'net-http-persistent', '~> 2.9.4'
gem 'clamav-client', '3.1.0', require: 'clamav/client'

# payment
gem 'braintree','2.10.0'
gem 'chargebee', '~> 1.5.1'

# freshfone
gem 'carmen', git: 'git://github.com/jim/carmen.git', tag: 'ruby-18'
# gem 'postoffice', git: 'git://github.com/chrisbutcher/postoffice.git', branch: 'master' # PRE-RAILS: added a file to repo for rdoc removed in gemspec
gem 'rubytree'
gem 'telephone_number', '1.1.1'
gem 'resque','~> 1.24.0'
gem 'resque-scheduler', '2.2.0', require: 'resque_scheduler'
# gem 'resque-status', '0.4.1'

# reports
gem 'spreadsheet', '0.6.8'
gem 'wkhtmltopdf-binary', git: 'git://github.com/freshdesk/wkhtmltopdf_binary_gem.git', branch: 'ruby_2.3'
gem 'wicked_pdf', '~> 0.9.10'

# social
gem 'twitter', '~> 5.16.0'
gem 'twitter-text'
gem 'gnip-rule', '1.0.0'
gem 'curb', '~> 0.8.5'
gem 'sanitize', '4.6.6'
gem 'koala', '1.10.1'

# gem 'sax-machine', '~> 0.1.0' # zen import

#integration 
gem 'omniauth-box2', '~> 0.0.1'
gem 'static_model', '~> 1.1.0'
gem 'xml-simple', '1.1.5', require: 'xmlsimple'
gem 'soap4r-ruby1.9', '~> 2.0.5' # jira
gem 'jira4r', '0.3.0'
gem 'rforce'
gem 'dynamics_crm', git: 'git@github.com:TinderBox/dynamics_crm.git', branch: 'master'

# log trace, For debugging app in staging/production
gem 'marginalia', '1.7.0'
gem 'newrelic_rpm','~> 5.5.0'
gem 'ddtrace'
gem 'dogstatsd-ruby'
gem 'rbtrace', require: false
gem 'prometheus_exporter', git: 'git@github.com:freshdesk/prometheus_exporter.git', tag: 'v1.1.0'

# Freshdesk
gem 'rate-limiting', git:'git://github.com/freshdesk/rate-limiting.git', tag: 'v1.2.2'
gem 'time_bandits', git: 'git@github.com:freshdesk/fd_time_bandits', tag: 'v1.3' # for instrumenting cache-performance
gem 'rack-ssl', require: 'rack/ssl', git: 'git://github.com/freshdesk/rack-ssl', branch: 'ssl'
gem 'omniauth-salesforce', git: 'git://github.com/freshdesk/omniauth-salesforce.git', branch: 'master'
gem 'ruby-openid', git: 'git://github.com/freshdesk/ruby-openid.git', require: 'openid', branch: 'fd_ruby_openid'
gem 'twilio-ruby', git: 'git://github.com/freshdesk/twilio-ruby.git', branch: 'freshdesk_master'
gem 'xeroizer', git: 'git@github.com:freshdesk/xeroizer.git'
gem 'lhm', git: 'git://github.com/freshdesk/large-hadron-migrator.git'
gem 'rinku', git: 'git://github.com/freshdesk/rinku.git'
gem 'i18nema', git: 'https://github.com/freshdesk/i18nema', require: false

# Inhouse gems
gem 'emailserv_request', git: 'git@github.com:freshdesk/emailserv_request.git', tag: 'v1.1' # email
gem 'fd_rate_limiter', git: 'git@github.com:freshdesk/fd_rate_limiter.git', branch: 'dynamic_rules'
gem 'fresh_request', git: 'git@github.com:freshdesk/fresh_request.git', branch: 'release'
gem 'akismetor', git: 'git://github.com/freshdesk/akismetor.git'
gem 'deadlock_retry', git: 'git://github.com/freshdesk/deadlock_retry.git'
gem 'freshdesk_features', git: 'git@github.com:freshdesk/freshdesk-features.git', branch: 'freshdesk', require: true
gem 'launchparty', git: 'git@github.com:freshdesk/launch-party.git', tag: 'v0.2.1'
gem 'binarize', '0.1.1', git: 'git@github.com:freshdesk/binarize.git', branch: 'not_a_model_column'
gem 'rule_engine', git: 'git@github.com:freshdesk/rule_engine.git', tag: 'hv0.0.13.16'
gem 'freshid', git: 'git@github.com:freshdesk/freshid-ruby-client.git', tag: 'v4.0.13'
gem 'freshid-sdk', git: 'git@github.com:freshdesk/platforms-sdk-ruby.git', tag: '1.1.3', glob: 'gems/freshid-sdk/freshid-sdk.gemspec'
gem 'fluffy', git: 'git@github.com:freshdesk/api-gateway.git', tag: 'v0.0.5', glob: 'clients/fluffy_ruby/src/fluffy.gemspec'
gem 'central-publisher', git: 'git@github.com:freshdesk/central-publisher.git', tag: 'v2.0.17'
gem 'formserv-gem', git: 'git@github.com:freshdesk/formserv-gem.git', tag: 'v0.11.3'
gem 'optar', git: 'git@github.com:freshdesk/optar.git', tag: 'v1.1.4'
gem 'sidekiq_sober', git: 'git@github.com:freshdesk/sidekiq_sober.git', tag: 'v1.0.0'

# Vendor gems
gem 'add_pod_support', path: '#{File.expand_path(__FILE__)}/../vendor/gems/add_pod_support-0.0.1'
gem 'custom_fields', path: '#{File.expand_path(__FILE__)}/../vendor/gems/custom_fields-0.1'
gem 'freshdesk_authority', path: '#{File.expand_path(__FILE__)}/../vendor/gems/freshdesk_authority-0.1'
gem 'delayed_job', path: '#{File.expand_path(__FILE__)}/../vendor/gems/delayed_job'
gem 'facebook', path: '#{File.expand_path(__FILE__)}/../vendor/gems/facebook'
gem 'acts_as_voteable', path: '#{File.expand_path(__FILE__)}/../vendor/gems/acts_as_voteable'
gem 'ar_shards', path: '#{File.expand_path(__FILE__)}/../vendor/gems/ar_shards'
gem 'xss', path: '#{File.expand_path(__FILE__)}/../vendor/gems/xss'
gem 'has_no_table', path: '#{File.expand_path(__FILE__)}/../vendor/gems/has_no_table'
gem 'gnip', path: '#{File.expand_path(__FILE__)}/../vendor/gems/gnip'
gem 'dev_notification', path: '#{File.expand_path(__FILE__)}/../vendor/gems/dev_notification'
gem 'sharding', path: '#{File.expand_path(__FILE__)}/../vendor/gems/sharding'
gem 'business_time', path: '#{File.expand_path(__FILE__)}/../vendor/gems/business_time'
gem 'paperclip_ext', path: '#{File.expand_path(__FILE__)}/../vendor/gems/paperclip_ext'
gem 'ssl_requirement', path: '#{File.expand_path(__FILE__)}/../vendor/gems/ssl_requirement'
gem 'helpdesk_attachable', path: '#{File.expand_path(__FILE__)}/../vendor/gems/helpdesk_attachable'
gem 'has_flexiblefields', path: '#{File.expand_path(__FILE__)}/../vendor/gems/has_flexiblefields'
gem 'liquid', path: '#{File.expand_path(__FILE__)}/../vendor/gems/liquid'
gem 'seed-fu', path: '#{File.expand_path(__FILE__)}/../vendor/gems/seed-fu'
gem 'highcharts-rails', path: '#{File.expand_path(__FILE__)}/../vendor/gems/highcharts-rails' # reports
gem 'will_paginate-liquidized', path: '#{File.expand_path(__FILE__)}/../vendor/gems/will_paginate-liquidized'
gem 'will_filter', path: '#{File.expand_path(__FILE__)}/../vendor/gems/will_filter'
gem 'rack-openid', path: '#{File.expand_path(__FILE__)}/../vendor/gems/rack-openid'
gem 'open_id_authentication', path: '#{File.expand_path(__FILE__)}/../vendor/gems/open_id_authentication'
gem 'ebayr', path: '#{File.expand_path(__FILE__)}/../vendor/gems/ebayr'
gem 'fd_spam_detection_service', path: '#{File.expand_path(__FILE__)}/../vendor/gems/fd_spam_detection_service'
# gem 'log_filter', path: '#{File.expand_path(__FILE__)}/../vendor/gems/log_filter' # should be removed
# gem 'sentient_user', path: '#{File.expand_path(__FILE__)}/../vendor/gems/sentient_user' # should be removed

group :production, :staging, :development do
  gem 'semian', require: %w(semian semian/mysql2), git: 'git://github.com/freshdesk/semian.git', branch: 'fd_master'
end

group :production, :staging, :test do
  gem 'tire', git: 'git@github.com:freshdesk/retire.git'
  gem 'test-unit', '3.1.7' # PRE-RAILS: activesupport requires test-unit in staging console boot, need to check for production env.
end

group :staging, :test, :development do
  gem 'bullet', '5.4.3'
end

group :staging do
  gem 'coverband', '1.5.4'
end

group :test,:development do
  gem 'active_record_query_trace'
  gem 'rails-dev-boost', git: 'git://github.com/thedarkone/rails-dev-boost.git'
  # Commenting out for ruby ~> 2.1.0 upgrade
  # gem 'debugger', '~> 1.6.8'
  gem 'pry'
  gem 'pry-byebug'
  gem 'byebug', '11.0.1'
  gem 'pry-nav'
  gem 'binding_of_caller'
  gem 'meta_request'
  gem 'fake_sqs', '0.3.1'
  gem 'fake_dynamo', '0.2.5'
  gem 'forgery','0.5.0'
  gem 'factory_girl_rails', '4.4.0'
  gem 'webrick', '1.3.1'
  gem 'jasmine', '2.4.0'
  gem 'spring', '1.2.0'
  gem 'rubocop', '0.68.0'
  gem 'unicode-display_width', '1.4.1'
end

group :test do
  #ruby 2.2.3 expects tesst-unit to be available by default.
  #http://stackoverflow.com/questions/28252036/how-to-run-existing-test-code-on-ruby-2-2
  gem 'test-unit-minitest'
  gem 'rspec', '~> 3.8.0'
  gem 'rspec-rails', '~> 3.8.0'
  gem 'spork', '~> 0.9.0'
  gem 'mocha', '~> 0.13.0', require: false
  gem 'rspec-collection_matchers', '1.0.0'
  gem 'rack-test', '~> 0.6.2'
  gem 'rr', '~> 1.1.0' # PRE-RAILS: Need to clean up. moved stubs to mocha
  gem 'ZenTest', '4.4.1'
  gem 'autotest-fsevent', '0.1.1'
  gem 'autotest-growl', '0.2.0'
  gem 'autotest-rails', '4.1.0'
  gem 'faker', '~> 1.4.3'
  gem 'simplecov', '~> 0.16.1'
  gem 'simplecov-csv'
  gem 'database_cleaner', '1.5.3'
  gem 'fuubar', '2.1.1'
  gem 'json-compare', '0.1.8'
  gem 'rspec_junit_formatter', '0.2.3' # Used by API
  gem 'simplecov-rcov'
  gem 'rubocop-checkstyle_formatter' # Used by API
  gem 'minitest-rails', '1.0.1' # Used by API
  gem 'minitest-reporters', '0.14.24' # Used by API
  gem 'minitest', '4.7.5'
  gem 'json_expressions', '0.8.3' # Used by API
  gem 'timecop', '0.8.1' # Used by API
  gem 'yard-cucumber', '3.1.0', require: false
  gem 'cucumber-rails', require: false
  gem 'cucumber_statistics', '2.3.0'
  gem 'fakeweb', '~> 1.3'
  gem 'webmock'
  gem 'codecov', require: false
  gem 'yard' , '0.9.20'
end

group :development do
  #commenting it out as rack mini profiler strips out etag response headers. Using it for falcon apis.
  #gem 'rack-mini-profiler', group: [:development]
  # gem 'bootsnap', require: false
  gem 'brakeman', require: false
  gem 'pronto', '0.6.0'
  gem 'pronto-rubocop', '0.6.2', require: false
  gem 'pronto-rails_best_practices', '0.6.0', require: false
  gem 'pronto-brakeman', '0.6.0', require: false
  gem 'pronto-reek', '0.6.2', require: false
  gem 'better_errors', '~> 1.1.0'
end
