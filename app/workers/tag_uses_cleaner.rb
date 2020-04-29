# Class to destroy tag uses after tag destroy to trigger callbacks to ES
#
class TagUsesCleaner
  include Sidekiq::Worker

  TICKET_KLASS = 'Helpdesk::Ticket'.freeze

  sidekiq_options queue: :tag_uses_destroy, retry: 2, failures: :exhausted

  def perform(args)
    args.symbolize_keys!

    condition = { tag_id: args[:tag_id] }
    condition[:taggable_type] = args[:taggable_type] if args[:taggable_type]
    tag_name = args[:tag_name] || Account.current.tags.find(args[:tag_id]).name
    options = { manual_publish: true, model_changes: { tags: { added: [], removed: [tag_name] } }, routing_key: RabbitMq::Constants::RMQ_TICKET_TAG_USE_KEY }
    if args[:doer_id].present?
      options[:doer_id] = args[:doer_id]
      Account.current.users.find(args[:doer_id]).make_current
    end
    Account.current.tag_uses.where(condition).find_in_batches(batch_size: 300) do |tag_uses|
      ticket_ids = []
      tag_uses.each do |tag_use|
        ticket_ids << tag_use.taggable_id if tag_use.taggable_type == TICKET_KLASS
        tag_use.destroy
      end
      UpdateAllPublisher.perform_async(klass_name: TICKET_KLASS, ids: ticket_ids, options: options) if ticket_ids.present?
    end
  ensure
    User.reset_current_user
  end
end
