module Channel::V2
  class TicketValidation < ::TicketValidation
    CHECK_PARAMS_SET_FIELDS += Channel::V2::TicketConstants::TICKET_ATTRIBUTES + 
                               Channel::V2::TicketConstants::TICKET_STATES_ATTRIBUTES
    attr_accessor :display_id, :deleted, :spam, :created_at, :updated_at, :opened_at, 
                  :pending_since, :resolved_at, :closed_at, :first_assigned_at, 
                  :assigned_at, :first_response_time, :requester_responded_at, 
                  :agent_responded_at, :status_updated_at, :sla_timer_stopped_at,
                  :on_state_time, :inbound_count, :outbound_count, :first_resp_time_by_bhrs, 
                  :resolution_time_by_bhrs, :group_escalated, :avg_response_time, 
                  :avg_response_time_by_bhrs, :import_id, :facebook, :twitter

    include TimestampsValidationConcern

    validates *Channel::V2::TicketConstants::DATETIME_ATTRIBUTES, 
                custom_absence: { message: :cannot_set_ticket_state },
                unless: :ticket_state_change_allowed?

    validates *Channel::V2::TicketConstants::DATETIME_ATTRIBUTES, date_time: { allow_nil: false }

    validates :display_id, :import_id, :on_state_time, :inbound_count, :outbound_count,
              :first_resp_time_by_bhrs, :resolution_time_by_bhrs,
              custom_numericality: { only_integer: true, greater_than: 0,
                                     allow_nil: true, ignore_string: :allow_string_param }

    validates :deleted, :spam, :group_escalated, data_type: { rules: 'Boolean',
                                                  ignore_string: :allow_string_param }
    validates :avg_response_time, :avg_response_time_by_bhrs, custom_numericality: 
                { only_float: true, greater_than: 0, allow_nil: true, 
                  ignore_string: :allow_string_param }

    validate :validate_ticket_states

    validate :display_id_exists?, if: -> { display_id.present? }

    validate :facebook_hash_presence?, unless: -> { facebook_ticket? }, on: :create

    validates :facebook, data_type: { rules: Hash, required: true }, hash: { validatable_fields_hash: proc { |x| x.facebook_fields_validation } }, if: -> { facebook_ticket? }, on: :create

    validate :twitter_hash_presence?, unless: -> { twitter_ticket? }, on: :create

    validates :twitter, data_type: { rules: Hash, required: true },
                        hash: { validatable_fields_hash: proc { |x| x.twitter_fields_validation } }, if: -> { twitter_ticket? }, on: :create

    def required_default_fields
      []
    end

    def custom_fields_to_validate
      []
    end

    def ticket_state_change_allowed?
      created_at && updated_at
    end

    def sources
      ticket_source_keys_by_token = Account.current.helpdesk_sources.ticket_source_keys_by_token
      ticket_sources = super | [ticket_source_keys_by_token[:facebook], ticket_source_keys_by_token[:twitter]]
      ticket_sources << ticket_source_keys_by_token[:whatsapp] if Account.current.launched?(:whatsapp_ticket_source)
      ticket_sources
    end

    def facebook_ticket?
      Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook] == source
    end

    def facebook_hash_presence?
      errors[:facebook] << :invalid_field if facebook.present?
    end

    def facebook_fields_validation
      facebook_dm_ticket? ? facebook_dm_fields_validation : facebook_post_fields_validation
    end

    def facebook_post_fields_validation
      {
        post_id: { data_type: { rules: String, required: true } },
        page_id: { data_type: { rules: Integer, required: true } },
        msg_type: {
          data_type: { rules: String, required: true },
          custom_inclusion: { in: Channel::V2::TicketConstants::FB_MSG_TYPES }
        },
        can_comment: { data_type: { rules: 'Boolean', required: true } },
        post_type: {
          data_type: { rules: Integer, required: true },
          custom_inclusion: { in: Facebook::Constants::CODE_TO_POST_TYPE.keys }
        }
      }
    end

    def facebook_dm_fields_validation
      {
        post_id: { data_type: { rules: String, required: true } },
        page_id: { data_type: { rules: Integer, required: true } },
        msg_type: {
          data_type: { rules: String, required: true },
          custom_inclusion: { in: Channel::V2::TicketConstants::FB_MSG_TYPES }
        },
        thread_id: { data_type: { rules: String, required: true } }
      }
    end

    def facebook_dm_ticket?
      facebook[:msg_type].present? && facebook[:msg_type] == Channel::V2::TicketConstants::FB_MSG_TYPES[0]
    end

    def validate_ticket_states
      Channel::V2::TicketConstants::DATETIME_ATTRIBUTES.each do |attribute|
        if self.safe_send(attribute).present? && errors[attribute].blank?
          validate_ticket_state_attribute(self.safe_send(attribute), attribute)
        end
      end
    end

    def twitter_ticket?
      Account.current.helpdesk_sources.ticket_source_keys_by_token[:twitter] == source
    end

    def twitter_hash_presence?
      errors[:twitter] << :invalid_field if twitter.present?
    end

    def twitter_fields_validation
      {
        tweet_id: { data_type: { rules: Integer, required: true } },
        tweet_type: {
          data_type: { rules: String, required: true },
          custom_inclusion: { in: Channel::V2::TicketConstants::TWITTER_MSG_TYPES }
        },
        support_handle_id: { data_type: { rules: Integer, required: true } },
        stream_id: { data_type: { rules: Integer, required: true } }
      }
    end

    def validate_ticket_state_attribute(attribute, key)
      if attribute > Time.zone.now
        errors[key] << :start_time_lt_now
      elsif attribute < created_at
        errors[key] << :gt_created_and_now
      end
      case key
      when :pending_since
        errors[key] << :cant_set_pending_since if status.to_i != ApiTicketConstants::PENDING
      when :resolved_at
        errors[key] << :cant_set_resolved_at if status.to_i != ApiTicketConstants::RESOLVED &&
                                                status.to_i != ApiTicketConstants::CLOSED
      when :closed_at
        errors[key] << :cant_set_closed_at if status.to_i != ApiTicketConstants::RESOLVED &&
                                              status.to_i != ApiTicketConstants::CLOSED
      end
    end

    def due_by_gt_created_at
      if due_by < (created_at || @item.try(:created_at) || Time.zone.now)
        errors[:due_by] << :gt_created_and_now
      end
    end

    def fr_due_gt_created_at
      if fr_due_by < (created_at || @item.try(:created_at) || Time.zone.now)
        errors[:fr_due_by] << :gt_created_and_now
      end
    end
    
    def display_id_exists?
      unless id.present?
        ticket = ::Account.current.tickets.find_by_display_id(display_id)
        errors[:display_id] << :display_id_exists if ticket.present?
      end
    end
  end
end
