require 'spec_helper'

module SurveyHelper

  def create_survey_handle(ticket, send_while, note=nil)
    s_handle = ticket.survey_handles.build({
      :id_token => Digest::MD5.hexdigest(Helpdesk::SECRET_1 + ticket.id.to_s + 
        Time.now.to_f.to_s).downcase,
      :sent_while => send_while
    })
    s_handle.account_id = ticket.account_id
    s_handle.survey_id = ticket.account.survey.id
    s_handle.response_note_id = note.id if note
    s_handle.save

    s_handle
  end
end