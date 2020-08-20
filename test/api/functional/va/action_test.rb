require_relative '../../test_helper'

require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')

class ActionTest < ActionView::TestCase
  include CoreTicketsTestHelper

  def setup
    super
    @account = Account.first || create_test_account
    @ticket = @account.tickets.first || create_ticket
    @account.make_current
  end

  def teardown
    super
  end

  def test_trim_special_character_with_feature
    @account.launch :trim_special_characters
    email_body = '<p data-identifyelement="291" dir="ltr">-- group --</p><p data-identifyelement="292" dir="ltr">---hey---</p><p data-identifyelement="293" dir="ltr">-hello-</p><p data-identifyelement="294" dir="ltr">--- tell me please ---</p><p data-identifyelement="295" dir="ltr"><br data-identifyelement="296"></p><p data-identifyelement="297" dir="ltr">---エージェント---</p><p data-identifyelement="298" dir="rtl">--אַגענט--</p><p data-identifyelement="299" dir="ltr">--- エージェント エージェント ---</p><p data-identifyelement="300" dir="ltr">-- エージェント エージェント ---</p><p data-identifyelement="301" dir="ltr"><br data-identifyelement="302"></p><p>&#8220;}, {:name=&gt;&#8221;send_email_to_requester&quot;, :email_subject=&gt;&quot;--test from hk--&#8220;, :email_body=&gt;&#8221;<p data-identifyelement="291" dir="ltr">-- group --</p><p data-identifyelement="292" dir="ltr">---hey---</p><p data-identifyelement="293" dir="ltr">-hello-</p><p data-identifyelement="294" dir="ltr">--- tell me please ---</p><p>!!!!!hey!!!!!<p data-identifyelement="295" dir="ltr"><br data-identifyelement="296"></p><p data-identifyelement="297" dir="ltr">---エージェント---</p><p data-identifyelement="298" dir="rtl">--אַגענט--</p><p data-identifyelement="299" dir="ltr">--- エージェント エージェント ---</p><p data-identifyelement="300" dir="ltr">-- エージェント エージェント ---</p></p>'
    act_hash = { name: 'send_email_to_requester', email_to: 1, email_subject: 'Test Email', email_body: email_body }
    resp = Va::Action.new(act_hash).send(:substitute_placeholders, @ticket, :email_body)
    assert_equal resp, email_body
  ensure
    @account.rollback :trim_special_characters
    Account.reset_current_account
  end

  def test_trim_special_character_without_feature
    @account.rollback :trim_special_characters
    email_body = '<p dir="ltr">--check--</p>'
    act_hash = { name: 'send_email_to_requester', email_to: 1, email_subject: 'Test Email', email_body: email_body }
    resp = Va::Action.new(act_hash).send(:substitute_placeholders, @ticket, :email_body)
    assert_not_equal resp, email_body
  ensure
    Account.reset_current_account
  end

  def test_normal_email_body_with_feature
    @account.launch :trim_special_characters
    email_body = '<p> hello this text is normal</p>'
    act_hash = { name: 'send_email_to_requester', email_to: 1, email_subject: 'Test Email', email_body: email_body }
    resp = Va::Action.new(act_hash).send(:substitute_placeholders, @ticket, :email_body)
    assert_equal resp, email_body
  ensure
    @account.rollback :trim_special_characters
    Account.reset_current_account
  end

  def test_normal_email_body_without_feature
    @account.rollback :trim_special_characters
    email_body = '<p> hello this text is normal</p>'
    act_hash = { name: 'send_email_to_requester', email_to: 1, email_subject: 'Test Email', email_body: email_body }
    resp = Va::Action.new(act_hash).send(:substitute_placeholders, @ticket, :email_body)
    assert_equal resp, email_body
  ensure
    Account.reset_current_account
  end

  def test_exclamation_along_with_image_data_should_not_replace_image
    @account.rollback :trim_special_characters
    email_body = '<pre data-placeholder=\"Translation\" dir=\"rtl\">&amp;lt;span dir=\"rtl\" lang=\"iw\"&amp;gt;חשבון\n &amp;lt;img src=\"https://attachment.freshdesk.com/inline/attachment?token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZCI6NDMxNTAwNzk3MDAsImRvbWFpbiI6ImhrY29ycC5mcmVzaGRlc2suY29tIiwiYWNjb3VudF9pZCI6OTU0NzQ0fQ.mlXBEZ787Qcy2lFg66rV9YzudG-YjC2wmZosAw2Xbk4\" style=\"width: auto; display: block; vertical-align: top; margin: 5px auto; text-align: center;\" data-attachment=\"[object Object]\" data-id=\"43150079700\"&amp;gt;היי\n שלום&amp;lt;/span&amp;gt;!!!testExclamation!!!</pre>'
    act_hash = { name: 'send_email_to_requester', email_to: 1, email_subject: 'Test Email', email_body: email_body }
    resp = Va::Action.new(act_hash).send(:substitute_placeholders, @ticket, :email_body)
    assert_equal true, email_body.include?('img src')
    assert_equal true, email_body.include?('!!!testExclamation!!!')
  ensure
    @account.rollback :trim_special_characters
    Account.reset_current_account
  end

  def test_replace_html_tags_with_spl_characters
    replace_type = ['hyphen', 'exclamation']
    email_body = '<p>check --- !!hii!!</p>'
    redcloth_content = RedCloth.new(email_body).to_html
    act_hash = { name: 'send_email_to_requester', email_to: 1, email_subject: 'Test Email', email_body: email_body }
    resp = Va::Action.new(act_hash).send(:replace_html_tags_with_spl_characters, redcloth_content, replace_type)
    assert_equal email_body, resp
  end
end
