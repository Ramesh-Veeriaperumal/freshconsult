module EmailActionsHelper
  def confirm_action(options)
    data = {
      '@context' => 'http://schema.org',
      '@type' => 'EmailMessage',
      'action' => {
        '@type' => 'ConfirmAction',
        'name' => options[:name],
        'handler' => {
          '@type' => 'HttpActionHandler',
          'url' => options[:url]
        }
      }
    }
    content_tag :script, type: 'application/ld+json' do
      data.to_json.html_safe
    end
  end

  def view_action(options)
    data = {
      '@context' => 'http://schema.org',
      '@type' => 'EmailMessage',
      'action' => {
        '@type' => 'ViewAction',
        'name' => options[:name],
        'url' => options[:url]
      }
    }
    content_tag :script, type: 'application/ld+json' do
      data.to_json.html_safe
    end
  end
end
