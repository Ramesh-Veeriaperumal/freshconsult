TICKETS_THRESHOLD = 20 #Allowed number of tickets in 30 minutes window..
CONVERSATIONS_THRESHOLD = 40
#We might need to make the time window also as configurable. Right now, 30 minutes looks like a good guess!

namespace :watch do
  desc 'Check for abnormal activities and email us, if needed'
  task :abnormal => :environment do
    puts "Check for abnormal activities started at #{Time.now}"
    check_and_alert('helpdesk_tickets', TICKETS_THRESHOLD)
    check_and_alert('helpdesk_notes', CONVERSATIONS_THRESHOLD)
  end
end

def check_and_alert(table, threshold)
  current_time = Time.zone.now #Should it be Time.now?!?!
  query_str = <<-eos
    select account_id,count(*) as total from #{table} where created_at 
    between '#{30.minutes.ago(current_time).to_s(:db)}' and '#{current_time.to_s(:db)}' 
    group by account_id having total > #{threshold}
  eos
  accounts = ActiveRecord::Base.connection.select_values(query_str)
  puts "The accounts which are having abnormal load in '#{table}' are #{accounts}"
  deliver_alert(table, accounts, query_str) unless accounts.empty?

  #  accounts.each do |a| #Well, this part could be argued either way (do it here vs do in on a consilated list)
  #    
  #  end
end

def deliver_alert(table, accounts, query_str)
  FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
    {
      :subject          => "Abnormal load in #{table}",
      :additional_info  => {
        :accounts_list  => accounts,
        :query          => query_str
      }
    }
  )
end
