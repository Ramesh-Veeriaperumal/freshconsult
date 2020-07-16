# frozen_string_literal: true

class PrivilegesModificationWorker < BaseWorker
  sidekiq_options queue: :privilege_modification, retry: 0, backtrace: true

  def perform(args)
    @account = Account.current
    feature = args.with_indifferent_access[:feature]
    @account.safe_send("#{feature}_enabled?") ? safe_send("add_#{feature}_privileges") : safe_send("remove_#{feature}_privileges")
  rescue StandardError => e
    Rails.logger.error "Error in PrivilegesModificationWorker::Exception::  A - #{@account.id} #{e.message}"
    NewRelic::Agent.notice_error(e, description: "Error in PrivilegesModificationWorker::Exception:: #{e.message}")
  end

  private

    def add_custom_objects_privileges
      @account.roles.each do |role|
        next unless role.privilege?(:admin_tasks)

        role.privilege_list = (role.abilities + [:manage_custom_objects]).flatten
        role.save
      end
    end

    def remove_custom_objects_privileges
      @account.roles.each do |role|
        next unless role.privilege?(:manage_custom_objects)

        role.privilege_list = (role.abilities - [:manage_custom_objects]).flatten
        role.save
      end
    end
end
