# NOTE: This is NOT a traditional ActiveRecord based model, it fetches, stores and transforms the ticket reply draft data in redis.
class TicketDraft
  include Redis::RedisKeys
  include Redis::TicketsRedis

  FIELDS = [:body, :cc_emails, :bcc_emails, :from_email, :attachment_ids, :saved_at].freeze

  REDIS_MAX_ATTEMPTS = 3

  FIELDS.each do |attribute|
    define_method attribute do
      fetch unless @loaded
      instance_variable_get("@#{attribute}")
    end
  end

  def initialize(ticket_id)
    @ticket_id = ticket_id
    @loaded = false
  end

  def build(params)
    params.each_pair do |key, value|
      instance_variable_set("@#{key}", value) if (FIELDS - [:saved_at]).include?(key.to_sym)
    end
  end

  def save
    @loaded = true
    count = 0
    begin
      set_tickets_redis_hash_key(draft_key, to_hash)
    rescue Exception => e
      NewRelic::Agent.notice_error(e, key: draft_key, value: to_hash, description: 'Redis issue', count: count)
      retry if (count += 1) < REDIS_MAX_ATTEMPTS
      return false
    end
    true
  end

  def clear
    remove_tickets_redis_key(draft_key)
  end

  def exists?
    fetch unless @loaded
    FIELDS.each do |field|
      return true unless instance_variable_get("@#{field}").nil?
    end
    false
  end

  private

    def fetch
      map_hash_to_attributes(get_tickets_redis_hash_key(draft_key))
      @loaded = true
    end

    def map_hash_to_attributes(draft_hash)
      if draft_hash.present?
        @body = draft_hash['draft_data']
        @cc_emails = draft_hash['draft_cc'].split(';')
        @bcc_emails = draft_hash['draft_bcc'].split(';')
        @from_email = draft_hash['draft_from']
        @attachment_ids = draft_hash['draft_attachment_ids'].split(';')
        @saved_at = Time.at(draft_hash['saved_at'].to_i).utc.iso8601 if draft_hash['saved_at']
      end
    end

    def to_hash
      @draft_hash ||= {
        'draft_data' => @body,
        'draft_cc' => (@cc_emails || []).join(';'),
        'draft_bcc' => (@bcc_emails || []).join(';'),
        'draft_from' => @from_email || '',
        'draft_attachment_ids' => (@attachment_ids || []).join(';'),
        'saved_at' => Time.now.to_i
      }
    end

    def draft_key
      HELPDESK_REPLY_DRAFTS % { account_id: Account.current.id, user_id: User.current.id, ticket_id: @ticket_id }
    end
end
