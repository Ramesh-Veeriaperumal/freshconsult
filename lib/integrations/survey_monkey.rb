require 'sanitize'

module Integrations::SurveyMonkey
  # CALLED : When survey is sent on reply.
  def self.survey specific_include, ticket, user
    return nil unless enabled?
    s_while = specific_include ? Survey::SPECIFIC_EMAIL_RESPONSE : Survey::ANY_EMAIL_RESPONSE
    installed_app = sm_installed_app
    send_while = installed_app.configs[:inputs]['send_while'].to_i if installed_app
    url = survey_url(installed_app, ticket, user) unless send_while.blank?

    return nil if url.blank? or send_while.blank? or (s_while!=send_while)
    {:link => url, :text => installed_app.configs[:inputs]['survey_text']}
  end

  def self.survey_for_social(ticket, user)
    return nil unless enabled?

    installed_app = sm_installed_app
    url = survey_url(installed_app, ticket, user) if installed_app

    return nil if url.blank?

    url = URI.parse(url).to_s
    "#{installed_app.configs[:inputs]['survey_text']} \n #{url}"
  end

  # CALLED: When survey is sent for ticket status change.
  def self.survey_for_notification notification_type, ticket
    return nil unless enabled?
    installed_app = sm_installed_app
    agent = ticket.responder
    if !agent and notification_type!=Survey::PLACE_HOLDER
      last_note = ticket.notes.visible.agent_public_responses.last
      agent = last_note.user if last_note
    end

    if agent
      url = survey_url(installed_app, ticket, agent)
      send_while = installed_app.configs[:inputs]['send_while'].to_i
    end

    return nil if url.blank? or agent.blank? or send_while.blank? or
    (SurveyHandle::NOTIFICATION_VS_SEND_WHILE[notification_type]!=send_while and
     notification_type!=Survey::PLACE_HOLDER)
    {:link => url, :text => installed_app.configs[:inputs]['survey_text']}
  end

  def self.placeholder_allowed?
    return false unless enabled?

    # Allow the place holder for a canned response when the all groups survey link is configured.
    url = survey_url_by_version(sm_installed_app)
    url.present?
  end

  def self.enabled?
    MemcacheKeys.fetch("surveymonkey_#{Account.current.id}") {
      sm_installed_app.present?
    }
  end

  def self.survey_html ticket
    args = {:survey_handle => nil, :in_placeholder => true,
              :surveymonkey_survey => survey_for_notification(Survey::PLACE_HOLDER, ticket)}
    Account.current.new_survey_enabled? ? CustomSurveyHelper.render_content_for_placeholder(args)
                                        : SurveyHelper.render_content_for_placeholder(args) #ask Murugan
  end

  def self.show_surveymonkey_checkbox?
    return false unless enabled?
    installed_app = sm_installed_app
    send_while = installed_app.configs[:inputs]['send_while'].to_i if installed_app
    return true if send_while and send_while == Survey::SPECIFIC_EMAIL_RESPONSE
    false
  end

  def self.sanitize_survey_text installed_app
    installed_app.configs[:inputs]['survey_text'] = Sanitize.fragment(installed_app.configs[:inputs]['survey_text'],
      Sanitize::Config::BASIC)
    add_api_version installed_app
  end

  def self.add_api_version installed_app
    installed_app.configs[:inputs]['api_version'] = 'V3'
  end

  def self.delete_cached_status installed_app
    MemcacheKeys.delete_from_cache "surveymonkey_#{installed_app.account_id}" if installed_app
  end

  private
  def self.survey_url installed_app, ticket, user
    group_id = ticket.group_id || 0  #0 denotes "All Groups"
    url = construct_url(installed_app, ticket, user, group_id) if installed_app
  end

  def self.construct_url installed_app, ticket, user, group_id
    url = survey_url_by_version(installed_app, group_id)
    if url.present?
      url = "#{url}?c=#{user.name}&fd_ticketid=#{ticket.display_id}"
      url = "#{url}&fd_group=#{ticket.group.name}" if group_id != 0
    end
    url
  end

  def self.survey_url_by_version installed_app, group_id=0
    url = nil
    group_config = installed_app.configs[:inputs]['groups']
    group_id_str = "#{group_id}"

    if group_config #New format - survey/group
      if group_config[group_id_str]
        url = group_config[group_id_str]['survey_link']
      elsif group_config["0"]
        url = group_config["0"]['survey_link']
      end
    else #Old format
      url = installed_app.configs[:inputs]['survey_link']
    end
    url
  end

  def self.sm_installed_app
    Account.current.installed_applications.with_name("#{Integrations::Constants::APP_NAMES[:surveymonkey]}").first
  end

end