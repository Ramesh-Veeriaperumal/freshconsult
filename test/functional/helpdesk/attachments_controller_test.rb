require 'test_helper'

class Helpdesk::AttachmentsControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
    end
  end

  context "controller's private and protected methods made public" do
    setup { publicize_controller_methods }
    teardown { privatize_controller_methods }

    context "note attachment" do
      setup do
        @attachment = mock
        @note = mock
        @ticket = mock
        @attachment.stubs(:attachable).returns(@note)
        @note.stubs(:notable).returns(@ticket)
        @controller.instance_variable_set("@attachment", @attachment)
      end

      should "grant permission if user has global manage tickets permission" do
        allow_all
        assert @controller.check_download_permission
      end

      should "grant permission if user is logged in and is ticket requester" do
        deny_all
        stub_user
        @ticket.stubs(:requester_id).returns(@user.id)
        assert @controller.check_download_permission
      end

      should "grant permission if user provides correct access token" do
        deny_all
        stub_user
        @ticket.stubs(:requester_id).returns("user is not ticket requester")
        @ticket.expects(:access_token).returns('some_token')
        @controller.stubs(:params).returns({:access_token => 'some_token'})
        assert @controller.check_download_permission
      end


      should "deny permission if none of the criteria are met" do
        deny_all
        stub_user
        @ticket.stubs(:requester_id).returns("user is not ticket requester")
        @ticket.expects(:access_token).returns('some_token')
        @controller.stubs(:params).returns({:access_token => 'another_token'})
        @controller.expects(:redirect_to)
        assert !@controller.check_download_permission
      end
    end

    context "article attachment" do
      setup do
        @attachment = mock
        @article = mock
        @guide = mock
        @attachment.stubs(:attachable).returns(@article)
        @article.stubs(:guide).returns(@guide)
        @article.stubs(:ticket).returns(nil)
        @controller.instance_variable_set("@attachment", @attachment)
      end

      should "grant permission" do
        assert @controller.check_download_permission
      end
      
    end
  end
  

end
