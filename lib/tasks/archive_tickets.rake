# usage rake archive_tickets:archive_closed_tickets
# This checks for feature for intial few days, till everything is working properly
namespace :archive_tickets do
  
  desc "This task archives all closed tickets with no activities in the last n days"
  task :archive_closed_tickets => :environment do
    Sharding.run_on_all_slaves do    
      Features::Feature.find_in_batches(:conditions => ["type = 'ArchiveTicketsFeature'"]) do |features|
        features.each do |feature|
          account = feature.account.make_current
          Archive::TicketsSplitter.perform_async({ :account_id => feature.account_id, :ticket_status => :closed })
        end
      end
    end
  end
end
