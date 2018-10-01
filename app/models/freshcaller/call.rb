module Freshcaller
  class Call < ActiveRecord::Base
    self.table_name =  :freshcaller_calls
    self.primary_key = :id

    belongs_to_account

    belongs_to :ticket, foreign_key: 'notable_id', class_name: 'Helpdesk::Ticket'
    belongs_to :note, foreign_key: 'notable_id', class_name: 'Helpdesk::Note'

    belongs_to :notable, polymorphic: true, validate: true

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
  end
end
