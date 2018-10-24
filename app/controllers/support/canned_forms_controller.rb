class Support::CannedFormsController < SupportController
  skip_before_filter :verify_authenticity_token, :redirect_to_locale
  before_filter :check_feature, :check_privilege, only: [:preview]
  before_filter :validate_current_user, only: [:show]
  before_filter :load_form_object

  # Settings current_user for observers rules
  around_filter :set_current_user, only: [:new], if: :current_user_blank?

  LABEL_TEMPLATE = '<span>%<label>s</span><br>'.freeze
  VALUE_TEMPLATE = '<p><strong>%<value>s</strong></p><br>'.freeze
  NO_INFO_TEMPLATE = '<div><i>%<value>s</i></div><br>'.freeze

  def preview
    render partial: 'preview'
  end

  def show
    render partial: 'show'
  end

  def new
    if form_handle.present?
      Rails.logger.debug "Canned form :: current_user :: #{User.current}"
      note = form_handle_ticket.notes.build(
        user_id: User.current.id,
        note_body_attributes: { body_html: parsed_note_body },
        source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['canned_form'],
        incoming: true,
        private: false
      )
      note.account_id = form_handle_ticket.account_id
      if note.save_note
        form_handle.update_attributes(response_note_id: note.id, response_data: @sanitized_data)
        Rails.logger.debug "Canned form :: current_user_session :: #{current_user_session.inspect}"
        current_user_session ? redirect_to(form_handle.support_ticket_url) : render(partial: 'thankyou')
        return
      end
    end
    Rails.logger.debug "Error on form submission #{note.errors.full_messages.inspect}"
    render partial: 'show'
  end

  private

    def check_feature
      redirect_to support_tickets_url unless current_account.canned_forms_enabled?
    end

    def load_form_object
      if params[:token].present? && form_handle.present? && form_handle.response_note_id.blank?
        @form = form_handle.canned_form
        @ticket = form_handle.ticket
      elsif preview? && cname_params.present?
        @preview = true
        # include_fields has introduced in formserv-gem to fetch the fields
        @form = params[:id].present? ? current_account.canned_forms.find_by_id(params[:id]).include_fields : current_account.canned_forms.new(filter_preview_param)
      else
        render_404 && return
      end
      @fields = @form.present? ? @form.prepare_form_json[:fields].map(&:symbolize_keys) : []
      @ticket ||= I18n.t('support.canned_form.ticket_subject_and_created_at')
    end

    def current_user_blank?
      Rails.logger.debug "Canned form :: current_user :: #{current_user.inspect}"
      current_user.blank?
    end

    def set_current_user
      user = current_user || form_handle_ticket.requester
      user.make_current
      Rails.logger.debug "Canned form :: set_current_user :: #{User.current}"
      yield
    ensure
      User.reset_current_user
      Rails.logger.debug "Canned form :: reset_current_user :: #{User.current || true}"
    end

    def form_handle
      @handle ||= current_account.canned_form_handles.find_by_id_token(params[:token])
    end

    def form_handle_ticket
      @form_handle_ticket ||= form_handle.ticket
    end

    def cname_params
      params.slice(:id, :name, :welcome_text, :thankyou_text, :fields)
    end

    def filter_preview_param
      if cname_params['fields'].present?
        fields = JSON.parse(cname_params['fields'])
        return cname_params.merge('fields' => fields.sort_by { |h| h['position'] }) if fields.present?
      end
      cname_params
    end

    def preview?
      action.to_sym == :preview
    end

    def validate_current_user
      return render_403 if current_user.present? && current_user.id != form_handle_ticket.requester_id
    end

    def parsed_note_body
      html_body = ''
      @sanitized_data = {}
      params[:canned_forms].each do |field_name, value|
        sanitized_value = Helpdesk::HTMLSanitizer.plain(value)
        field = @fields.select { |f| f[:name] == field_name }.try(:first)
        next if field.blank?
        field_type = field[:name].split('_')[0].upcase
        field_label = field[:label]
        html_body += format(LABEL_TEMPLATE, label: field_label)
        if field_type == 'CHECKBOX'
          sanitized_value = sanitized_value.to_bool ? I18n.t('plain_yes') : I18n.t('plain_no')
        end
        no_info_text = I18n.t('support.canned_form.no_info')
        @sanitized_data[field_label] = sanitized_value || no_info_text
        html_body += if sanitized_value.present?
                       format(VALUE_TEMPLATE, value: sanitized_value)
                     else
                       format(NO_INFO_TEMPLATE, value: no_info_text)
                     end
      end
      html_body
    end
end