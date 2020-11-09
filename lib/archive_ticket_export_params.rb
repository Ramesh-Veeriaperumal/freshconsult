module ArchiveTicketExportParams
  TICKET_STATE_FIELDS = ['resolved_at', 'closed_at', 'first_response_time', 'first_resp_time_by_bhrs',
                         'resolution_time_by_bhrs', 'outbound_count', 'inbound_count', 'assigned_at'].freeze
  
  def requester_info
    requester.get_info if requester
  end

  def requester_phone
    (requester_has_phone?)? requester.phone : requester.mobile if requester
  end

  def not_editable?
    requester and !requester_has_email? and !requester_has_phone?
  end
  
  def requester_has_email?
    (requester) and (requester.email.present?)
  end

  def requester_has_phone?
    requester and requester.phone.present?
  end

  def requester_fb_profile_id
    requester.fb_profile_id
  end

  def due_by
    ticket = archive_ticket_association.association_data["helpdesk_tickets"]
    ticket["due_by"] if ticket.present?
  end

  def frDueBy
    ticket = archive_ticket_association.association_data["helpdesk_tickets"]
    ticket["frDueBy"] if ticket.present?
  end

  TICKET_STATE_FIELDS.each do |ticket_field|
    define_method "#{ticket_field}" do
      ticket_states = helpdesk_tickets_association["ticket_states"]
      ticket_states[ticket_field] if ticket_states
    end
  end

  def first_res_time_bhrs
    hhmm(first_resp_time_by_bhrs)
  end

  def resolution_time_bhrs
    hhmm(resolution_time_by_bhrs)
  end

  def service_task?
    ticket_type == Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE
  end

  def resolution_status
    return '' if service_task?

    resolved_at.nil? ? "" : ((resolved_at < due_by) ? I18n.t('export_data.in_sla') : I18n.t('export_data.out_of_sla'))
  end

  def first_response_status
    # skipping first response status for service task as frDueBy is null for service tasks
    return '' if service_task? || first_response_time.nil?

    first_response_time < frDueBy ? I18n.t('export_data.in_sla') : I18n.t('export_data.out_of_sla')
  end

  def tag_names
    tags.collect { |tag| tag.name }
  end

  def ticket_tags
    tag_names.join(',')
  end

  def ticket_survey_results
    if Account.current.new_survey_enabled?
      custom_survey_results.sort_by(&:id).last.try(:text)
    else
      survey_results.sort_by(&:id).last.try(:text)
    end
  end

  def time_tracked
    time_sheets.map(&:running_time).sum
  end

  def time_tracked_hours
    round_off_time_hrs(time_tracked)
  end

  def hhmm(seconds)
    seconds = 0 if seconds.nil?
    hh = (seconds/3600).to_i
    mm = ((seconds % 3600) / 60).to_i
    ss = (seconds % 60).to_i
    "#{hh.to_s.rjust(2,'0')}:#{mm.to_s.rjust(2,'0')}:#{ss.to_s.rjust(2,'0')}"
  end

  def round_off_time_hrs seconds
    hh = (seconds/3600).to_i
    mm = ((seconds % 3600)/60.to_f).round

    hh.to_s.rjust(2,'0') + ":" + mm.to_s.rjust(2,'0')
  end

end
