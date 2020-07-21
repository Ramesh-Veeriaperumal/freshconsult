module QualityManagementSystem
  class PerformQmsOperationsWorker < BaseWorker
    include ::RoleConstants
    sidekiq_options queue: :quality_management_system, retry: 0, backtrace: true

    def perform
      @account = Account.current
      @account.quality_management_system_enabled? ? perform_operations_on_qms_enable : perform_operations_on_qms_disable
    rescue StandardError => e
      Rails.logger.error "Error in PerformQmsOperationsWorker::Exception::  A - #{@account.id} #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Error in PerformQmsOperationsWorker::Exception:: #{e.message}")
    end

    private

      def create_coach_role
        coach_role = Helpdesk::Roles::COACH_ROLE
        return if @account.roles.map(&:name).include?(coach_role[:name])

        role = @account.roles.build(coach_role)
        role.save!
      end

      def destroy_coach_role
        @account.roles.coach.destroy_all
      end

      def add_qms_privileges_to_admin_roles
        @account.roles.each do |role|
          next unless role.privilege?(:admin_tasks)

          role.privilege_list = (role.abilities + QMS_ADMIN_PRIVILEGES).flatten
          role.save
        end
      end

      def add_qms_privileges_to_agent_roles
        @account.roles.each do |role|
          next if role.privilege?(:admin_tasks)

          role.privilege_list = (role.abilities + QMS_AGENT_PRIVILEGES).flatten
          role.save
        end
      end

      def remove_qms_privileges_from_admin_roles
        @account.roles.each do |role|
          next unless role.privilege?(:admin_tasks)

          role.privilege_list = (role.abilities - QMS_ADMIN_PRIVILEGES).flatten
          role.save
        end
      end

      def remove_qms_privileges_from_agent_roles
        @account.roles.each do |role|
          next unless role.privilege?(:view_scores)

          role.privilege_list = (role.abilities - QMS_AGENT_PRIVILEGES).flatten
          role.save
        end
      end

      def perform_operations_on_qms_enable
        create_coach_role
        add_qms_privileges_to_admin_roles
        add_qms_privileges_to_agent_roles
      end

      def perform_operations_on_qms_disable
        destroy_coach_role
        remove_qms_privileges_from_admin_roles
        remove_qms_privileges_from_agent_roles
      end
  end
end
