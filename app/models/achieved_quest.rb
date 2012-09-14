class AchievedQuest < ActiveRecord::Base

  include Notifications::MessageBroker
  belongs_to_account
  
  belongs_to :user
  belongs_to :quest

  attr_protected :account_id

  after_create :publish_game_notifications

  private
    def publish_game_notifications
      publish("#{I18n.t('gamification.notifications.achieved_quest',:name => quest.name)}", 
        [user_id], quest.badge[:classname]) 
    end

end
