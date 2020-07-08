class Archive::ConversationsController < ::ConversationsController
  include HelperConcern
  include ConversationConcern

  def ticket_conversations
    validate_filter_params
    return unless @conversation_filter.valid?

    load_conversations
    response.api_meta = { count: @items_count }
  end

  private

    def feature_name
      :archive_tickets
    end
    
    def load_conversations
      order_type = params[:order_type]
      order_conditions = "created_at #{order_type}"
      since_id = params[:since_id] && params[:since_id].to_i <= 0 ? nil : params[:since_id]

      conversations = @ticket.archive_notes.conversations(conditional_preload_options, order_conditions)
      filtered_conversations = if since_id
                                 last_created_at = @ticket.archive_notes.where(id: since_id).pluck(:created_at).first
                                 conversations.created_since(since_id, last_created_at)
                               else
                                 conversations
                               end

      @items = paginate_items(filtered_conversations)
      @items_count = conversations.count
    end

    def conditional_preload_options
      # Loading the preload options only if the ArchiveNoteConfig is lesser than the note id.
      # If the tickets note_id is not in the ArchiveNoteConfig then preload the options.
      current_shard = ActiveRecord::Base.current_shard_selection.shard.to_s

      if(ArchiveNoteConfig[current_shard] && (@ticket.id <= ArchiveNoteConfig[current_shard].to_i))
        preload_options = [:attachments]
      else
        preload_options = [:schema_less_note, :note_body, :attachments, :cloud_files, :attachments_sharable,
                         custom_survey_remark: { survey_result: { survey: { survey_questions: {} }, survey_result_data: {} } }]
      end
      
      if @ticket.facebook?
        preload_options << :fb_post
      elsif @ticket.twitter?
        preload_options << :tweet
      end
      preload_options << :freshfone_call if current_account.freshfone_enabled?
      preload_options << :user if sideload_options.include?('requester')
      preload_options
    end

    def sideload_options
      @conversation_filter.try(:include_array) || []
    end

    def validate_filter_params
      @constants_klass = 'ConversationConstants'
      @validation_klass = 'ConversationFilterValidation'
      validate_query_params
      @conversation_filter = @validator
    end

    def tickets_scoper
      current_account.archive_tickets
    end

    def check_privilege
      # Overriding so that verify_ticket_permission is called with current scope(erroring out with schemaless in archive).
      return false unless check_api_privilege # duping api controllers privilege checks.
      return false if ticket_required? && !load_parent_ticket
      verify_ticket_permission(api_current_user, @ticket) if @ticket
    end

    def index?
      @index ||= current_action?('ticket_conversations')
    end

    def verify_ticket_permission(user = api_current_user, ticket = @item)
      unless user.has_ticket_permission?(ticket) # Overriding to remove schema_less_check.
        Rails.logger.error "User: #{user.id}, #{user.email} doesn't have permission to ticket display_id: #{ticket.display_id}"
        render_request_error :access_denied, 403
        return false
      end
      true
    end

    def check_api_privilege
      if api_current_user.nil? || api_current_user.customer? || !allowed_to_access?
        access_denied
        return false
      elsif verify_password_expired?
        Rails.logger.debug 'API V2 Password expired error'
        render_request_error :password_expired, 403
        return false
      end
      true
    end
end
