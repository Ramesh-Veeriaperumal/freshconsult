class CustomerNotesController < ApiApplicationController
  include HelperConcern
  include AttachmentConcern
  include Utils::Sanitizer
  decorate_views

  ROOT_KEY = :note
  ORDER_TYPE_OPERATOR = {
    'asc' => '>=',
    'desc' => '<='
  }.freeze

  def index
    super
    response.api_meta = { count: @items_count, more_items: @more_items }
  end

  def create
    assign_note_attributes
    return unless validate_delegator(@item, attachment_ids: @attachment_ids)
    assign_attachments
    if @item.save
      render :create, status: 201
    else
      render_custom_errors
    end
  end

  def update
    assign_note_attributes
    @item.assign_attributes(cname_params)
    return unless validate_delegator(@item, attachment_ids: @attachment_ids)
    assign_attachments
    if @item.save
      render :update, status: 200
    else
      render_custom_errors
    end
  end

  def destroy
    if @item.destroy
      head 204
    else
      render_custom_errors
    end
  end

  def self.wrap_params
    CustomerNoteConstants::WRAP_PARAMS
  end

  private

    def scoper
      notes = note_type == :contact ? @parent.contact_notes : @parent.notes
      if params[:next_id]
        conditions = "id #{ORDER_TYPE_OPERATOR[order_type]} #{params[:next_id]}"
        notes = notes.where(conditions)
      end
      notes
    end

    def check_privilege
      return false unless super && load_parent_object
      true
    end

    def load_parent_object
      if note_type == :contact
        @parent = contact_scoper.find_by_id(params[:contact_id])
      else
        @parent = company_scoper.find_by_id(params[:company_id])
      end
      log_and_render_404 unless @parent
      true
    end

    def contact_scoper
      current_account.all_contacts
    end

    def company_scoper
      current_account.companies
    end

    def note_type
      @type_cached ||= begin
        params[:contact_id] ? :contact : :company
      end
    end

    def cname
      'note'.freeze
    end

    def validate_params
      fields_to_validate = "CustomerNoteConstants::#{note_type.upcase}_NOTE_CONSTANTS".constantize
      params[cname].permit(*fields_to_validate)
      note_validation = CustomerNoteValidation.new(params[cname], @item, string_request_params?)
      is_valid = note_validation.valid?(action_name.to_sym)
      render_errors(note_validation.errors, note_validation.error_options) unless is_valid
      is_valid
    end

    def validate_filter_params
      additional_fields_to_validate = "CustomerNoteConstants::#{note_type.upcase}_ADDITIONAL_INDEX_FIELDS".constantize
      params.permit(*ApiConstants::DEFAULT_INDEX_FIELDS, *additional_fields_to_validate)
      @filter = CustomerNoteFilterValidation.new(params, nil, true)
      render_errors(@filter.errors, @filter.error_options) unless @filter.valid?
    end

    def sanitize_params
      sanitize_body_html if cname_params[:body]
      params[cname][:created_by] = api_current_user.id.to_s if create?
      params[cname][:last_updated_by] = api_current_user.id.to_s if update?
      params[cname][:attachments] = params[cname][:attachments].map do |att|
        { resource: att }
      end if params[cname][:attachments]
      ParamsHelper.save_and_remove_params(self, CustomerNoteConstants::PARAMS_TO_SAVE_AND_REMOVE, cname_params)
    end

    def sanitize_body_html
      params[cname]["note_body_attributes"] = {
        body_html: params[cname].delete(:body) { '' }
      }
      sanitize_body_hash(cname_params, :note_body_attributes, 'body')
      params[cname][:note_body_attributes][:body] = params[cname][:note_body_attributes].delete(:body_html) { '' }
    end

    def assign_note_attributes
      build_normal_attachments(@item, cname_params[:attachments])
      # build_cloud_files(@item, @cloud_files)
    end

    def assign_attachments
      @item.attachments = @item.attachments + @delegator.draft_attachments if @delegator.draft_attachments
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(CustomerNoteConstants::FIELD_MAPPINGS, item)
    end

    def error_options_mappings
      CustomerNoteConstants::FIELD_MAPPINGS
    end

    def decorator_options_hash
      { name_mapping: CustomerNoteConstants::FIELD_MAPPINGS }
    end

    def decorator_options
      super decorator_options_hash
    end

    def paginate_options(is_array = false)
      options = super(is_array)
      options[:order] = order_clause
      options
    end

    def order_clause
      order_by = CustomerNoteConstants::DEFAULT_ORDER_BY
      "#{order_by} #{order_type} "
    end

    def order_type
      @ord_type ||= begin
        params[:order_type] || CustomerNoteConstants::DEFAULT_ORDER_TYPE
      end
    end

    def set_custom_errors(_item = @item)
      ErrorHelper.rename_error_fields({ :'note_body.body' => :body }, @item)
    end

    def valid_content_type?
      return true if super
      allowed_content_types = CustomerNoteConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def constants_class
      CustomerNoteConstants.to_s.freeze
    end

    def feature_name
      FeatureConstants::CONTACT_COMPANY_NOTES
    end

    wrap_parameters(*wrap_params)
end
