# frozen_string_literal: true

module PrivilegesModificationTestHelper
  def enable_custom_objects
    Account.current.add_feature(:custom_objects)
    ::PrivilegesModificationWorker.new.perform(feature: 'custom_objects')
  end

  def disable_custom_objects
    Account.current.revoke_feature(:custom_objects)
    ::PrivilegesModificationWorker.new.perform(feature: 'custom_objects')
  end
end
