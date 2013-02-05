class AddDropboxToApplications < ActiveRecord::Migration
	@app_name = "dropbox"

  	def self.up	
   	Integrations::Application.create(
	        :name => @app_name,
	        :display_name => "integrations.dropbox.label", 
	        :description => "integrations.dropbox.desc", 
	        :listing_order => 19,
	        :options => {:app_key=>{:required=>:true,:type=>:text,:label=>"integrations.dropbox.form.app_key",:info=>"integrations.dropbox.form.app_key_info"},:keys_order=>[:app_key]})
	end

  def self.down
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
 	Integrations::Application.find(:first, :conditions => {:name => @app_name}).delete
  end
end
