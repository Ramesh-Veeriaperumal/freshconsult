class AddDropboxToApplications < ActiveRecord::Migration
	@app_name = "dropbox"

  	def self.up	
   		dropbox = Integrations::Application.create(
	        :name => @app_name,
	        :display_name => "integrations.dropbox.label", 
	        :description => "integrations.dropbox.desc", 
	        :listing_order => 19,
	        :options => {:no_settings => true})
   		dropbox.save
	end

  def self.down
 	Integrations::Application.find(:first, :conditions => {:name => @app_name}).delete
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
  end
end
