module Redis::ArchiveRedis
  def account_ids_in_shard(current_archive_shard)
    $redis_tickets.perform_redis_op('lrange', current_archive_shard, 0, -1)
  end

  def archive_automation_shards
    $redis_tickets.perform_redis_op('smembers', 'archive_automation_shards')
  end
end
