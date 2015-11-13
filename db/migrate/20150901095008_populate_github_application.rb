class PopulateGithubApplication < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Integrations::Application.create(
      :name => "github",
      :display_name => "integrations.github.label",
      :description => "integrations.github.desc",
      :listing_order => 36,
      :options => {
        :direct_install => true,
        :oauth_url => "/auth/github?origin=id%3D{{account_id}}",
        :edit_url => "/integrations/github/edit",
        :after_commit_on_destroy => {
          :method => "uninstall",
          :clazz => "IntegrationServices::Services::GithubService",
        },
      },
      :application_type => "github",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID
    )
  end

  def down
    Integrations::Application.find_by_name("github").destroy
  end
end
