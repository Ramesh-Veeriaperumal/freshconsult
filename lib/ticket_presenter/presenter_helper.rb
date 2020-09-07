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
  DATETIME_FIELDS = [:due_by, :closed_at, :resolved_at, :created_at, :updated_at, :first_response_time, :first_assigned_at].freeze
  DONT_CARE_VALUE = '*'.freeze

  included do |base|
    base.include InstanceMethods

    acts_as_api

    api_accessible :central_publish do |at|
      at.add :id
      at.add :display_id
      at.add :account_id
      at.add :responder_id
      at.add :group_id
      at.add :status_hash, as: :status
      at.add :priority_hash, as: :priority
      at.add :ticket_type
      at.add :source_hash, as: :source
      at.add :requester_id
      at.add :sl_skill_id, as: :skill_id, if: proc { Account.current.skill_based_round_robin_enabled? }
      at.add :central_custom_fields_hash, as: :custom_fields
      at.add :product_id
      at.add :company_id
      at.add :sla_policy_id
      at.add :association_hash, as: :associates
      at.add :associates_rdb
      at.add :isescalated, as: :is_escalated
      at.add :fr_escalated
      at.add :nr_escalated, if: proc { Account.current.next_response_sla_enabled? }
      at.add :escalation_level, as: :resolution_escalation_level
      at.add :sla_response_reminded, as: :response_reminded
      at.add :sla_resolution_reminded, as: :resolution_reminded
      at.add :nr_reminded, as: :next_response_reminded, if: proc { Account.current.next_response_sla_enabled? }
      at.add :resolution_time_by_bhrs, as: :time_to_resolution_in_bhrs
      at.add :resolution_time_by_chrs, as: :time_to_resolution_in_chrs
      at.add :inbound_count
      at.add :first_resp_time_by_bhrs, as: :first_response_by_bhrs
      at.add :archive
      at.add :internal_agent_id
      at.add :internal_group_id
      at.add :outbound_email?, as: :outbound_email
      at.add :subject
      at.add proc { |x| x.description }, as: :description_text
      at.add :description_html
      at.add :watchers
      at.add :urgent
      at.add :spam
      at.add :trained
      at.add proc { |x| x.utc_format(x.parse_to_date_time(x.frDueBy)) }, as: :fr_due_by
      at.add proc { |x| x.utc_format(x.parse_to_date_time(x.nr_due_by)) }, as: :nr_due_by, if: proc { Account.current.next_response_sla_enabled? }
      at.add :to_emails
      at.add :email_config_id
      at.add :deleted
      at.add :group_users
      at.add :import_id
      at.add :on_state_time
      at.add :status_stop_sla_timer
      at.add :status_deleted
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
      at.add :source_additional_info_hash, as: :source_additional_info
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
        name: Account.current.helpdesk_sources.ticket_source_names_by_key[source]
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
          }
          handle_dropdown_flexifield_coltype(field_value, pv_transformer, field.column_name, custom_field) if field.flexifield_coltype == 'dropdown'
          custom_field[:value] = DONT_CARE_VALUE if field.field_type == TicketFieldsConstants::SECURE_TEXT && custom_field[:value].present?
          arr.push(custom_field)
        rescue StandardError => e
          Rails.logger.error("Error while fetching ticket custom field #{field.name} - account #{account.id} - #{e.message} :: #{e.backtrace[0..10].inspect}")
          NewRelic::Agent.notice_error(e)
        end
      end
      arr
    end

    def handle_dropdown_flexifield_coltype(field_value, pv_transformer, column_name, custom_field)
      if field_value
        picklist_id = pv_transformer.transform(field_value, column_name) # fetch picklist_id of the field
        custom_field[:value] = nil if picklist_id.blank?
      end
      custom_field[:choice_id] = picklist_id
    end

    def map_field_value(ticket_field, value)
      if ticket_field.field_type == 'custom_date'
        utc_format(parse_to_date_time(value))
      elsif ticket_field.field_type == 'custom_file' && value.present?
        value.to_i
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
