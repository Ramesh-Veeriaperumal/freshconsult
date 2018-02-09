class CreateGoogleHangoutChatApplication < ActiveRecord::Migration
  shard :all

  def up
    Integrations::Application.create(
        name: 'google_hangout_chat',
        display_name: 'integrations.google_hangout_chat.label',
        description: 'integrations.google_hangout_chat.desc',
        listing_order: 52,
        options: {
            direct_install: true,
            auth_url: '/integrations/google_hangout_chat/oauth',
            after_create: {method: 'add_chat', clazz: 'IntegrationServices::Services::GoogleHangoutChatService'},
            after_destroy: {method: 'remove_chat', clazz: 'IntegrationServices::Services::GoogleHangoutChatService'}
        },
        application_type: 'google_hangout_chat',
        account_id: Integrations::Constants::SYSTEM_ACCOUNT_ID
    )
  end

  def down
    Integrations::Application.find_by_name('google_hangout_chat').destroy
  end
end
