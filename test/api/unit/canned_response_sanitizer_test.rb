require_relative '../unit_test_helper'
include Utils::Unhtml

class HtmlSanitizerTest < ActionView::TestCase

  def test_canned_response_with_placeholder_jsaction
    record = create_canned_responsetitle: 'testing', account_id: 1, content_html: '<div><a onmouseover="delete_node()"  href="google.com?id={{ticket.id}}">Testing</a></div>', folder_id: 2})
    assert_equal record.content_html, '<div><a href="google.com?id={{ticket.id}}" rel="noreferrer">Testing</a></div>'
  end

  def test_canned_response_with_placeholder_badprtocol
    record = create_canned_responsetitle: 'testing', account_id: 1, content_html: '<div><a href="ddp://google.com?id={{ticket.id}}">Testing</a></div>', folder_id: 2})
    assert_equal record.content_html, '<div><a rel="noreferrer">Testing</a></div>'
  end

  def test_canned_response_with_placeholder_badproperty
    record = create_canned_responsetitle: 'testing', account_id: 1, content_html: '<div><a data-property="data-item" href="https://google.com?id={{ticket.id}}">Testing</a></div>', folder_id: 2})
    assert_equal record.content_html, '<div><a href="https://google.com?id={{ticket.id}}" rel="noreferrer">Testing</a></div>'
  end

  def test_canned_response_with_placeholder_with_style
    record = create_canned_responsetitle: 'testing', account_id: 1, content_html: '<div><style></style><a data-property="data-item" href="https://google.com?id={{ticket.id}}">Testing</a></div>', folder_id: 2})
    assert_equal record.content_html, '<div><a href="https://google.com?id={{ticket.id}}" rel="noreferrer">Testing</a></div>'
  end

  def test_canned_response_with_placeholder_with_script
    record = create_canned_responsetitle: 'testing', account_id: 1, content_html: '<div><script> var banner = "none"</script><style></style><a data-property="data-item" href="https://google.com?id={{ticket.id}}">Testing</a></div>', folder_id: 2})
    assert_equal record.content_html, '<div><a href="https://google.com?id={{ticket.id}}" rel="noreferrer">Testing</a></div>'
  end

  def test_canned_response_with_placeholder_with_cite
    record = create_canned_responsetitle: 'testing', account_id: 1, content_html: '<div cite="google.com"><script> var banner = "none"</script><style></style><a data-property="data-item" href="https://google.com?id={{ticket.id}}">Testing</a></div>', folder_id: 2})
    assert_equal record.content_html, '<div><a href="https://google.com?id={{ticket.id}}" rel="noreferrer">Testing</a></div>'
  end

  private
  def current_account
    @current_account ||= Account.first.make_current
  end

  def create_canned_response(params)
    record = current_account.canned_responses.new(params)
    record.helpdesk_accessible = current_account.accesses.new
    record.save
    record
  end

end 