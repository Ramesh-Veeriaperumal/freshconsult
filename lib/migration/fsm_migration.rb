module Migration
  class FsmMigration < Base
    FSM_FIELDS = ['cf_fsm_contact_name', 'cf_fsm_phone_number', 'cf_fsm_service_location', 'cf_fsm_appointment_start_time', 'cf_fsm_appointment_end_time', 'cf_fsm_customer_signature'].freeze
    SERVICE_TASK_SECTION = 'Service task section'.freeze
    SERVICE_TASK_TYPE = 'Service Task'.freeze

    def initialize(options = {})
      super(options)
    end

    def add_fsm_to_field_options(ticket_field)
      ticket_field.field_options[:fsm] = true
      ticket_field.save!
    end

    def run_migration_for_all_accounts
      Sharding.run_on_all_shards do
        Account.active_accounts.find_each do |account|
          account.make_current
          migration_process(account)
        end
      end
    end

    def run_migration_for_single_account(account_id)
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
        account.make_current
        migration_process(account)
      end
    end

    def migration_process(account)
      if account.field_service_management_enabled?
        account.ticket_fields_only.select do |tf|
          next unless (FSM_FIELDS.include? tf.name) && tf.field_options && tf.field_options[:fsm].nil?

          Rails.logger.info "before_save: #{tf.inspect}"
          add_fsm_to_field_options(tf)
          tf.reload!
          Rails.logger.info "after_save: #{tf.inspect}"
        end
        service_task_section = Account.current.sections.find_by_label(SERVICE_TASK_SECTION)
        update_service_task_section(service_task_section)
        update_service_task_picklist_mapping
      end
    rescue StandardError => e
      Rails.logger.info "Account_id: #{Account.current.id} \t error: #{e.inspect} \t backtrace: #{e.backtrace}"
    end

    def run_migration_for_fsm
      @account_id.nil? ? run_migration_for_all_accounts : run_migration_for_single_account(@account_id)
    end

    def update_service_task_section(service_task_section)
      service_task_section.options['fsm'] = true unless service_task_section.options && service_task_section.options['fsm'].nil?
      service_task_section.save!
    end

    def update_service_task_picklist_mapping
      ticket_type_field = Account.current.ticket_fields_with_nested_fields.find_by_field_type('default_ticket_type')
      picklist_value = ticket_type_field.picklist_values.preload(:section_picklist_mapping).find_by_value(SERVICE_TASK_TYPE)
      picklist_value.section_picklist_mapping.picklist_id = picklist_value.picklist_id
      picklist_value.save!
      ticket_type_field.save!
    end
  end
end

# Migration::FsmMigration.new(account_id: 1).run_migration_for_fsm
