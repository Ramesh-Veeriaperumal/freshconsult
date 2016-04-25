(Dir['test/api/**/*email_config*_test.rb'] -  Dir['test/api/integration/queries/*email_config*_test.rb']).each { |file| require "./#{file}" }
