# frozen_string_literal: true

class Helpdesk::NoteBody < ActiveRecord::Base
  self.table_name = 'helpdesk_note_bodies'
  self.primary_key = :id

  belongs_to_account
  belongs_to :note, class_name: 'Helpdesk::Note', foreign_key: :note_id, inverse_of: :note_body

  attr_accessor :redaction_processed

  before_validation :redact_content, if: -> { !redaction_processed }

  attr_protected :account_id

  REDACTABLE_FIELDS = ['body_html', 'body', 'full_text', 'full_text_html'].freeze

  def redact_content
    if note.redactable?
      redaction_data = (REDACTABLE_FIELDS & changes.keys).map { |field| safe_send(field) }
      Redaction.new(data: redaction_data, configs: Account.current.active_redaction_configs).redact!
    end
    self.redaction_processed = true
  end
end
