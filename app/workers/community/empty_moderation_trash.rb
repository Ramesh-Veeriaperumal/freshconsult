class Community::EmptyModerationTrash < BaseWorker

  sidekiq_options :queue => :empty_moderation_trash, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
     ForumSpam.delete_account_spam
  end
end
