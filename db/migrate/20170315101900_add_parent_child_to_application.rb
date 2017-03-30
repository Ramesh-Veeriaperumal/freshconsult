class AddParentChildToApplication < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    parent_child = Integrations::Application.new(
      :name => "parent_child_tickets",
      :display_name => "integrations.parent_child.label",
      :description => "integrations.parent_child.desc",
      :listing_order => 48,
      :options => {
        :direct_install => true,
        :user_specific_auth => true,
        :before_create => {
          :clazz => 'Integrations::AdvancedTicketing::ParentChild',
          :method => 'enable_parent_child'
        },
        :after_commit_on_destroy => {
          :clazz => 'Integrations::AdvancedTicketing::ParentChild',
          :method => 'disable_parent_child'
        }
      },
      :application_type => "parent_child_tickets",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    parent_child.save
  end

  def down
    Integrations::Application.where(:name => "parent_child_tickets").first.destroy
  end
end
