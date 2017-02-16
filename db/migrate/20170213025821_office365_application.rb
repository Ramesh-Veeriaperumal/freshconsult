class Office365Application < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
  	Integrations::Application.create(
      :name => "office365",
      :display_name => "integrations.office365.label",
      :description => "integrations.office365.desc",
      :listing_order => 47,
      :options => {:direct_install => true},
      :application_type => "office365",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID
    )
  end

  def down
  	Integrations::Application.find_by_name("office365").destroy
  end
end
