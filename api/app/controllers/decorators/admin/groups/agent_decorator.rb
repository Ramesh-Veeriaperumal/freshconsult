class Admin::Groups::AgentDecorator < ApiDecorator
  delegate :id, :roles, :agent, to: :record

  def initialize(record, options)
    super(record)
    @write_access_user_ids = options[:write_access_user_ids]
  end

  def to_hash
    agent_info = {
      id: record.id,
      ticket_scope: agent.ticket_permission,
      write_access: @write_access_user_ids.include?(record.id),
      role_ids: roles.map(&:id),
      contact: contact_hash,
      created_at: agent.created_at,
      updated_at: agent.updated_at
    }
    if Account.current.freshcaller_enabled?
      agent_info[:freshcaller_agent] = agent.freshcaller_agent.present? ? agent.freshcaller_agent.try(:fc_enabled) : false
    end
    agent_info[:freshchat_agent] = agent.agent_freshchat_enabled? if Account.current.omni_chat_agent_enabled?
    agent_info
  end

  private

    def contact_hash
      { name: record.name, avatar: avatar_hash }
    end

    def avatar_hash
      avatar = record.avatar
      return {} unless avatar

      AttachmentDecorator.new(avatar).to_hash
    end
end
