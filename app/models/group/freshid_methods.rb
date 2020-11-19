# frozen_string_literal: true

class Group < ActiveRecord::Base

  def freshid_usergroup_member_class
    Freshid::V2::Models::UsergroupMember
  end

  def freshid_usergroup_class
    Freshid::V2::Models::Usergroup
  end

  def create_freshid_usergroup
    org_domain = Account.current.organisation_from_cache.try(:domain)
    freshid_usergroup = freshid_usergroup_class.create(org_domain, usergroup_info, member_info)
    if freshid_usergroup.blank?
      errors.add(:uid, format(ErrorConstants::ERROR_MESSAGES[:freshid_group_api_failure], action: "create"))
      return false
    end
    self.uid = freshid_usergroup.id if freshid_usergroup.id.present?
    assign_freshchat_settings(freshid_usergroup.config)
    freshid_usergroup
  end

  def delete_freshid_usergroup
    org_domain = Account.current.organisation_from_cache.try(:domain)
    freshid_usergroup_class.delete(org_domain, self.uid.to_s)
  rescue Exception => e
    Rails.logger.info "Freshid group delete API failed :: #{Account.current.id} :: #{self.uid} :: #{e.inspect}"
  end
  
  def find_freshid_usergroup_by_id
    errors.add(:uid, format(ErrorConstants::ERROR_MESSAGES[:freshid_group_api_failure], action: "show")) and return false if self.uid.nil?

    org_domain = Account.current.organisation_from_cache.try(:domain)
    freshid_usergroup = freshid_usergroup_class.find_by_id(org_domain, self.uid)
    unless freshid_usergroup.present?
      errors.add(:uid, format(ErrorConstants::ERROR_MESSAGES[:freshid_group_api_failure], action: "show")) and return false
    end
    assign_freshchat_settings(freshid_usergroup.config)
    freshid_usergroup
  end

  def assign_freshchat_settings(config)
    return if config.nil?

    config = JSON.parse(config).deep_symbolize_keys

    settings = config.try(:[], :automatic_agent_assignment).try(:[], :settings)
    return if settings.nil?

    self.freshchat_settings ||= settings.find { |s| s[:channel] == 'chat' }
  end

  def usergroup_info
    {
      name: name,
      description: description,
      account_id: Account.current.id.to_s,
      bundle_id: Account.current.omni_bundle_id.to_s,
      config: config_hash.to_json
    }
  end

  def config_hash
    {
      business_calendar_id: business_calendar_id,
      automatic_agent_assignment: automatic_agent_assignment_settings
    }
  end

  def member_info
    agents_hash = self.agent_groups.each_with_object([]) do |agent, array|
      array << {
        user_identifier: {
          id: agent.user.freshid_authorization.uid.to_s
        }
      }
    end
    agents_hash
  end
end
