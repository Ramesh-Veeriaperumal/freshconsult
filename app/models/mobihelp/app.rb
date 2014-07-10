class Mobihelp::App < ActiveRecord::Base
  include ApplicationHelper

  set_table_name :mobihelp_apps
  concerned_with :associations, :callbacks, :constants, :validations
  serialize :config, Hash
  attr_protected :account_id
  
  belongs_to_account

  def push_notification_enabled?
    self.config[:push_notification].eql? 'true'
  end
end
