class AddConfigOptionsToFreshbooks < ActiveRecord::Migration
  shard :all

  def up
  	Integrations::Application.find_by_name('freshbooks').update_attributes(
    :options => {
        :keys_order => [:title, :api_url, :api_key, :settings], 
        :title => { :type => :text, :required => true, :label => "integrations.freshbooks.form.widget_title", :default_value => "Freshbooks"},
        :api_url => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_url", :info => "integrations.freshbooks.form.api_url_info", :validator_type => "url_validator" }, 
        :api_key => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_key", :info => "integrations.freshbooks.form.api_key_info" },
        :settings => { :type => :custom, :required => false, :label => "integrations.google_contacts.form.account_settings", :partial => "/integrations/applications/invoice_timeactivity_settings" }
    }
  	)	
  end

  def down
  	Integrations::Application.find_by_name('freshbooks').update_attributes(
  	    :options => {
        :keys_order => [:title, :api_url, :api_key, :freshbooks_note], 
        :title => { :type => :text, :required => true, :label => "integrations.freshbooks.form.widget_title", :default_value => "Freshbooks"},
        :api_url => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_url", :info => "integrations.freshbooks.form.api_url_info", :validator_type => "url_validator" }, 
        :api_key => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_key", :info => "integrations.freshbooks.form.api_key_info" },
        :freshbooks_note => { :type => :text, :required => false, :label => "integrations.freshbooks.form.freshbooks_note", 
                            :info => "integrations.freshbooks.form.freshbooks_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}}' }
    }
    )
  end
end
