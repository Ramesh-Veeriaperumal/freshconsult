class Admin::CustomTranslationsController < ApiApplicationController
  include HelperConcern

  before_filter :validate_query_params, only: [:download]
  before_filter :validate_upload_params, only: [:upload]
  before_filter :set_scope

  WRAP_PARAMS = [:custom_translation, exclude: [], format: [:multipart_form]].freeze

  def upload
    translation_file = cname_params['translation_file']
    translation_file = translation_file.is_a?(StringIO) ? translation_file : translation_file.tempfile
    tf_hash = YAML.safe_load(translation_file)

    delegator_params = params_hash.merge(uploaded_hash: tf_hash)
    custom_translation_delegator = Admin::CustomTranslationDelegator.new(delegator_params)

    if custom_translation_delegator.valid?
      @language = Language.find_by_code(params['language_code'])
      custom_translations_hash = tf_hash[@language.code]['custom_translations']
      upload_translation(custom_translations_hash) unless custom_translations_hash.empty?
    else
      render_custom_errors(custom_translation_delegator, true)
    end
  end

  def download
    custom_translation_delegator = Admin::CustomTranslationDelegator.new(params_hash)
    if custom_translation_delegator.valid?
      translation = { @language => { 'custom_translations' => fetch_translation } }
      respond_with_yaml(translation)
    else
      render_custom_errors(custom_translation_delegator, true)
    end
  end

  private

    def fetch_translation
      data = {}
      @objects.each do |object|
        items = params['object_id'].blank? ? scoper(object) : scoper(object).where(id: params['object_id'])
        items = items.preload("#{@language.underscore}_translation".to_sym) if download_type == :custom_translation_secondary
        data[object] = {}
        items.each do |item|
          data[object][item.custom_translation_key] = item.as_api_response(download_type, lang: @language).stringify_keys
        end
      end
      data
    end

    def feature_name
      :custom_translations
    end

    def valid_content_type?
      return true if request.content_mime_type.blank?

      allowed_content_types = Admin::CustomTranslationsConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def cname
      'custom_translation'.freeze
    end

    def validate_upload_params
      return unless validate_query_params(nil, params_hash)
    end

    def params_hash
      params.slice('object_type', 'object_id', 'language_code', 'translation_file')
    end

    # string_request_params? (from api application controller) is true only for multipart content type & get
    # If there is no file uploaded, then string_request_params? becomes false & doesnt allow string params.
    # Overriding below method to allow it for put request also.

    def allowed_http_method?
      get_request? || request.delete? || put_request?
    end

    def put_request?
      @put_request ||= request.put?
    end

    def download_type
      @language == Account.current.language ? :custom_translation : :custom_translation_secondary
    end

    def constants_class
      'Admin::CustomTranslationsConstants'.freeze
    end

    def scoper(object)
      object_mapping = Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS[object]
      items = Account.current.safe_send(object_mapping[:model])
      items = items.where(object_mapping[:conditions]) if object_mapping[:conditions].present?
      items
    end

    def set_scope
      @language = params['language_code'] || Account.current.language
      @objects = params['object_type'].present? ? [params['object_type']] : Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS.keys
    end

    # if the object is empty, upload for all the modules
    # if the object is present, even if the file has entries for all modules, upload only for given object
    # if the object & record id is present & upload only for the particular record
    # Below method will be added to helper & used in the sidekiq worker.
    # Below method is having an assumption that in upload file module name will be surveys &
    # each record name will be survey_*

    def upload_translation(translations)
      object_id = params['object_id']

      @objects.each do |object|
        items = object_id.blank? ? scoper(object) : scoper(object).where(lookup_method(object) => object_id).first

        if object_id
          record_key = translations[object][items.custom_translation_key]
          create_translation(items, record_key) if record_key.present?
        end
      end
    end

    def lookup_method(object)
      Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS[object][:lookup_key]
    end

    # Look for existing DB record. If not, create a empty record & update the values.
    # Using the active record for sanitization & update-merge

    def create_translation(field_object, translations)
      @custom_translation_record = field_object.safe_send(language_translation)

      if @custom_translation_record.blank?
        @custom_translation_record = field_object.safe_send("build_#{language_translation}", translations: nil, status: 0)
      end
      @custom_translation_record.sanitize_and_update(translations)
      @custom_translation_record.save!
    end

    def language_translation
      "#{@language.to_key}_translation"
    end

    # Adding code for file upload in S3.
    # Temporarily commenting it. Will need it when we use workers to do the upload processing.
    # def save_yml(cname_params, id)
    #   translation_file = cname_params['translation_file']
    #   return nil if translation_file.nil?

    #   translation_file = translation_file.is_a?(StringIO) ? translation_file : translation_file.tempfile
    #   file_path = generate_file_path(id)
    #   AwsWrapper::S3Object.store(file_path,
    #                              translation_file,
    #                              S3_CONFIG[:bucket],
    #                              server_side_encryption: :aes256, expires: 30.days)
    #   file_path
    # end

    # def generate_file_path(language)
    #   output_dir = "data/helpdesk/custom_translations/#{Rails.env}/#{Account.current.id}"
    #   file_path = "#{output_dir}/#{language}-#{Time.now.utc.strftime('%B-%d-%Y-%H:%M:%S')}.yml"
    #   file_path
    # end

    def respond_with_yaml(translation)
      response.headers['Content-Disposition'] = "attachment; filename=#{@language}.yml"
      render text: translation.psych_to_yaml, content_type: 'text/yaml'
    end

    wrap_parameters(*WRAP_PARAMS)
end
