class UpdateSegmentFilter < BaseWorker
  include Segments::WorkerConstants
  sidekiq_options queue: :update_segment_filter, retry: 0,  failures: :exhausted

  def perform(args)
    return unless Account.current.segments_enabled?
    Rails.logger.info("current args :: #{args.inspect}")
    if segment_field_update(args['type'])
      fields_update(args)
    elsif segment_choice_update(args['type'])
      choices_update(args)
    end
    Account.reset_current_account
  rescue Exception => e
    msg = { class: e.class, args: e.exception.to_s, error_message: e.backtrace }
    Rails.logger.debug("Error in segment worker :: #{msg.inspect}")
    NewRelic::Agent.notice_error(e, msg)
  end

  def fields_update(args)
    return if args['custom_field'].blank?
    field_names = get_field_names(Account.current, args['type'])
    segment_filters(args['type']) do |filter|
      filter.data.delete_if do |filter_set|
        field_names.exclude?(filter_set['condition'])
      end
    end
  end

  def get_field_names(account, segment_type)
    fields = contact_segment?(segment_type) ? account.contact_form.contact_fields : account.company_form.company_fields
    fields.collect do |field|
      field.name.sub(CUSTOM_FIELD_PREFIX_REGEX, '')
    end
  end

  def choices_update(args)
    segment_filters(args['type']) do |filter|
      condition_key = field_id_map(args['type']).key(args['custom_field'][@field_id])
      if CHOICE_DELETE.eql?(args['operation'])
        filter.data.delete_if do |filter_set|
          if condition_key.eql?("cf_#{filter_set['condition']}")
            filter_set['value'] = process_values(filter_set['value'], args['custom_field']['value'])
          end
          filter_set['value'].blank?
        end
      else
        filter.data.each do |filter_set|
          next unless condition_key.eql?("cf_#{filter_set['condition']}") && args['changes']['value'].present?
          filter_set['value'] = process_values(filter_set['value'], args['changes']['value'].first, args['changes']['value'].last)
        end
      end
    end
  end

  def process_values(list, del_value, new_value = '')
    return list unless list.include?(del_value)
    list -= [del_value]
    list.push(new_value) if new_value.present?
    list
  end

  def contact_segment?(type)
    type.include?(CONTACT)
  end

  def segment_filters(segment_type)
    filters = if contact_segment?(segment_type)
                @field_id = CONTACT_FIELD_ID
                Account.current.contact_filters
              else
                @field_id = COMPANY_FIELD_ID
                Account.current.company_filters
              end

    filters.each do |filter|
      yield(filter)
      if filter.data.blank?
        filter.destroy
      else
        filter.save
        Rails.logger.debug("Error while saving filter :: #{filter.errors.inspect}") if filter.errors.present?
      end
    end
  end

  def segment_field_update(type)
    CONTACT_FIELD.eql?(type) || COMPANY_FIELD.eql?(type)
  end

  def segment_choice_update(type)
    CONTACT_FIELD_CHOICE.eql?(type) || COMPANY_FIELD_CHOICE.eql?(type)
  end

  def field_id_map(type)
    @field_id_map ||= Segments::FilterDataValidation.new({}, (contact_segment?(type) ? 'contacts' : 'company')).fields_info
  end
end
