class OnedriveMint < ActiveRecord::Migration
  shard :all

  @app_name = "onedrive_mint"

  def self.up
    Integrations::Application.create(
          :name => @app_name,
          :display_name => "integrations.onedrive_mint.label",
          :description => "integrations.onedrive_mint.desc",
          :listing_order => 51,
          :application_type => "onedrive_mint",
          :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID,
          :options => {
              :keys_order => [:application_id],
              :application_id => { :type => :text, :required => true, :label => "integrations.onedrive_mint.form.application_id" },
          })
  end

  def self.down
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
    Integrations::Application.where(name: @app_name).first.delete
  end

end
