# frozen_string_literal: true

require_relative '../../api/test_helper'

class TicketsUploadedImagesControllerTest < ActionController::TestCase
  def test_create_file
    @controller.stubs(:logged_in?).returns(true)
    post :create_file, image_params
    image = @controller.instance_variable_get(:@image)
    assert_not_nil image
    assert_equal image.content_file_name, 'blob1602848280299.png'
    assert_equal image.attachable_type, 'Tickets Image Upload'
  ensure
    @controller.unstub(:logged_in?)
  end

  def test_create_file_without_login
    @controller.stubs(:logged_in?).returns(false)
    post :create_file, image_params
    assert_nil @controller.instance_variable_get(:@image)
    match_json(error: ErrorConstants::ERROR_MESSAGES[:invalid_credentials])
  ensure
    @controller.unstub(:logged_in?)
  end

  private

    def image_params
      {
        dataURI: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAOEAAADhCAMAAAAJbSJIAAAAPFBMVEXw8PCP0Xv18vbe6tqIz3Oi15ON0Hja6Nam2JiGz3Cd1Y2CzWqL0Hbh69/s7uui1pO03Kn58/uU0oHJ48EgEUQuAAABcUlEQVR4nO3cS27CUBBEUYixwWB+yf73mkwyiJRBSbE6DZy7gj7j91SbjSRJkiRJeunOQ3GXYuDbdd6VdtpXCw/TtrQdISEhISEhISEhISEhISEhISEhISEhISEhISEhISHhr9cH3cuFwz25KwKer4eg91rgdhqTq24RcZinoGLgFzFoGTPhrvz6tZoICdtHSNg/QsL+ERL2j5Cwf4SE/SMk7B8hYf8ICftHSNg/QsL+EX4LT8nGQflD/hIcNR8j4WUfNIzFxOUjOisBZtX/p9lnf2VW67H/RBESEhISEhISEhISEhISEhISEhISEhISEhISEhIS/hQuyQTAes3lwttY23HFTwghsbpqoCRJkiRJkiRJkiRJz9ZlSDr/95l/KJrYCMcsehbNpISDJD0jJOwfIWH/CAn7R0jYP0LC/hES9o+QsH+EhP0jJOwfIWH/CAn79wLCOdiDWB5ZeD4mgxC3BxaG2xL/faUkSZIkSU/QJ7t2YHCn79n9AAAAAElFTkSuQmCC',
        _uniquekey: 1_602_848_280_299
      }
    end
end
