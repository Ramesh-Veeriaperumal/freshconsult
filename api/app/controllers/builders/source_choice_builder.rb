module SourceChoiceBuilder
  include Admin::TicketFieldConstants

  def modify_existing_source_choice(ticket_source, choice)
    custom_choice = choice.to_h.symbolize_keys
    custom_choice.delete(:value)
    custom_choice[:deleted] = true if choice[:deleted].present?
    ticket_source.meta.merge!(icon_id: custom_choice.delete(:icon_id)) if custom_choice[:icon_id]
    ticket_source.assign_attributes(build_params(SOURCE_CHOICES_PARAMS, custom_choice))
    unless ticket_source.save
      ErrorHelper.rename_keys({ name: :label }, ticket_source.errors.messages)
      render_errors(ticket_source.errors)
    end
  end

  def create_new_source_choice(choice)
    custom_choice = choice.to_h.symbolize_keys
    custom_choice.delete(:value)
    custom_choice[:default] = false
    custom_choice[:meta] = {}.with_indifferent_access
    custom_choice[:meta].merge!(icon_id: custom_choice.delete(:icon_id)) if custom_choice[:icon_id]
    source_params = build_params(SOURCE_CHOICES_PARAMS, custom_choice)
    new_choice = Account.current.helpdesk_sources.build(source_params)
    unless new_choice.save
      ErrorHelper.rename_keys({ name: :label }, new_choice.errors.messages)
      render_errors(new_choice.errors)
    end
  end

  def handle_source_choices(_ticket_field, choices)
    source_choices = current_account.ticket_source_from_cache.group_by(&:account_choice_id)
    choices.each do |each_choice|
      ticket_source = each_choice[:value] && source_choices[each_choice[:value]].first
      if ticket_source.present?
        modify_existing_source_choice(ticket_source, each_choice)
      else
        create_new_source_choice(each_choice)
      end
    end
  end
end
