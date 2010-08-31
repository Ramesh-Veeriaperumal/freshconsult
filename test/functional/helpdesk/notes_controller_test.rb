require 'test_helper'

class Helpdesk::NotesControllerTest < ActionController::TestCase

  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
      @note = Helpdesk::Note.first
      @ticket = @note.notable
    end

    should "respond to get index with 404" do
      assert_raise ActiveRecord::RecordNotFound do
        get :index
      end
    end

    context "on get edit with valid id" do
      setup do
        get :edit, :id => @note.id, :ticket_id => @ticket.to_param
      end

      should_respond_with :success
      should_render_template :edit
      should_render_a_form
      should_not_show_form_errors

      should_assign_to :item, :note, :parent
      should "load correct ticket and note" do
        assert_equal @ticket, assigns(:parent)
        assert_equal @note, assigns(:note)
      end
    end

    context "on get edit with invalid id" do
      should "respond with not found" do
        assert_raise ActiveRecord::RecordNotFound do
          get :edit, :id => "invalid id", :ticket_id => "invalid ticket id"
        end
      end
    end

    context "on valid put to update" do
      setup do
        @params = {:body => 'new body'}
        put :update, :id => @note.id, :ticket_id => @ticket.to_param, :helpdesk_note => @params
      end
      should_redirect_to "helpdesk_ticket_url(@parent)";
      should_assign_to :item, :note, :parent
      should_set_the_flash_to "The note has been updated"
      should_not_change "Helpdesk::Note.count"
      should "have updated the note" do
        @note.reload
        assert_equal @params[:body], @note.body
      end
    end

    context "on invalid put to update" do
      setup do
        @params = {:body => ''}
        put :update, :id => @note.id, :ticket_id => @ticket.to_param, :helpdesk_note => @params
      end
      should_render_template :edit
      should_assign_to :item, :note, :parent
      should_show_form_errors
      should_render_a_form
      should_not_change "Helpdesk::Note.count"
      should "not have updated the note" do
        @note.reload
        assert_not_equal @params[:body], @note.body
      end
    end

    context "on delete to destroy" do
      setup do
        delete :destroy, :id => @note.id, :ticket_id => @ticket.to_param
      end
      should_redirect_to back
      should_assign_to :items, :parent
      should_not_change "Helpdesk::Note.count"
      should "have set the note's deleted flag" do
        @note.reload
        assert @note.deleted
      end
      should "set flash" do
        assert_match(/^1 note was deleted/, flash[:notice])
      end
    end

    context "on delete to destroy with invalid id" do
      should "respond with not found" do
        assert_raise ActiveRecord::RecordNotFound do
          delete :destroy, :id => "invalid id", :ticket_id => "invalid parent"
        end
      end
    end


    context "on valid post to create, not specifying incoming or private" do
      setup do
        Helpdesk::TicketNotifier.expects(:deliver_reply).never
        @params = {:body => 'new body'}
        post :create, :ticket_id => @ticket.to_param, :helpdesk_note => @params
      end
      should_redirect_to "helpdesk_ticket_url(@parent)";
      should_assign_to :item, :note, :parent
      should_set_the_flash_to "The note has been created"
      should_change "Helpdesk::Note.count", 1
      should "have created the note" do
        note = Helpdesk::Note.last
        assert_equal @params[:body], note.body
        assert_equal true, note.private
        assert_equal false, note.incoming
      end
    end

    context "on valid post to create, with incoming and private false" do
      setup do
        Helpdesk::TicketNotifier.expects(:deliver_reply)
        @params = {:body => 'new body', :private => false, :incoming => false}
        post :create, :ticket_id => @ticket.to_param, :helpdesk_note => @params
      end
      should_redirect_to "helpdesk_ticket_url(@parent)";
      should_assign_to :item, :note, :parent
      should_set_the_flash_to "The note has been created"
      should_change "Helpdesk::Note.count", 1
      should "have created the note" do
        note = Helpdesk::Note.last
        @params.each do |k, v|
          assert_equal v, note.send(k)
        end
      end
    end

    context "controller's private and protected methods made public" do
      setup { publicize_controller_methods }
      teardown { privatize_controller_methods }

      should "return class_name from Namespace::ClassName" do
        assert_equal "note", @controller.cname
      end

      should "return namespace_class_name from Namespace::ClassName" do
        assert_equal "helpdesk_note", @controller.nscname
      end

      context "controller loaded with mock @parent" do
        setup do
          @parent = mock
          @notes = mock
          @notes.stubs(:find_by_id).with(999).returns(:some_note)
          @notes.stubs(:find_by_id).with(666).returns(nil)
          @parent.stubs(:notes).returns(@notes)
          @controller.instance_variable_set('@parent', @parent) 
        end

        should "return correct scoper" do
          assert_same @notes, @controller.scoper
        end

        should "find called when load by param is called" do
          assert_equal :some_note, @controller.load_by_param(999)
        end

        should "fetch item when load_item called" do
          @controller.expects(:params).returns({:id => 999})
          assert_equal :some_note, @controller.load_item
        end

        should "render not found if load_item called with invalid id" do
          @controller.expects(:params).returns({:id => 666})
          assert_raise ActiveRecord::RecordNotFound do
            @controller.load_item
          end
        end

        should "build a new ticket from params" do
          params = {'name' => "bill"}
          @notes.expects(:build).with(params).returns(:new_record)
          @controller.expects(:params).returns({'helpdesk_note' => params})
          assert_same :new_record, @controller.build_item
        end

      end

    end

  end

end
