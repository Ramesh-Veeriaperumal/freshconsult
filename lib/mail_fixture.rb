module MailFixture
  FIXTURES_PATH = Rails.root + '/test/fixtures/emails'
  CHARSET = "utf-8"
  def read_fixture(fixture)
    IO.read("#{MailFixture::FIXTURES_PATH}/#{fixture}")
  end
end
