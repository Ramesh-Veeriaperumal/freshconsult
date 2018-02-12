class CreateMicrosoftTeamsApplication < ActiveRecord::Migration
  shard :all
  def up
    Integrations::Application.create(
      name: 'microsoft_teams',
      display_name: 'integrations.microsoft_teams.label',
      description: 'integrations.microsoft_teams.desc',
      listing_order: 51,
      options: {
        direct_install: true,
        auth_url: '/integrations/teams/oauth',
        after_create: { method: 'add_teams', clazz: 'IntegrationServices::Services::MicrosoftTeamsService' },
        after_destroy: { method: 'remove_teams', clazz: 'IntegrationServices::Services::MicrosoftTeamsService' }
      },
      application_type: 'microsoft_teams',
      account_id: Integrations::Constants::SYSTEM_ACCOUNT_ID
    )
  end

  def down
    Integrations::Application.find_by_name('microsoft_teams').destroy
  end
end
