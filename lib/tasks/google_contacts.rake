namespace :google_contacts do
  desc 'Sync the modified contacts between Freshdesk and Google contacts.'
  task :sync => :environment do
    puts "Google contacts task initialized at #{Time.zone.now}"
    Integrations::GoogleContactsImporter.sync_google_contacts_for_all_accounts
    puts "Google contacts task finished at #{Time.zone.now}"
  end
end
