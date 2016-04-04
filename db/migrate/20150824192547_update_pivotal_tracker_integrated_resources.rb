class UpdatePivotalTrackerIntegratedResources < ActiveRecord::Migration
  shard :all
  
  def up
    app = Integrations::Application.find_by_name("pivotal_tracker")
    
    app.installed_applications.find_in_batches(:batch_size => 300) do |installed_apps|
      installed_apps.each do |installed_app|
        
        installed_app.integrated_resources.find_in_batches(:batch_size => 300) do |integ_resources|
          integ_resources.each do |integ_resource|

            account = Account.find_by_id(integ_resource.account_id)
            ticket = account.tickets.find_by_display_id(integ_resource.local_integratable_id)
            integ_resource.local_integratable_id = ticket.id
            integ_resource.save
            
          end
        end

      end
    end
  end

  def down
  end
end
