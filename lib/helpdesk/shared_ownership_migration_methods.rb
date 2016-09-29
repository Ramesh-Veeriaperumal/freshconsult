module Helpdesk::SharedOwnershipMigrationMethods

  def nullify_internal_fields(account = Account.current)
    not_null_conditions = "#{Helpdesk::SchemaLessTicket.internal_group_column} IS NOT NULL OR #{Helpdesk::SchemaLessTicket.internal_agent_column} IS NOT NULL"
    update_conditions = {Helpdesk::SchemaLessTicket.internal_group_column => nil, Helpdesk::SchemaLessTicket.internal_agent_column => nil }
    count = account.schema_less_tickets.where(not_null_conditions).update_all_with_publish(update_conditions, {})
    Rails.logger.debug "Nullifying internal agent and internal group columns : No of records affected => #{count}"
  end

  def remove_launch_party_feature(account = Account.current)
    account.rollback(:shared_ownership) if account.launched?(:shared_ownership)
  end

  def add_launch_party_feature(account = Account.current)
    account.launch(:shared_ownership)
  end

  def remove_feature(account = Account.current)
    account.features.shared_ownership.destroy
  end

  def add_feature(account = Account.current)
    account.features.shared_ownership.create
  end

  def delete_internal_fields(account = Account.current)
    account.ticket_fields.where(:type => [:default_internal_group, :default_internal_agent]).destroy_all
  end

  def add_internal_fields(account = Account.current)
    ticket_fields = account.ticket_fields
    agent_position = ticket_fields.select{|tf| tf.field_type == "default_agent"}.first.position
    ticket_fields.create!([
      {
        :name => "internal_group",
        :label => "Internal Group",
        :description => "Select the Internal group",
        :active => true,
        :field_type => "default_internal_group",
        :required => false,
        :visible_in_portal => false,
        :editable_in_portal => false,
        :required_in_portal => false,
        :required_for_closure => false,
        :default => true,
        :position => agent_position+1,
        :field_options => {}
      },
      {
        :name => "internal_agent",
        :label => "Internal Agent",
        :description => "Select the Internal agent",
        :active => true,
        :field_type => "default_internal_agent",
        :required => false,
        :visible_in_portal => false,
        :editable_in_portal => false,
        :required_in_portal => false,
        :required_for_closure => false,
        :default => true,
        :position => agent_position+2,
        :field_options => {}
      }
      ])
  end

  def migrate_views_with_internal_fiels(account = Account.current)
    # account.ticket_filters.find_in_batches(:batch_size => 50) do |filters|
    #   filters.each do |filter|
    #     changed = false
    #     params = HashWithIndifferentAccess.new
    #     params[:data] = data = filter.data
    #     data[:data_hash].each do |data_hash|
    #       if TicketConstants::SHARED_AGENT_COLUMNS_ORDER.include?(data_hash["condition"])
    #         puts "condition = #{data_hash.inspect}"
    #         data_hash["condition"] = "responder_id"
    #         changed = true
    #       elsif TicketConstants::SHARED_GROUP_COLUMNS_ORDER.include?(data_hash["condition"])
    #         data_hash["condition"] = "group_id"
    #         changed = true
    #       end
    #     end
    #     puts "data_hash = #{filter.data[:data_hash].inspect}"  if changed
    #     filter.update_attribute(:data, data) if changed
    #   end
    # end
  end


end