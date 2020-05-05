module StatusChoiceBuilder
  include Admin::TicketFieldConstants
  include Admin::TicketFields::CommonHelper

  def modify_existing_status_choice(ticket_status, choice)
    choice[:archived] = true if choice[:deleted].present?
    return if archive_data(ticket_status, choice)

    custom_choice = choice.dup
    custom_choice.delete(:id)
    # If position is passed in args use it or use the existing position.
    custom_choice[:position] ||= ticket_status.position
    group_ids = custom_choice.delete(:group_ids)
    archive_data(custom_choice, choice)
    ticket_status.assign_attributes(build_params(STATUS_CHOICES_PARAMS, custom_choice))
    update_status_groups(ticket_status, group_ids) if group_ids.is_a?(Array)
  end

  def create_new_status_choice(ticket_field, choice, last_status_id)
    custom_choice = choice.dup
    custom_choice.delete(:id)
    custom_choice[:position] ||= 1 # add into top if not there
    group_ids = custom_choice.delete(:group_ids)
    ticket_status = ticket_field.ticket_statuses_with_groups.build(build_params(STATUS_CHOICES_PARAMS, custom_choice))
    ticket_status.status_id = last_status_id
    update_status_groups(ticket_status, group_ids) if group_ids.is_a?(Array)
  end

  def update_status_choices(record, choices)
    status_choices = record.ticket_statuses_with_groups.group_by(&:status_id)
    last_status_id = status_choices.values.flatten.max_by(&:status_id).status_id
    choices.each do |each_choice|
      ticket_status = status_choices[each_choice[:id]] && status_choices[each_choice[:id]].first
      if ticket_status.present?
        modify_existing_status_choice(ticket_status, each_choice)
      else
        last_status_id += 1
        create_new_status_choice(record, each_choice, last_status_id)
      end
    end
  end

  def update_status_groups(ticket_status, group_ids)
    group_ids.sort!
    select_valid_group = proc do |status_group|
      group_ids.bsearch { |gr_id| status_group.group_id <=> gr_id }.present?
    end
    if group_ids.present?
      ticket_status.status_groups.reject(&select_valid_group).each(&:mark_for_destruction)
      group_ids -= ticket_status.status_groups.select(&select_valid_group).map(&:group_id)
      group_ids.each { |id| ticket_status.status_groups.build(group_id: id) }
    else
      ticket_status.status_groups.each(&:mark_for_destruction)
    end
  end
end
