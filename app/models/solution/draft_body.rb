class Solution::DraftBody < ActiveRecord::Base
  self.table_name = 'solution_draft_bodies'

  belongs_to_account
  belongs_to :draft, class_name: 'Solution::Draft'
  attr_accessible :description, :desc_un_html
  # xss_sanitize only: [:description], article_sanitizer: [:description] This can be uncommented, if there's no complaints after inclusion of emoji

  def description=(val)
    val = Helpdesk::HTMLSanitizer.sanitize_article(val)
    if Account.current.launched?(:encode_emoji_in_solutions)
      val = UnicodeSanitizer.utf84b_html_c(val)
    else
      val = UnicodeSanitizer.remove_4byte_chars(val)
    end
    write_attribute(:description, val)
  end
end
