class AddSharedOwnershipToApplication < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    shared_ownership = Integrations::Application.new(
      :name => "shared_ownership",
      :display_name => "integrations.shared_ownership.label",
      :description => "integrations.shared_ownership.desc",
      :listing_order => 50,
      :options => {
        :direct_install => true,
        :user_specific_auth => true,
        :before_create => {
          :clazz => 'Integrations::AdvancedTicketing::SharedOwnership',
          :method => 'install'
        },
        :after_commit_on_destroy => {
          :clazz => 'Integrations::AdvancedTicketing::SharedOwnership',
          :method => 'uninstall'
        }
      },
      :application_type => "shared_ownership",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    shared_ownership.save
  end

  def down
    Integrations::Application.where(:name => "shared_ownership").first.destroy
  end
end
