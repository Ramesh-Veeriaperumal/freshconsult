namespace :supervisor do
  desc 'Execute Supervisor Rules...'
  task :run => :environment do
    unless Rails.env.staging?
      Account.active_accounts.each do |account|
        if account.supervisor_rules.count > 0
          Resque.enqueue( Workers::Supervisor, account.id)
        end
      end
    end
  end
end