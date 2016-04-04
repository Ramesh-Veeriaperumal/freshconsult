require_relative '../test_helper'

class DecoratedController < ApiApplicationController
  include ActionController::Renderers::All
  include DecoratorConcern
  decorate_views decorate_objects: [:test_method], decorate_object: [:test_method_2]

  def test_method
    @items = Helpdesk::Ticket.first(2)
    render json: { message: @items }
  end

  def test_method_2
    @item = Helpdesk::Ticket.first
    render json: { message: @item }
  end
end

class DecoratedDecorator
  def initialize(*_args)
  end
end

class DecoratedControllerTest < ActionController::TestCase
  def test_decorate_objects_custom_method
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('test_method')
    @controller.expects(:decorate_objects).once
    @controller.expects(:decorate_object).never
    actual = @controller.send(:test_method)
    @controller.unstub(:action_name)
  end

  def test_decorate_object_custom_method
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('test_method_2')
    @controller.expects(:decorate_object).once
    @controller.expects(:decorate_objects).never
    actual = @controller.send(:test_method_2)
    @controller.unstub(:action_name)
  end
end
