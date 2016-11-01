def log_file
  @log_file_path = "#{Rails.root}/log/rake.log"
end

def custom_logger(path)
  @custom_logger ||= CustomLogger.new(path)
end

CONTACTS_SYNC_TASKS = {
  "trial" => {
    :account_method => "trial_accounts",
    :class_name => "Integrations::ContactsSync::Trial"
  },

  "paid" => {
    :account_method => "paid_accounts",
    :class_name => "Integrations::ContactsSync::Paid"
  },

  "free" => {
    :account_method => "free_accounts",
    :class_name => "Integrations::ContactsSync::Free"
  }
}

namespace :contacts_sync do

  desc "Execute sync for trial accounts"
  task :trial => :environment do
    execute_sync("trial")
  end

  desc "Execute sync for free accounts"
  task :free => :environment do
    execute_sync("free")
  end

  desc "Execute sync for paid accounts"
  task :paid => :environment do
    execute_sync("paid")
  end

end

def execute_sync(task_name)
  begin
    puts "Contacts Sync initialized at #{Time.zone.now}"
    path = log_file
    rake_logger = custom_logger(path)
  rescue Exception => e
    puts "Error --- \n#{e.message}\n#{e.backtrace.join("\n")}"
    FreshdeskErrorsMailer.error_email(nil, nil, e, {
      :subject => "Splunk logging Error for contacts_sync.rake", :recipients => "integrations@freshesk.com"
    })
  end

  class_constant = CONTACTS_SYNC_TASKS[task_name][:class_name].constantize
  queue_name = class_constant.get_sidekiq_options["queue"]
  puts "::::queue_name:::#{queue_name}"

  rake_logger.info "rake=contacts_sync #{task_name}" unless rake_logger.nil?
  accounts_queued = 0
  Sharding.run_on_all_slaves do
    Account.current_pod.send(CONTACTS_SYNC_TASKS[task_name][:account_method]).each do |account|
      begin
        installed_application = account.installed_applications.joins(:application).where(
          'name in (?)', Integrations::Constants::CONTACTS_SYNC_APPS).last
        next if installed_application.nil?
        app_name = installed_application.application.name
        account.make_current
        class_constant.perform_async(app_name, :sync_contacts)
        accounts_queued += 1
      rescue Exception => e
        puts "Error --- \n#{e.message}\n#{e.backtrace.join("\n")}"
        NewRelic::Agent.notice_error(e, { :custom_params => { :account_id => Account.current.id, :installed_application => installed_application.to_json } })
      ensure
        puts "\n#{accounts_queued} accounts have been queued\n"
        Account.reset_current_account
      end
    end
  end
end
