class Community::MergeTopicsWorker < BaseWorker

  sidekiq_options :queue => :merge_topics, :retry => 0, :failures => :exhausted


  def perform(args)
    args.symbolize_keys!
    user = User.current
    sources = Account.current.topics.where(id: args[:source_topic_ids]).to_a
    target = Account.current.topics.find(args[:target_topic_id])
    source_note = args[:source_note]
    Community::TopicsMerge.merge_topic(sources,target,user,source_note)
    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})    
  end
    

end