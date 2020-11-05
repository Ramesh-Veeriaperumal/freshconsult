# frozen_string_literal: true

module TicketPresenter::PresenterHelper
  extend ActiveSupport::Concern

  REPORT_FIELDS = [
    :first_assign_by_bhrs, :first_response_id, :first_response_group_id, :first_response_agent_id,
    :first_assign_agent_id, :first_assign_group_id, :agent_reassigned_count, :group_reassigned_count,
    :reopened_count, :private_note_count, :public_note_count, :agent_reply_count, :customer_reply_count,
    :agent_assigned_flag, :agent_reassigned_flag, :group_assigned_flag, :group_reassigned_flag,
    :internal_agent_assigned_flag, :internal_agent_reassigned_flag, :internal_group_assigned_flag,
    :internal_group_reassigned_flag, :internal_agent_first_assign_in_bhrs, :last_resolved_at
  ].freeze
  EMAIL_KEYS = [:cc_emails, :fwd_emails, :bcc_emails, :reply_cc, :tkt_cc].freeze
  DATETIME_FIELDS = [:due_by, :closed_at, :resolved_at, :created_at, :updated_at, :first_response_time, :first_assigned_at, :assigned_at].freeze
  DONT_CARE_VALUE = '*'.freeze

  PRE_COMPUTE_FIELDS = [
    [:id, :id],
    [:display_id, :display_id],
    [:account_id, :account_id],
    [:responder_id, :responder_id],
    [:group_id, :group_id],
    [:status_hash, :status],
    [:priority_hash, :priority],
    [:ticket_type, :ticket_type],
    [:source_hash, :source],
    [:requester_id, :requester_id],
    [:product_id, :product_id],
    [:company_id, :company_id],
    [:sla_policy_id, :sla_policy_id],
    [:isescalated, :is_escalated],
    [:fr_escalated, :fr_escalated],
    [:escalation_level, :resolution_escalation_level],
    [:sla_response_reminded, :response_reminded],
    [:sla_resolution_reminded, :resolution_reminded],
    [:resolution_time_by_bhrs, :time_to_resolution_in_bhrs],
    [:resolution_time_by_chrs, :time_to_resolution_in_chrs],
    [:inbound_count, :inbound_count],
    [:first_resp_time_by_bhrs, :first_response_by_bhrs],
    [:archive, :archive],
    [:internal_agent_id, :internal_agent_id],
    [:internal_group_id, :internal_group_id],
    [:outbound_email?, :outbound_email],
    [:watchers, :watchers],
    [:urgent, :urgent],
    [:spam, :spam],
    [:trained, :trained],
    [:to_emails, :to_emails],
    [:email_config_id, :email_config_id],
    [:deleted, :deleted],
    [:group_users, :group_users],
    [:import_id, :import_id],
    [:on_state_time, :on_state_time],
    [:source_additional_info_hash, :source_additional_info],
    [:status_stop_sla_timer, :status_stop_sla_timer],
    [:status_deleted, :status_deleted]
  ].freeze

  included do |base|
    base.include InstanceMethods

    acts_as_api

    # This is added to send the ticket properties at the time of commit or in otherword to avoid fetching latest data updated by some other thread.
    api_accessible :central_publish_preload do |at|
      PRE_COMPUTE_FIELDS.each do |key, key_as|
        at.add key, as: key_as
      end
      at.add :sl_skill_id, as: :skill_id, if: proc { Account.current.skill_based_round_robin_enabled? }
      at.add :nr_escalated, if: proc { Account.current.next_response_sla_enabled? }
      at.add :nr_reminded, as: :next_response_reminded, if: proc { Account.current.next_response_sla_enabled? }
      at.add proc { |x| x.utc_format(x.parse_to_date_time(x.frDueBy)) }, as: :fr_due_by
      at.add proc { |x| x.utc_format(x.parse_to_date_time(x.nr_due_by)) }, as: :nr_due_by, if: proc { Account.current.next_response_sla_enabled? }
      at.add proc { |x| x.attachments.map(&:id) }, as: :attachment_ids
      at.add proc { |x| x.tags.collect { |tag| { id: tag.id, name: tag.name } } }, as: :tags
      REPORT_FIELDS.each do |key|
        at.add proc { |x| x.reports_hash[key.to_s] }, as: key
      end
      DATETIME_FIELDS.each do |key|
        at.add proc { |x| x.utc_format(x.parse_to_date_time(x.safe_send(key))) }, as: key
      end
      EMAIL_KEYS.each do |key|
        at.add proc { |x| x.cc_email_hash.try(:[], key) }, as: key
      end
    end

    api_accessible :central_publish, extend: :central_publish_preload do |at|
      at.add :central_custom_fields_hash, as: :custom_fields
      at.add :association_hash, as: :associates
      at.add :associates_rdb
      at.add :subject
      at.add proc { |x| x.description }, as: :description_text
      at.add :description_html
    end

    api_accessible :central_publish_associations do |at|
      at.add :requester, template: :central_publish
      at.add :responder, template: :central_publish
      at.add :group, template: :central_publish
      at.add :attachments, template: :central_publish
      at.add :skill, template: :skill_as_association, if: proc { Account.current.skill_based_round_robin_enabled? }
      at.add :product, template: :product_as_association
      at.add :internal_group, template: :internal_group_central_publish_associations, if: proc { Account.current.shared_ownership_enabled? }
      at.add :internal_agent, template: :internal_agent_central_publish_associations, if: proc { Account.current.shared_ownership_enabled? }
    end
  end

  module InstanceMethods
    include TicketConstants

    def priority_hash
      {
        id: priority,
        name: PRIORITY_NAMES_BY_KEY[priority]
      }
    end

    def status_hash
      {
        id: status,
        name: status_name
      }
    end

    def source_hash
      {
        id: source,
        name: Account.current.ticket_source_revamp_enabled? ? source_name : Account.current.helpdesk_sources.default_ticket_source_names_by_key[source]
      }
    end

    def source_additional_info_hash
      source_info = {}
      source_info = social_source_additional_info(source_info)
      source_info[:email] = email_source_info(header_info) if email_ticket?
      source_info.presence
    end

    def association_hash
      render_assoc_hash(association_type)
    end

    def render_assoc_hash(current_association_type)
      return nil if current_association_type.blank?

      {
        id: current_association_type,
        type: TICKET_ASSOCIATION_TOKEN_BY_KEY[current_association_type]
      }
    end

    def requester_twitter_id
      requester.try(:twitter_id)
    end

    def requester_fb_id
      requester.try(:fb_profile_id)
    end

    def central_custom_fields_hash
      pv_transformer = Helpdesk::Ticketfields::PicklistValueTransformer::StringToId.new(self)
      arr = []
      custom_flexifield_def_entries.each do |flexifield_def_entry|
        field = flexifield_def_entry.ticket_field
        next if field.blank?

        begin
          field_value = custom_field_value(field.name) # custom_field_value method is used to get the custom field
          custom_field = {
            name: field.name,
            label: field.label,
            type: field.flexifield_coltype,
            value: map_field_value(field, field_value),
            column: field.column_name
          }.tap do |hash_body|
            hash_body[:choice_id] = pv_transformer.transform(field_value, field.column_name) if field.flexifield_coltype == 'dropdown'
          end
          arr.push(custom_field)
        rescue StandardError => e
          Rails.logger.error("Error while fetching ticket custom field #{field.name} - account #{account.id} - #{e.message} :: #{e.backtrace[0..10].inspect}")
          NewRelic::Agent.notice_error(e)
        end
      end
      arr
    end

    def map_field_value(ticket_field, value)
      if ticket_field.field_type == 'custom_date'
        utc_format(parse_to_date_time(value))
      elsif ticket_field.field_type == 'custom_file' && value.present?
        value.to_i
      elsif ticket_field.field_type == TicketFieldsConstants::SECURE_TEXT && value.present?
        DONT_CARE_VALUE
      else
        value
      end
    end

    def custom_flexifield_def_entries
      @custom_flexifield_def_entries ||= account.flexifields_with_ticket_fields_from_cache
    end

    def resolution_time_by_chrs
      resolved_at ? (parse_to_date_time(resolved_at) - created_at) : nil
    end

    def group_users
      return [] unless group

      group_users = Account.current.agent_groups_hash_from_cache[group.id]
      group_users&.collect { |user_id| { id: user_id } } || []
    end

    def parse_to_date_time(value)
      value.is_a?(String) ? Time.zone.parse(value) : value # since date coming as string class converting it to TimeZone class
    end
  end
end
