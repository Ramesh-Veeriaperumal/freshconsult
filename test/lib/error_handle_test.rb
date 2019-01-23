require_relative '../api/unit_test_helper'

class ErrorHandleTest < ActionView::TestCase
  include ErrorHandle

  def test_error_handle_exception
    User.any_instance.stubs(:has_company?).raises(Exception)
    returned_value = sandbox(0) {
      user = User.last
      user.has_company?
    }
    assert_equal 0, returned_value
  end

  def test_error_handle_econnreset
    User.any_instance.stubs(:has_company?).raises(Errno::ECONNRESET)
    returned_value = sandbox(0) {
      user = User.last
      user.has_company?
    }
    assert_equal 0, returned_value
  end

  def test_error_handle_timeout_error
    User.any_instance.stubs(:has_company?).raises(Timeout::Error)
    returned_value = sandbox(0) {
      user = User.last
      user.has_company?
    }
    assert_equal 0, returned_value
  end

  def test_error_handle_eof_error
    User.any_instance.stubs(:has_company?).raises(EOFError)
    returned_value = sandbox(0) {
      user = User.last
      user.has_company?
    }
    assert_equal 0, returned_value
  end

  def test_error_handle_etimedout_error
    User.any_instance.stubs(:has_company?).raises(Errno::ETIMEDOUT)
    returned_value = sandbox(0) {
      user = User.last
      user.has_company?
    }
    assert_equal 0, returned_value
  end

  def test_error_handle_econnrefused_error
    User.any_instance.stubs(:has_company?).raises(Errno::ECONNREFUSED)
    returned_value = sandbox(0) {
      user = User.last
      user.has_company?
    }
    assert_equal 0, returned_value
  end

  def test_error_handle_eafnosupport_error
    User.any_instance.stubs(:has_company?).raises(Errno::EAFNOSUPPORT)
    returned_value = sandbox(0) {
      user = User.last
      user.has_company?
    }
    assert_equal 0, returned_value
  end

  def test_error_handle_ssl_error
    User.any_instance.stubs(:has_company?).raises(OpenSSL::SSL::SSLError)
    returned_value = sandbox(0) {
      user = User.last
      user.has_company?
    }
    assert_equal 0, returned_value
  end

  def test_error_handle_systemstack_error
    User.any_instance.stubs(:has_company?).raises(SystemStackError)
    returned_value = sandbox(0) {
      user = User.last
      user.has_company?
    }
    assert_equal 0, returned_value
  end
end
