module Freshcaller
  class Call < ActiveRecord::Base
    self.table_name =  :freshcaller_calls
    self.primary_key = :id

    belongs_to_account
    # concerned_with :presenter

    belongs_to :ticket, foreign_key: 'notable_id', class_name: 'Helpdesk::Ticket'
    belongs_to :note, foreign_key: 'notable_id', class_name: 'Helpdesk::Note'

    belongs_to :notable, polymorphic: true, validate: true

    serialize :call_info, Hash

    scope :recording_with_call_id, -> (call_id) { where(fc_call_id: call_id, recording_status: RECORDING_STATUS_HASH.values_at(:'in-progress', :completed)) }

    validates :fc_call_id, uniqueness: true

    RECORDING_STATUS_HASH = {
      invalid: 0,
      'in-progress': 1,
      completed: 2,
      deleted: 3
    }

    RECORDING_STATUS_NAMES_BY_KEY = RECORDING_STATUS_HASH.invert

    RECORDING_STATUS_HASH.each_pair do |k, v|
      define_method("recording_#{k.to_s.gsub(/\W/, '')}?") do
        recording_status == v
      end
    end

    def ticket_display_id
      return notable.display_id if notable_id.present? && notable_type.eql?('Helpdesk::Ticket')
      return notable.notable.display_id if notable_id.present? && notable_type.eql?('Helpdesk::Note')
    end

    def note_id
      notable_id if notable_id.present? && notable_type.eql?('Helpdesk::Note')
    end

    def associated_ticket
      return if notable_type.blank?
      return ticket if ticket_notable?
      note.notable
    end

    def ticket_notable?
      notable_type == "Helpdesk::Ticket"
    end
  end
end
