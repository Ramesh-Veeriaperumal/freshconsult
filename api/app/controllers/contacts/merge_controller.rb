class Contacts::MergeController < ApiApplicationController
  include HelperConcern

  before_filter :validate_merge_params

  def merge
    sanitize_body_params

    @delegator_klass = 'ContactMergeDelegator'
    return unless validate_delegator(@item, delegator_params)
    return render_custom_errors unless merge_with_contacts(
      @delegator.secondary_contacts,
      delegator_params
    )
    MergeContacts.perform_async(parent: params[cname][:primary_contact_id], children: params[cname][:secondary_contact_ids])
    head 204
  end

  private

    def scoper
      current_account.all_contacts.preload(:user_companies, :user_emails)
    end

    def load_primary_contact
      @item = scoper.find_by_id(params[cname][:primary_contact_id])
    end

    def validate_merge_params
      load_primary_contact
      field = if private_api?
                ContactConstants::MERGE_CONTACT_FIELDS
              else
                ContactConstants::MERGE_CONTACT_FIELDS - [:external_id]
              end
      params[cname][:contact].try(:permit, *field)
      @validation_klass = 'ContactMergeValidation'
      validate_body_params @item
    end

    def delegator_params
      @delegator_params_cached ||= begin
        primary_user_hash = params[cname][:contact] || {}
        if primary_user_hash.key?(:other_emails)
          primary_user_hash[:emails] = primary_user_hash[:other_emails] || []
        end
        primary_user_hash[:company_ids] ||= [] if primary_user_hash.key?(:company_ids)
        if primary_user_hash[:email].present?
          primary_user_hash[:emails] ||= []
          primary_user_hash[:emails] += [primary_user_hash[:email]]
        end

        { params: primary_user_hash,
          scoper: scoper,
          secondary_contact_ids: params[cname][:secondary_contact_ids] }
      end
    end

    def merge_with_contacts(secondary_contacts, user_params)
      primary_user_hash = user_params[:params]
      primary_email = set_user_values(primary_user_hash, :email)
      @included_emails = set_user_values(primary_user_hash, :other_emails)
      @included_emails |= [primary_email] if primary_email.present?
      @included_companies = set_user_values(primary_user_hash, :company_ids)
      @primary_contact_company_ids = @item.user_companies.map(&:company_id) & @included_companies
      @secondary_contact_company_ids = []
      set_primary_attributes(secondary_contacts, primary_user_hash)
      secondary_contacts.each { |secondary_contact| merge_with_contact(secondary_contact) }
      item_user_emails = if @included_emails.blank?
                           @item.user_emails
                         else
                           @item.user_emails.where(['email NOT IN (?)', @included_emails])
                         end
      if primary_email && @item.email != primary_email
        primary_user_email = @item.user_emails.find_by_email(primary_email)
        @item.reset_primary_email(nil, primary_user_email)
      end
      @item.email = primary_email
      @item.user_emails_attributes = build_email_attributes(item_user_emails)
      item_user_companies = if @included_companies.blank?
                              @item.user_companies
                            else
                              @item.user_companies.where(['company_id NOT IN (?)', @included_companies])
                            end
      @item.user_companies_attributes = build_company_attributes(item_user_companies)
      @item.save
    end

    def merge_with_contact(secondary_contact)
      merge_companies(secondary_contact)
      ContactConstants::MERGE_KEYS.each do |att_key|
        secondary_contact[att_key] = nil
      end
      secondary_contact.deleted = true
      secondary_contact.user_emails.where(['email IN (?)', @included_emails]).update_all_with_publish({ user_id: @item.id,
                                                                                                        primary_role: false,
                                                                                                        verified: @item.active? }, ['user_id != ?', @item.id])
      secondary_contact_user_emails = if @included_emails.blank?
                                        secondary_contact.user_emails
                                      else
                                        secondary_contact.user_emails.where(['email NOT IN (?)', @included_emails])
                                      end
      secondary_contact.user_emails_attributes = build_email_attributes(secondary_contact_user_emails)
      secondary_contact.email = nil
      secondary_contact.parent_id = @item.id
      secondary_contact.save
    end

    def merge_companies(secondary_contact)
      secondary_contact.user_companies.where(['company_id IN (?)', @included_companies]).each do |uc|
        next if @primary_contact_company_ids.include?(uc.company_id) || @secondary_contact_company_ids.include?(uc.company_id)
        @item.user_companies.build(company_id: uc.company_id, client_manager: uc.client_manager,
                                   default: @primary_contact_company_ids.present? ? false : uc.default)
        @secondary_contact_company_ids << uc.company_id
      end
    end

    def set_primary_attributes(secondary_contacts, primary_user_hash)
      ContactConstants::MERGE_KEYS.each do |field|
        if primary_user_hash.key?(field)
          @item[field] = primary_user_hash[field].presence
        elsif !@item[field]
          @item[field] = secondary_contacts.select { |x| x[field].present? }.map(&field).first
        end
      end
    end

    def constants_class
      :ContactConstants.to_s.freeze
    end

    def set_user_values(user_hash, field)
      if user_hash.key?(field)
        user_hash[field]
      else
        @delegator.primary_fields[field]
      end
    end

    def build_email_attributes(user_emails)
      email_attributes = []
      user_emails.each do |user_email|
        email_attributes << { 'email' => user_email.email, 'id' => user_email.id, '_destroy' => 1 }
      end

      Hash[(0...email_attributes.size).zip email_attributes]
    end

    def build_company_attributes(user_companies)
      company_attributes = []
      user_companies.each do |user_company|
        company_attributes << { 'id' => user_company.id, '_destroy' => 1 }
      end
      Hash[(0...company_attributes.size).zip company_attributes]
    end
end
