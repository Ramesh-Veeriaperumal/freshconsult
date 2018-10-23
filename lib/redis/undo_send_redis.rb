module Redis::UndoSendRedis
  include Redis::RedisKeys
  include Redis::TicketsRedis

  UNDO_SEND_REDIS_DELIMITERS = ['body', 'body_html', 'full_text', 'full_text_html'].freeze
  UNDO_SEND_FALSE = 'false'.freeze

  def get_body_data(user_id, ticket_id, created_at)
    key = get_body_key(user_id, ticket_id, created_at)
    get_tickets_redis_hash_key(key)
  end

  def set_body_data(user_id, ticket_id, created_at, note_body)
    key = get_body_key(user_id, ticket_id, created_at)
    UNDO_SEND_REDIS_DELIMITERS.each do |delimiter|
      $redis_tickets.perform_redis_op('hset', key, delimiter, note_body[delimiter])
    end
  end

  def delete_body_data(user_id, ticket_id, created_at)
    key = get_body_key(user_id, ticket_id, created_at)
    remove_tickets_redis_key(key)
  end

  def undo_send_enqueued(user_id, ticket_id, created_at, jobid)
    key = get_undo_key(user_id, ticket_id, created_at)
    set_tickets_redis_key(key, jobid)
  end

  def set_worker_choice_false(user_id, ticket_id, created_at)
    key = get_undo_key(user_id, ticket_id, created_at)
    set_tickets_redis_key(key, UNDO_SEND_FALSE)
  end

  def get_undo_option(user_id, ticket_id, created_at)
    key = get_undo_key(user_id, ticket_id, created_at)
    get_tickets_redis_key(key)
  end

  def delete_undo_choice(user_id, ticket_id, created_at)
    key = get_undo_key(user_id, ticket_id, created_at)
    remove_tickets_redis_key(key)
  end

  def get_reply_template_content(user_id, ticket_id, created_at)
    key = get_body_key(user_id, ticket_id, created_at)
    $redis_tickets.perform_redis_op('hget', key, 'body_html')
  end

  def get_quoted_content(user_id, ticket_id, created_at)
    key = get_body_key(user_id, ticket_id, created_at)
    $redis_tickets.perform_redis_op('hget', key, 'full_text_html')
  end

  def undo_send_msg_enqueued?(ticket_id)
    key = get_enqueued_key(ticket_id)
    get_tickets_redis_key(key)
  end

  def enqueue_undo_send_traffic_cop_msg(ticket_id, user_id)
    key = get_enqueued_key(ticket_id)
    set_tickets_redis_key(key, user_id)
  end

  def remove_undo_send_traffic_cop_msg(ticket_id)
    key = get_enqueued_key(ticket_id)
    remove_tickets_redis_key(key)
  end

  def get_body_key(user_id, ticket_id, created_at)
    format(UNDO_SEND_BODY_KEY, account_id: ::Account.current.id, user_id: user_id, ticket_id: ticket_id, created_at: created_at)
  end

  def get_undo_key(user_id, ticket_id, created_at)
    format(UNDO_SEND_KEY, account_id: ::Account.current.id, user_id: user_id, ticket_id: ticket_id, created_at: created_at)
  end

  def get_enqueued_key(ticket_id)
    format(UNDO_SEND_REPLY_ENQUEUE, account_id: ::Account.current.id, ticket_id: ticket_id)
  end
end
