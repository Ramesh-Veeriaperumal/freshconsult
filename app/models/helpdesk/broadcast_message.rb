class Helpdesk::BroadcastMessage < ActiveRecord::Base
  self.table_name =  "helpdesk_broadcast_messages"
  self.primary_key = :id

  belongs_to_account
  belongs_to :note, :class_name => 'Helpdesk::Note',:foreign_key => 'note_id', :readonly => true,
             :conditions => {:private => true, :category => Helpdesk::Note::CATEGORIES[:broadcast]}

  attr_protected :account_id

  after_commit :send_notifications, on: :create

  private

    def send_notifications
      BroadcastMessages::NotifyBroadcastMessages.perform_async({
        tracker_display_id: self.tracker_display_id,
        broadcast_id: self.id })
    end

end
