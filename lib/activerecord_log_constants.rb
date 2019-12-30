module ActiverecordLogConstants
  UPDATE_QUERY_SIZE = 'UPDATE `'.size
  COLUMN_MODEL_NAME_HASH = {
    'users': {
      columns: ['`crypted_password`', '`password_salt`', '`persistence_token`', '`perishable_token`', '`single_access_token`'],
      model_name: 'User'
    },
    'admin_users': {
      columns: ['`password_salt`', '`crypted_password`', '`perishable_token`', '`persistence_token`'],
      model_name: 'AdminUser'
    },
    'user_emails': {
      columns: ['`perishable_token`'],
      model_name: 'UserEmail'
    },
    'sync_accounts': {
      columns: ['`oauth_token`'],
      model_name: 'Integrations::SyncAccount'
    },
    'social_facebook_pages': {
      columns: ['`access_token`', '`page_token`'],
      model_name: 'Social::FacebookPage'
    },
    'social_twitter_handles': {
      columns: ['`access_token`', '`access_secret`'],
      model_name: 'Social::TwitterHandle'
    },
    'installed_applications': {
      columns: ['`configs`'],
      model_name: 'Integrations::InstalledApplication'
    },
    'active_account_jobs': {
      columns: ['`handler`'],
      model_name: 'Active::Job'
    },
    'mailbox_jobs': {
      columns: ['`handler`'],
      model_name: 'Mailbox::Job'
    },
    'premium_account_jobs': {
      columns: ['`handler`'],
      model_name: 'Premium::Job'
    },
    'free_account_jobs': {
      columns: ['`handler`'],
      model_name: 'Free::Job'
    },
    'delayed_jobs': {
      columns: ['`handler`'],
      model_name: 'Delayed::Job'
    },
    'trial_account_jobs': {
      columns: ['`handler`'],
      model_name: 'Trial::Job'
    }
  }.freeze
end.freeze
