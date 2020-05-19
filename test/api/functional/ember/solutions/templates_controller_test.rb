require_relative '../../../test_helper'

module Ember
  module Solutions
    class TemplatesControllerTest < ActionController::TestCase
      include SolutionsTemplatesTestHelper
      include TestCaseMethods

      def setup
        super
        @account = Account.first
        Account.stubs(:current).returns(@account)
        before_all
        @account.add_feature(:solutions_templates)
      end

      def teardown
        Account.unstub(:current)
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run

        @account.reload
        @@before_all_run = true
      end

      def wrap_cname(params)
        { template: params }
      end

      # show
      def test_show_template
        sample_template = create_sample_template
        get :show, controller_params(version: 'private', id: sample_template.id)
        assert_response 200
        sample_template.reload
        match_json(template_show_pattern(sample_template))
      ensure
        sample_template.destroy
      end

      def test_show_template_with_article_usage
        sample_template = create_sample_template
        create_sample_template_mapping(template_id: sample_template.id, used_cnt: 5)
        get :show, controller_params(version: 'private', id: sample_template.id)
        assert_response 200
        sample_template.reload
        match_json(template_show_pattern(sample_template))
      ensure
        sample_template.destroy
      end

      def test_show_without_feature
        disable_solutions_templates do
          get :show, controller_params(version: 'private', id: 345_846)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Solutions Templates'))
        end
      end

      def test_show_without_view_manage_privileges
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        get :show, controller_params(version: 'private', id: 21)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_show_without_manage_with_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        sample_template = create_sample_template
        get :show, controller_params(version: 'private', id: sample_template.id)
        assert_response 200
        sample_template.reload
        match_json(template_show_pattern(sample_template))
      ensure
        User.any_instance.unstub(:privilege?)
        sample_template.destroy
      end

      def test_show_with_manage_without_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        sample_template = create_sample_template
        get :show, controller_params(version: 'private', id: sample_template.id)
        assert_response 200
        sample_template.reload
        match_json(template_show_pattern(sample_template))
      ensure
        User.any_instance.unstub(:privilege?)
        sample_template.destroy
      end

      def test_show_with_invalid_int_id
        get :show, controller_params(version: 'private', id: 821_219)
        assert_response 404
      end

      def test_show_with_invalid_string_id
        get :show, controller_params(version: 'private', id: 'FZ')
        assert_response 404
      end

      # index
      def test_index
        sample_templates = get_sample_templates
        get :index, controller_params(version: 'private')
        assert_response 200
        templates = Account.current.solution_templates.latest
        match_json(template_index_pattern(templates))
      ensure
        sample_templates.destroy_all
      end

      def test_index_with_usage
        sample_templates = get_sample_templates
        sample_templates[0..3].each { |template| create_sample_template_mapping(template_id: template.id, used_cnt: 10) }
        get :index, controller_params(version: 'private')
        assert_response 200
        templates = Account.current.solution_templates.latest
        match_json(template_index_pattern(templates))
      ensure
        sample_templates.destroy_all
      end

      def test_index_without_feature
        disable_solutions_templates do
          get :index, controller_params(version: 'private')
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Solutions Templates'))
        end
      end

      def test_index_without_view_manage_privileges
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        get :index, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_index_without_manage_with_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        sample_templates = get_sample_templates
        get :index, controller_params(version: 'private')
        assert_response 200
        match_json(template_index_pattern(sample_templates))
      ensure
        User.any_instance.unstub(:privilege?)
        sample_templates.destroy_all
      end

      def test_index_with_manage_without_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        get_sample_templates
        get :index, controller_params(version: 'private')
        assert_response 200
        templates = Account.current.solution_templates.latest
        match_json(template_index_pattern(templates))
      ensure
        User.any_instance.unstub(:privilege?)
        templates.destroy_all
      end

      # create
      def get_sample_title
        "#{Faker::Name.name}#{Time.now.to_i}"
      end

      def test_create
        sample_title = get_sample_title
        post :create, construct_params({ version: 'private' }, title: sample_title,
                                                               description: Faker::Lorem.paragraph, is_active: false)
        assert_response 201
        template = Account.current.solution_templates.where(title: sample_title).first
        assert_equal false, template.is_active
        assert_equal User.current.id, template.user_id
        match_json(template_show_pattern(template))
      ensure
        template.destroy
      end

      def test_create_without_feature
        disable_solutions_templates do
          post :create, construct_params(version: 'private')
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Solutions Templates'))
        end
      end

      def test_create_without_view_manage_privileges
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        post :create, construct_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_create_without_manage_with_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        post :create, construct_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_create_with_manage_without_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        sample_title = get_sample_title
        post :create, construct_params({ version: 'private' }, title: sample_title,
                                                               description: Faker::Lorem.paragraph, is_active: false)
        assert_response 201
        template = Account.current.solution_templates.where(title: sample_title).first
        match_json(template_show_pattern(template))
      ensure
        User.any_instance.unstub(:privilege?)
        template.destroy
      end

      def test_create_without_mandatory_params
        post :create, construct_params(version: 'private')
        assert_response 400
        match_json([bad_request_error_pattern('title', 'Mandatory attribute missing', code: :missing_field),
                    bad_request_error_pattern('description', 'Mandatory attribute missing', code: :missing_field)])
      end

      def test_create_with_title_exceeding_max_length
        sample_title = 'a' * 241
        post :create, construct_params({ version: 'private' }, title: sample_title,
                                                               description: Faker::Lorem.paragraph)
        assert_response 400
        match_json([bad_request_error_pattern('title', :too_long_too_short, current_count: 241, element_type: 'characters', max_count: 240, min_count: 3)])
      end

      def test_create_with_title_less_than_min_length
        sample_title = 'a'
        post :create, construct_params({ version: 'private' }, title: sample_title,
                                                               description: Faker::Lorem.paragraph)
        assert_response 400
        match_json([bad_request_error_pattern('title', :too_long_too_short, current_count: 1, element_type: 'characters', max_count: 240, min_count: 3)])
      end

      def test_create_with_invalid_params_types
        post :create, construct_params({ version: 'private' }, title: 'fdsafdsaljk',
                                                               description: 2_121_212,
                                                               is_active: 1212)
        assert_response 400
        match_json([bad_request_error_pattern('description', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                    bad_request_error_pattern('is_active', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'Boolean', given_data_type: 'Integer', prepend_msg: :input_received)])
      end

      def test_create_check_default_fields
        sample_title = get_sample_title
        post :create, construct_params({ version: 'private' }, title: sample_title,
                                                               description: Faker::Lorem.paragraph)
        assert_response 201
        template = Account.current.solution_templates.where(title: sample_title).first
        assert_equal true, template.is_active
        assert_equal false, template.is_default
        assert_equal User.current.id, template.user_id
        match_json(template_show_pattern(template))
      ensure
        template.destroy
      end

      def test_create_with_duplicate_title
        sample_title = create_sample_template.title
        post :create, construct_params({ version: 'private' }, title: sample_title,
                                                               description: Faker::Lorem.paragraph, is_active: false)
        assert_response 400
        match_json(description: 'Validation failed',
                   errors: [bad_request_error_pattern('title', :duplicate_title, code: :invalid_value)])
      end

      def test_create_after_max_cap
        sample_templates = get_sample_templates(30)
        post :create, construct_params({ version: 'private' }, title: 'sample_title',
                                                               description: Faker::Lorem.paragraph, is_active: false)
        assert_response 400
        match_json(description: 'Validation failed',
                   errors: [bad_request_error_pattern('templates_count', :reached_max_count, code: :invalid_value)])
      ensure
        sample_templates.reload.destroy_all
      end

      def test_create_with_is_default
        sample_title = get_sample_title
        post :create, construct_params({ version: 'private' }, title: sample_title,
                                                               description: Faker::Lorem.paragraph, is_default: true)
        assert_response 201
        template = Account.current.solution_templates.where(title: sample_title).first
        assert_equal true, template.is_default
        assert_equal User.current.id, template.user_id
        match_json(template_show_pattern(template))
      ensure
        template.destroy
      end

      def test_create_with_existing_is_default
        existing_template = create_sample_template(is_default: true)
        sample_title = get_sample_title
        post :create, construct_params({ version: 'private' }, title: sample_title,
                                                               description: Faker::Lorem.paragraph, is_default: true)
        assert_response 201
        existing_template.reload
        template = Account.current.solution_templates.where(title: sample_title).first
        assert_equal true, template.is_default
        assert_equal false, existing_template.is_default
        assert_equal User.current.id, template.user_id
        match_json(template_show_pattern(template))
      ensure
        template.destroy
        existing_template.destroy
      end

      def test_create_template_with_emoji_content_in_description_and_title_with_encode_emoji_enabled
        Account.current.launch(:encode_emoji_in_solutions)
        sample_title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        sample_paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'

        post :create, construct_params({ version: 'private' }, title: sample_title,
                                                               description: sample_paragraph, is_active: false)

        assert_response 201
        template = Account.current.solution_templates.last
        paragraph_with_emoji_enabled = UnicodeSanitizer.utf84b_html_c(sample_paragraph)
        assert_equal template.description, paragraph_with_emoji_enabled
        match_json(template_show_pattern(template))
      ensure
        Account.current.rollback(:encode_emoji_in_solutions)
        template.destroy
      end

      # update
      def test_update
        template = create_sample_template
        new_title = Faker::Lorem.name
        new_desc = Faker::Lorem.paragraph
        put :update, construct_params({ version: 'private', id: template.id },
                                      title: new_title,
                                      description: new_desc, is_active: false)
        assert_response 200
        template.reload
        assert_equal new_title, template.title
        assert_equal new_desc, template.description
        assert_equal false, template.is_active
        assert_equal User.current.id, template.modified_by
        match_json(template_show_pattern(template))
      ensure
        template.destroy
      end

      def test_update_with_duplicate_title
        template1 = create_sample_template
        template2 = create_sample_template
        put :update, construct_params({ version: 'private', id: template2.id },
                                      title: template1.title)
        assert_response 400
        match_json(description: 'Validation failed',
                   errors: [bad_request_error_pattern('title', :duplicate_title, code: :invalid_value)])
      ensure
        template1.destroy
        template2.destroy
      end

      def test_update_with_same_title
        template = create_sample_template
        new_title = template.title
        put :update, construct_params({ version: 'private', id: template.id },
                                      title: new_title)
        assert_response 200

        template.reload
        assert_equal new_title, template.title
        match_json(template_show_pattern(template))
      ensure
        template.destroy
      end

      def test_update_without_feature
        disable_solutions_templates do
          put :update, construct_params(version: 'private', id: 345_846)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Solutions Templates'))
        end
      end

      def test_update_without_view_manage_privileges
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        put :update, construct_params(version: 'private', id: 345_846)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_without_manage_with_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        put :update, construct_params(version: 'private', id: 345_846)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_with_manage_without_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        template = create_sample_template
        new_title = Faker::Lorem.name
        new_desc = Faker::Lorem.paragraph
        put :update, construct_params({ version: 'private', id: template.id }, title: new_title,
                                                                               description: new_desc, is_active: false)
        assert_response 200
        template.reload
        assert_equal new_title, template.title
        assert_equal new_desc, template.description
        assert_equal false, template.is_active
        assert_equal User.current.id, template.modified_by
        match_json(template_show_pattern(template))
      ensure
        User.any_instance.unstub(:privilege?)
        template.destroy
      end

      def test_update_with_title_exceeding_max_length
        sample_title = 'a' * 241
        template = create_sample_template
        put :update, construct_params({ version: 'private', id: template.id },
                                      title: sample_title)
        assert_response 400
        match_json([bad_request_error_pattern('title', :too_long_too_short, current_count: 241, element_type: 'characters', max_count: 240, min_count: 3)])
      ensure
        template.destroy
      end

      def test_update_with_title_less_than_min_length
        sample_title = 'a'
        template = create_sample_template
        put :update, construct_params({ version: 'private', id: template.id }, title: sample_title)
        assert_response 400
        match_json([bad_request_error_pattern('title', :too_long_too_short, current_count: 1, element_type: 'characters', max_count: 240, min_count: 3)])
      ensure
        template.destroy
      end

      def test_update_with_invalid_params_types
        template = create_sample_template
        put :update, construct_params({ version: 'private', id: template.id }, title: 1_212_121,
                                                                               description: 2_121_212,
                                                                               is_active: 1212)
        assert_response 400
        match_json([bad_request_error_pattern('description', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                    bad_request_error_pattern('title', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                    bad_request_error_pattern('is_active', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'Boolean', given_data_type: 'Integer', prepend_msg: :input_received)])
      ensure
        template.destroy
      end

      def test_update_with_is_default
        template = create_sample_template
        new_title = Faker::Lorem.name
        new_desc = Faker::Lorem.paragraph
        put :update, construct_params({ version: 'private', id: template.id },
                                      title: new_title,
                                      description: new_desc, is_default: true)
        assert_response 200
        template.reload
        assert_equal new_title, template.title
        assert_equal new_desc, template.description
        assert_equal true, template.is_default
        assert_equal User.current.id, template.modified_by
        match_json(template_show_pattern(template))
      ensure
        template.destroy
      end

      def test_update_with_is_default_existing
        existing_template = create_sample_template(is_default: true)
        template = create_sample_template
        new_title = Faker::Lorem.name
        new_desc = Faker::Lorem.paragraph
        put :update, construct_params({ version: 'private', id: template.id },
                                      title: new_title,
                                      description: new_desc, is_default: true)
        assert_response 200
        template.reload
        existing_template.reload
        assert_equal new_title, template.title
        assert_equal new_desc, template.description
        assert_equal true, template.is_default
        assert_equal false, existing_template.is_default
        assert_equal User.current.id, template.modified_by
        match_json(template_show_pattern(template))
      ensure
        existing_template.destroy
        template.destroy
      end

      def test_update_template_with_emoji_content_in_description_and_title_with_encode_emoji_enabled
        Account.current.launch(:encode_emoji_in_solutions)
        template = create_sample_template
        sample_title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        sample_paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'
        put :update, construct_params({ version: 'private', id: template.id },
                                      title: sample_title,
                                      description: sample_paragraph)
        assert_response 200
        template.reload
        assert_equal UnicodeSanitizer.utf84b_html_c(sample_paragraph), template.description
        assert_equal ' hey ', template.title
        # it is required to match the full template. Need to check
        # match_json(template_show_pattern(template))
      ensure
        Account.current.rollback(:encode_emoji_in_solutions)
        template.destroy
      end

      # destroy
      def test_destroy_template
        sample_template = create_sample_template
        delete :destroy, controller_params(version: 'private', id: sample_template.id)
        assert_response 204
      end

      def test_destroy_without_feature
        disable_solutions_templates do
          delete :destroy, controller_params(version: 'private', id: 345_846)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Solutions Templates'))
        end
      end

      def test_destroy_without_view_manage_privileges
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        delete :destroy, controller_params(version: 'private', id: 21)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_destroy_without_manage_with_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        sample_template = create_sample_template
        delete :destroy, controller_params(version: 'private', id: sample_template.id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_destroy_with_manage_without_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        sample_template = create_sample_template
        delete :destroy, controller_params(version: 'private', id: sample_template.id)
        assert_response 204
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_destroy_with_invalid_int_id
        delete :destroy, controller_params(version: 'private', id: 345_846)
        assert_response 404
      end

      def test_destroy_with_invalid_string_id
        delete :destroy, controller_params(version: 'private', id: 'FZ')
        assert_response 404
      end

      # default
      def test_default_template
        sample_template = create_sample_template(is_default: true)
        get :default, controller_params(version: 'private')
        assert_response 200
        sample_template.reload
        match_json(template_show_pattern(sample_template))
      ensure
        sample_template.destroy
      end

      def test_default_template_without_any_default_templates
        get :default, controller_params(version: 'private')
        assert_response 200
        match_json({})
      end

      def test_default_template_without_feature
        disable_solutions_templates do
          get :default, controller_params(version: 'private')
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Solutions Templates'))
        end
      end

      def test_default_template_without_view_manage_privileges
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        get :default, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_default_template_without_manage_with_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        sample_template = create_sample_template(is_default: true)
        get :default, controller_params(version: 'private')
        assert_response 200
        sample_template.reload
        match_json(template_show_pattern(sample_template))
      ensure
        User.any_instance.unstub(:privilege?)
        sample_template.destroy
      end

      def test_default_template_with_manage_without_view_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solution_templates).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        sample_template = create_sample_template(is_default: true)
        get :default, controller_params(version: 'private')
        assert_response 200
        sample_template.reload
        match_json(template_show_pattern(sample_template))
      ensure
        User.any_instance.unstub(:privilege?)
        sample_template.destroy
      end
    end
  end
end
