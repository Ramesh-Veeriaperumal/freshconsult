class Sugarcrm < ActiveRecord::Migration
shard :all

  def up
   	Integrations::Application.find_by_name("sugarcrm").update_attributes(
     	:options => {:direct_install => true, :auth_url => "/integrations/sugarcrm/settings", :edit_url => "/integrations/sugarcrm/edit",:default_fields => {:account => ["Name:"], :contact => ["Name:"], :lead => ["Name:"]}})
  end

  def down
  	Integrations::Application.find_by_name("sugarcrm").update_attributes(
  	 :options => {
        :keys_order => [:domain, :username, :password], 
        :domain => { :type => :text, :required => true, :label => "integrations.sugarcrm.form.domain", :info => "integrations.sugarcrm.form.domain_info", :validator_type => "url_validator" }, 
        :username => { :type => :text, :required => true, :label => "integrations.sugarcrm.form.username" },
        :password => { :type => :password, :label => "integrations.sugarcrm.form.password", :encryption_type => "md5" }
    }
   )
  end
end
