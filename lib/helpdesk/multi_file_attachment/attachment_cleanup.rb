class Helpdesk::MultiFileAttachment::AttachmentCleanup
  include Helpdesk::MultiFileAttachment::Util
  def initialize(args)
    args.symbolize_keys!
    @key = user_draft_redis_key(args[:cleanup_date])
  end

  def cleanup
    account_hash_group = Hash.new { |hash, key| hash[key] = [] }
    get_all_members_in_a_redis_set(@key).map{|val| val.split(":")}.each{ |x,y| account_hash_group[x.to_i] << y.to_i }
    account_hash_group.each do |key, val|
      destroy_attachments(key,val) unless val.empty?
    end
  ensure
    stale_attachments = get_all_members_in_a_redis_set(@key)
    if stale_attachments.empty?
      remove_others_redis_key(@key)
    else
      puts "** Not all stale attachments got cleaned up. Remaining attachments : #{stale_attachments.inspect} **"
      Rails.logger.debug "** Not all stale attachments got cleaned up. Remaining attachments : #{stale_attachments.inspect} **"
      notification_topic = SNS["freshdesk_team_notification_topic"]
      options = { :environment => Rails.env, :key => @key }
      DevNotification.publish(notification_topic, "Issue with attachment cleanup - Not all stale attachments got cleaned up", options.to_json)
    end
  end

  private

    def destroy_attachments account_id, attachment_list
      Sharding.admin_select_shard_of account_id do
        account = Account.find_by_id(account_id).make_current
        account.attachments.find_each(:conditions => {:id => attachment_list}) do |attach|
          attachment_list.delete(attach.id)
          destroy_attachment(attach, account_id)
        end
        attachment_list.each do |attachment_id|
          remove_member_from_redis_set(@key, construct_set_value(attachment_id, account_id))
        end
      end
    rescue => e
      puts "** Something went wrong when destroying stale attachments. ** #{e.inspect} **"
      NewRelic::Agent.notice_error(e)
    ensure
      Account.reset_current_account
    end

    def destroy_attachment attach, account_id
      attach.destroy if Helpdesk::Attachment::DRAFT_ATTACHMENTS.include?(attach.attachable_type)
      remove_member_from_redis_set(@key, construct_set_value(attach.id, account_id))
    rescue => e
      puts "** Something went wrong when destroying stale attachment #{attach.inspect}. ** #{e.inspect} **"
      NewRelic::Agent.notice_error(e)
    end
end
