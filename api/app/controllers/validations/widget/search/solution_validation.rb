module Widget
  module Search
    class SolutionValidation < ApiValidation
      attr_accessor :page, :per_page
      include Widget::Search::SolutionConstants

      validates :page, custom_numericality:
                        {
                          only_integer: true,
                          greater_than: 0,
                          ignore_string: :allow_string_param,
                          less_than_or_equal_to: MAX_PAGE,
                          custom_message: :limit_invalid,
                          message_options:
                          {
                            max_value: MAX_PAGE
                          }
                        }
      validates :per_page, custom_numericality:
                            {
                              only_integer: true,
                              greater_than: 0,
                              ignore_string: :allow_string_param,
                              less_than_or_equal_to: MAX_PER_PAGE,
                              custom_message: :per_page_invalid,
                              message_options:
                              {
                                max_value: MAX_PER_PAGE
                              }
                            }
    end
  end
end
