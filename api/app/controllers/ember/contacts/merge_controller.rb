module Ember
  module Contacts
    class MergeController < ApiApplicationController
      include HelperConcern

      before_filter :validate_merge_params

      def merge
        sanitize_body_params

        @delegator_klass = 'ContactMergeDelegator'
        primary_email = params[cname][:contact][:email] || nil
        return unless validate_delegator(@item, delegator_params)
        return render_custom_errors unless merge_with_contacts(
          @delegator.target_users,
          delegator_params.merge!(email: primary_email)
        )
        MergeContacts.perform_async(parent: params[cname][:primary_id], children: params[cname][:target_ids])
        head 204
      end

      private

        def scoper
          current_account.contacts.preload(:user_companies, :user_emails)
        end

        def load_primary_contact
          @item = scoper.find_by_id(params[cname][:primary_id])
          log_and_render_404 unless @item
          @item
        end

        def validate_merge_params
          return unless load_primary_contact
          @validation_klass = 'ContactMergeValidation'
          validate_body_params
        end

        def delegator_params
          @delegator_params_cached ||= begin
            primary_user_hash = params[cname][:contact] || {}
            ContactConstants::MERGE_KEYS.each do |user_key|
              primary_user_hash[user_key] ||= nil
            end

            primary_user_hash[:emails] = primary_user_hash.delete(:other_emails) || []
            primary_user_hash[:company_ids] ||= []
            if primary_user_hash[:email].present?
              primary_user_hash[:emails] += [primary_user_hash.delete(:email)]
            else
              primary_user_hash[:emails] += [@item.email] if @item.email
            end
            { params: primary_user_hash, scoper: scoper, target_ids: params[cname][:target_ids] }
          end
        end

        def merge_with_contacts(target_users, user_params)
          primary_user_hash = user_params[:params]
          primary_email = user_params[:email]
          @included_emails = primary_user_hash[:emails]
          @included_companies = primary_user_hash[:company_ids]
          @source_company_ids = @item.user_companies.map(&:company_id) & @included_companies
          @target_company_ids = []
          @item.attributes = primary_user_hash.except(:external_id, :emails, :company_ids)
          @item.external_id = primary_user_hash[:external_id]
          target_users.each { |target| merge_with_contact(target) }

          item_user_emails = @item.user_emails.where(['email NOT IN (?)', @included_emails])
          if primary_email && @item.email != primary_email
            primary_user_email = @item.user_emails.find_by_email(primary_email)
            @item.reset_primary_email(nil, primary_user_email)
          end
          @item.user_emails_attributes = build_email_attributes(item_user_emails)

          item_user_companies = @item.user_companies.where(['company_id NOT IN (?)', @included_companies])
          @item.user_companies_attributes = build_company_attributes(item_user_companies)

          @item.save
        end

        def merge_with_contact(target)
          merge_companies(target)
          ContactConstants::MERGE_KEYS.each do |att_key|
            target[att_key] = nil
          end
          target.deleted = true
          target.user_emails.where(['email IN (?)', @included_emails]).update_all_with_publish({ user_id: @item.id,
                                                        primary_role: false,
                                                        verified: @item.active? }, ['user_id != ?', @item.id])
          target_user_emails = target.user_emails.where(['email NOT IN (?)', @included_emails])
          target.user_emails_attributes = build_email_attributes(target_user_emails)
          target.email = nil
          target.parent_id = @item.id
          target.save
        end

        def merge_companies(target)
          target.user_companies.where(['company_id IN (?)', @included_companies]).each do |uc|
            next if @source_company_ids.include?(uc.company_id) || @target_company_ids.include?(uc.company_id)
            @item.user_companies.build(company_id: uc.company_id, client_manager: uc.client_manager,
                                       default: @source_company_ids.present? ? false : uc.default)
            @target_company_ids << uc.company_id
          end
        end

        def constants_class
          :ContactConstants.to_s.freeze
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
  end
end
