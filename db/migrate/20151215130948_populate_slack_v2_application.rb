class PopulateSlackV2Application < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Integrations::Application.create(
      :name => "slack_v2",
      :display_name => "integrations.slack_v2.label",
      :description => "integrations.slack_v2.desc",
      :listing_order => 39,
      :options => {
        :direct_install => true,
        :auth_url => "/integrations/slack_v2/oauth",
        :edit_url => "/integrations/slack_v2/edit"
      },
      :application_type => "slack_v2",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID
    )
  end

  def down
    Integrations::Application.find_by_name("slack_v2").destroy
  end
end
