# Be sure to restart your server when you modify this file.

ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.merge!(  
  :us => '%m/%d/%y',
  :us_with_time => '%m/%d/%y, %l:%M %p',
  :short_day => '%e %B %Y',
  :long_day => '%A, %e %B %Y',
  :long_day_with_time => '%A, %e %B %Y, %l:%M %p',
  :short_day_with_week => "%a, %b %e, %Y",
  :short_day_with_time => "%a, %b %e, %Y at %l:%M %p",
  :javascript_date => '%Y-%m-%dT%H:%M:%S.%3N-%Z'
)
