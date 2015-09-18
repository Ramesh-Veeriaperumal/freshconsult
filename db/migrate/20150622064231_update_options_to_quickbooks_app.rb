class UpdateOptionsToQuickbooksApp < ActiveRecord::Migration

  shard :all

  def up
  	Integrations::Application.find_by_name('quickbooks').update_attributes(
      :options => {
        :direct_install => true,
        :configurable => true,
        :keys_order => [:settings],
    	  :settings => {
    	    :type => :custom,
    	    :required => false,
    	    :partial => "/integrations/applications/invoice_timeactivity_settings",
    	    :label => "integrations.quickbooks.form.account_settings"
    	  },
        :after_destroy => {
          :clazz => "Integrations::QuickbooksUtil",
          :method => "remove_app_from_qbo"
        }
      }
    )
  end

  def down
  	Integrations::Application.find_by_name('quickbooks').update_attributes(
      :options => {
        :direct_install => true,
        :after_destroy => {
          :clazz => "Integrations::QuickbooksUtil",
          :method => "remove_app_from_qbo"
        }
      }
    )
  end
end
