class PopulateCtiAdminApplication < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Integrations::Application.create(
      :name => "cti",
      :display_name => "integrations.cti_admin.label",
      :description => "integrations.cti_admin.desc",
      :listing_order => 43,
      :options => {
        :direct_install => true,
        :edit_url => "/integrations/cti_admin/edit",
        :auth_url => "/integrations/cti_admin/edit",
        :install => {:require_feature => {:notice => 'integrations.cti_admin.no_feature', :feature_name => :cti}},
        :edit => {:require_feature => {:notice => 'integrations.cti_admin.no_feature', :feature_name => :cti}},
        :after_commit => {
          :clazz => 'Integrations::Cti',
          :method => 'clear_memcache'
        }
      },
      :application_type => "cti_integration",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID
    )
  end

  def down
    Integrations::Application.find_by_name("cti_admin").destroy
  end
end
