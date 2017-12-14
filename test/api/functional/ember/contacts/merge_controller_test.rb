require_relative '../../../test_helper'
module Ember
  module Contacts
    class MergeControllerTest < ActionController::TestCase
      include UsersTestHelper

      def setup
        super
        before_all
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run
        @account.add_feature(:multiple_user_companies)
        @@before_all_run = true
      end

      def wrap_cname(params)
        { merge: params }
      end

      def test_merge_with_no_params
        post :merge, construct_params({ version: 'private' }, {})
        assert_response 404
      end

      def test_merge_with_non_existing_contact
        post :merge, construct_params({ version: 'private' },
          primary_id: (User.last.try(:id) || 0) + 10,
          target_ids: [1, 2],
          contact: {
            phone: Faker::Lorem.characters(9),
            mobile: Faker::Lorem.characters(9),
            twitter_id: Faker::Lorem.characters(9),
            fb_profile_id: Faker::Lorem.characters(9),
            external_id: Faker::Lorem.characters(9),
            other_emails: ["s@g.com"],
            company_ids: [1, 2]
          }
        )
        assert_response 404
      end

      def test_merge_with_invalid_target_ids
        primary_contact = add_new_user(@account)
        invalid_ids = [primary_contact.id + 10, primary_contact.id + 20]
        post :merge, construct_params({ version: 'private' },
          primary_id: primary_contact.id,
          target_ids: invalid_ids,
          contact: {
            phone: Faker::Lorem.characters(9),
            mobile: Faker::Lorem.characters(9),
            twitter_id: Faker::Lorem.characters(9),
            fb_profile_id: Faker::Lorem.characters(9),
            external_id: Faker::Lorem.characters(9),
            other_emails: ["s@g.com"],
            company_ids: [1, 2]
          }
        )
        assert_response 400
        match_json([bad_request_error_pattern(:target_ids, :invalid_list, list: invalid_ids.join(', '))])
      end

      def test_merge_validation_failures
        primary_contact = add_new_user(@account)
        target_ids = []
        other_emails = []
        10.times do
          company = create_company
          target_user = add_new_user(@account)
          target_ids << target_user.id
          other_emails << target_user.email
        end
        params_hash = { primary_id: primary_contact.id, target_ids: target_ids, contact: { other_emails: other_emails } }
        post :merge, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('other_emails', :too_long, element_type: :values, max_count: ContactConstants::MAX_OTHER_EMAILS_COUNT, current_count: other_emails.size)])
      end

      def test_merge_success
        primary_contact = add_new_user(@account, customer_id: create_company.id)
        target_ids = []
        other_emails = []
        company_ids = []
        rand(2..4).times do
          company = create_company
          target_user = add_new_user(@account, customer_id: company.id)
          target_ids << target_user.id
          other_emails << target_user.email
          company_ids << company.id
        end
        params_hash = { primary_id: primary_contact.id, target_ids: target_ids, contact: { other_emails: other_emails, company_ids: company_ids } }
        post :merge, construct_params({ version: 'private' }, params_hash)
        assert_response 204
        primary_contact.reload
        assert_equal (other_emails.size + 1), primary_contact.user_emails.count
        assert_equal company_ids.size, primary_contact.user_companies.count
        Account.current.all_contacts.where(id: target_ids).each { |x| assert x.deleted }
      end

      def test_merge_success_without_primary_email
        primary_contact = add_new_user_without_email(@account, customer_id: create_company.id)
        target_ids = []
        other_emails = []
        company_ids = []
        rand(2..4).times do
          company = create_company
          target_user = add_new_user(@account, customer_id: company.id)
          target_ids << target_user.id
          other_emails << target_user.email
          company_ids << company.id
        end
        params_hash = { primary_id: primary_contact.id, target_ids: target_ids, contact: { phone: primary_contact.phone, other_emails: other_emails, company_ids: company_ids } }
        post :merge, construct_params({ version: 'private' }, params_hash)
        assert_response 204
        primary_contact.reload
        assert_equal (other_emails.size), primary_contact.user_emails.count
        assert_equal company_ids.size, primary_contact.user_companies.count
        Account.current.all_contacts.where(id: target_ids).each { |x| assert x.deleted }
      end

      def test_merge_success_with_required_custom_fields
        primary_contact = add_new_user(@account, customer_id: create_company.id)
        cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))

        target_ids = []
        other_emails = []
        company_ids = []
        rand(2..4).times do
          company = create_company
          target_user = add_new_user(@account, customer_id: company.id)
          target_ids << target_user.id
          other_emails << target_user.email
          company_ids << company.id
        end
        params_hash = { primary_id: primary_contact.id, target_ids: target_ids, contact: { other_emails: other_emails, company_ids: company_ids } }
        post :merge, construct_params({ version: 'private' }, params_hash)
        assert_response 204
        primary_contact.reload
        assert_equal (other_emails.size + 1), primary_contact.user_emails.count
        assert_equal company_ids.size, primary_contact.user_companies.count
        Account.current.all_contacts.where(id: target_ids).each { |x| assert x.deleted }
      ensure
        cf.update_attribute(:required_for_agent, false)
      end

    end
  end
end
