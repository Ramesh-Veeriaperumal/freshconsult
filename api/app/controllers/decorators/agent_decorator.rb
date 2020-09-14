class AgentDecorator < ApiDecorator
  include Gamification::GamificationUtil
  include AgentConstants

  def initialize(record, options)
    super(record)
    @user_info = options[:include]
    @group_mapping_ids = options[:group_mapping_ids]
    @is_assumed_user = options[:is_assumed_user]
  end

  def to_hash
    User.current.privilege?(:manage_users) ? agent_hash : to_restricted_hash
  end

  def agent_hash
    agent_info = {
      available: record.available,
      show_rr_toggle: record.toggle_availability?,
      latest_notes_first: Account.current.latest_notes_first_enabled?(record.user),
      occasional: record.occasional,
      id: record.user_id,
      ticket_scope: record.ticket_permission,
      signature: record.signature_html,
      group_ids: group_ids,
      role_ids:  record.user.role_ids,
      skill_ids: record.user.skill_ids,
      available_since: record.active_since.try(:utc),
      contact: ContactDecorator.new(record.user, {}).to_agent_hash,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      last_active_at: record.last_active_at.try(:utc),
      gdpr_admin_name: record.user.current_user_gdpr_admin,
      type: Account.current.agent_types_from_cache.find { |type| type.agent_type_id == record.agent_type }.name,
      read_only: record.user.privilege?(:manage_account)
    }
    if Account.current.freshcaller_enabled?
      agent_info[:freshcaller_agent] = record.freshcaller_agent.present? ? record.freshcaller_agent.try(:fc_enabled) : false
    end
    agent_info[:contribution_group_ids] = record.agent_contribution_group_ids if Account.current.advanced_ticket_scopes_enabled? && !record.field_agent_check_using_cache?
    agent_info[:freshchat_agent] = record.agent_freshchat_enabled? if Account.current.omni_chat_agent_enabled?
    agent_info.merge!(gamification_options)
    agent_info
  end

  def to_privilege_hash
    {
      id: record.id,
      contact: {
        name: record.name,
        email: record.email
      }
    }
  end

  def to_full_hash
    [agent_hash, additional_agent_info, gamification_options, socket_authentication_hash].inject(&:merge)
  end

  def to_restricted_hash
    user_obj = user_object
    type = user_object.agent ? Account.current.agent_types_from_cache.find { |type|
      type.agent_type_id == user_object.agent.agent_type
    }.name : Agent::SUPPORT_AGENT

    restricted_hash = {
      id: user_obj.id,
      contact: {
        name: user_obj.name,
        email: user_obj.email
      },
      group_ids: group_ids,
      type: type
    }
    restricted_hash[:contact].merge!(ContactDecorator.new(record.user, {}).to_hash) if @user_info
    restricted_hash
  end

  def socket_authentication_hash
    authentication_hash = {}
    if Account.current.features?(:collision)
      authentication_hash[:collision_user_hash] = socket_auth_params('agentcollision')
    end
    if Account.current.auto_refresh_enabled?
      authentication_hash[:autorefresh_user_hash] = socket_auth_params('autorefresh')
    end
    authentication_hash
  end

  def group_ids
    (@group_mapping_ids || record.agent_groups.map(&:group_id) || []).compact.uniq
  end

  def agent_achievements_hash
    return {} unless gamification_feature?(Account.current)

    next_level = record.next_level || Account.current.scoreboard_levels.next_level_for_points(record.points.to_i).first
    points_needed = next_level.points - record.points.to_i if next_level

    {
      id: record.user_id,
      points: record.points.to_i,
      current_level_name: record.level.try(:name),
      next_level_name: next_level.try(:name),
      points_needed: (points_needed || 0),
      badges: record.user.quests.order('`achieved_quests`.`created_at` DESC').pluck(:badge_id)
    }
  end

  def availability_hash(all_agent_channels_hash)
    agent_hash.merge!(all_agent_channels_hash)
  end

  def preferences_list
    record.preferences
  end

  def self.availability_count(availability_count)
    return unless availability_count.is_a? Hash

    OmniChannelRouting::Constants::OMNI_CHANNELS.each_with_object([]) do |channel, array|
      array << { channel: channel, count: availability_count[channel] || 0 }
    end
  end

  def channel_agents_availability_data
    return record if Account.current.agent_statuses_enabled?

    channels_data = channel_availabilities.each_with_object([]) do |(channel, hash), array|
      array << hash.merge!(channel: channel, availability_updated_at: hash[:availability_updated_at] ||= nil)
    end
    availability_ocr_response = {
      id: record['freshdesk_user_id'],
      contact: {
        name: record['name']
      },
      availability: {
        channel_availability: channels_data
      }
    }
    availability_ocr_response[:availability][:status] = { id: record['status_id'] } if record['status_id'].present?
    availability_ocr_response
  end

  private

    def additional_agent_info
      {
        last_active_at:       record.last_active_at.try(:utc),
        is_assumed_user:      @is_assumed_user,
        abilities:            record.user.abilities,
        preferences:          record.preferences
      }
    end

    def gamification_options
      return {} unless gamification_feature?(Account.current)
      { points: record.points,
        agent_level_id: record.scoreboard_level_id,
        next_level_id: record.next_level.try(:id) }
    end

    def user_object
      record.is_a?(User) ? record : record.user
    end

    def socket_auth_params(connection)
      aes = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
      aes.encrypt
      aes.key = Digest::SHA256.digest(NodeConfig[connection]['key'])
      aes.iv  = NodeConfig[connection]['iv']
      user_obj = user_object
      account_data = {
        account_id: user_obj.account_id,
        user_id: user_obj.id,
        avatar_url: user_obj.avatar_url
      }.to_json
      encoded_data = Base64.encode64(aes.update(account_data) + aes.final)
      encoded_data
    end

    def channel_availabilities
      record.each_with_object(Hash.new { |h, k| h[k] = {} }) do |(ocr_key, ocr_val), hash|
        if ocr_key == 'on_call'
          hash[:freshcaller][ocr_key.to_sym] = ocr_val
          next
        end
        channel, key = ocr_key.split('_', 2)
        next unless OmniChannelRouting::Constants::OMNI_CHANNELS.include?(channel)

        formatted_key = FORMATTED_OCR_KEYS[key]
        formatted_val = CHANNELS_BOOLEAN_KEYS.include?(formatted_key) ? ocr_val.to_s.to_bool : ocr_val
        hash[channel.to_sym][formatted_key] = formatted_val if formatted_key.present?
      end
    end
end
