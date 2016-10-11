class Community::ClearModerationRecords < BaseWorker

  sidekiq_options :queue => :clear_moderation_records, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
  	Post::SPAM_SCOPES_DYNAMO.values.each do |scope|
      if args[:obj_class] == "Forum"
        records = scope.last_month
        while records.present?
          last = records.last_evaluated_key
          records.each { |r| r.destroy if r.topic_id.nil? && r.forum_id == args[:obj_id] }
          records = last ? scope.next(last) : []
        end
        (args[:topic_ids] || []).each { |topic_id| scope.delete_topic_spam(topic_id) }
      else
        scope.delete_topic_spam(args[:obj_id])
      end
    end
  end
end
