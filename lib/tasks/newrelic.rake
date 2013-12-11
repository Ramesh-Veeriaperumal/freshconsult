# lib/tasks/newrelic.rake
namespace :newrelic do
  task :notify => :environment do
    require 'newrelic_rpm'
 
    if Rails.env.staging? 
      # Notify New Relic of deployment
      puts "Log deployment of #{ENV['REVISION']} with NewRelic"
      app = "helpkit"
      key = "7a4f2f3abfd0f8044580034278816352324a9fb7"
      if ENV['NR_KEY'].blank?
        app = Rails.application.class.parent_name
        key = EY::Config.get("New Relic", 'license_key')
      else
        app = ENV['APP']
        key = ENV['NR_KEY']
      end
      begin
        `curl -H "x-license-key:#{key}" -d "deployment[app_name]=#{app}" -d "deployment[revision]=#{ENV['REVISION']}" -d "deployment[user]=#{ENV['DEPLOYED_BY']}" https://rpm.newrelic.com/deployments.xml`
      rescue  Exception => e  
        puts "The following error occurred: #{e.message}"
      end
    end
  end
end