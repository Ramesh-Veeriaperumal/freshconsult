require 'action_view/helpers'

module ValidatesCaptcha
  module Provider
    # A question/answer captcha provider.
    class Question
      include ActionView::Helpers

      DEFAULT_QUESTIONS_AND_ANSWERS = {
"What's the sum of two and three?" => ["5", "five"],
"What's the sum of five and six?" => ["11", "eleven"],
"What's the sum of three and four?" => ["7", "seven"],
"What's the sum of one and two?" => ["3", "three"],
"What's the sum of one and three?" => ["4", "four"],
"What's the sum of one and four?" => ["5", "five"],
"What's the sum of one and five?" => ["6", "six"],
"What's the sum of one and six?" => ["7", "seven"],
"What's the sum of one and seven?" => ["8", "eight"],
"What's the sum of one and eight?" => ["9", "nine"],
"What's the sum of one and nine?" => ["10", "ten"],
"What's the sum of two and four?" => ["6", "six"],
"What's the sum of two and five?" => ["7", "seven"],
"What's the sum of two and six?" => ["8", "eight"],
"What's the sum of two and seven?" => ["9", "nine"]
        }.freeze

      @@questions_and_answers = DEFAULT_QUESTIONS_AND_ANSWERS

      class << self
        # Returns the current captcha questions/answers hash. Defaults to
        # DEFAULT_QUESTIONS_AND_ANSWERS.
        def questions_and_answers
          @@questions_and_answers
        end

        # Sets the current captcha questions/answers hash. Used to set a
        # custom questions/answers hash.
        def questions_and_answers=(qna)
          @@questions_and_answers = qna
        end
      end

      # This method is the one called by Rack.
      #
      # It returns HTTP status 404 if the path is not recognized. If the path is
      # recognized, it returns HTTP status 200 and delivers a new challenge in
      # JSON format.
      #
      # Please take a look at the source code if you want to learn more.
      def call(env)
        if env['PATH_INFO'] == regenerate_path
          captcha_challenge = generate_challenge
          json = { :captcha_challenge => captcha_challenge }.to_json

          [200, { 'Content-Type' => 'application/json' }, [json]]
        else
          [404, { 'Content-Type' => 'text/html' }, ['Not Found']]
        end
      end

      # Returns a captcha question.
      def generate_challenge
        self.class.questions_and_answers.keys[rand(self.class.questions_and_answers.keys.size)]
      end

      # Returns true if the captcha was solved using the given +question+ and +answer+,
      # otherwise false.
      def solved?(question, answer)
        return false unless self.class.questions_and_answers.key?(question)
        answers = Array.wrap(self.class.questions_and_answers[question]).map(&:downcase)
        answers.include?(answer.downcase)
      end

      # Returns a span tag with the inner HTML set to the captcha question.
      #
      # Internally calls Rails' +content_tag+ helper method, passing the +options+ argument.
      def render_challenge(sanitized_object_name, object, options = {})
        options[:id] = "#{sanitized_object_name}_captcha_question"

        content_tag :span, object.captcha_challenge, options
      end

      # Returns an anchor tag that makes an AJAX request to fetch a new question and updates
      # the captcha challenge after the request is complete.
      #
      # Internally calls Rails' +link_to_remote+ helper method, passing the +options+ and
      # +html_options+ arguments. So it relies on the Prototype javascript framework
      # to be available on the web page. As of version 0.9.8 you can pass <tt>:jquery => true</tt>
      # as an option to render Javascript that's based on jQuery.
      #
      # The anchor text defaults to 'New question'. You can set this to a custom value
      # providing a +:text+ key in the +options+ hash.
      def render_regenerate_challenge_link(sanitized_object_name, object, options = {}, html_options = {})
        text = options.delete(:text) || 'New question'
        if options.delete(:jquery)
          onclick = "jQuery.getJSON('#{regenerate_path}', function(result){jQuery('##{sanitized_object_name}_captcha_question').text(result.captcha_challenge); jQuery('##{sanitized_object_name}_captcha_challenge').val(result.captcha_challenge); jQuery('##{sanitized_object_name}_captcha_solution').val('');});return false;"
          link_to text, "#", options.reverse_merge(:onclick => onclick), html_options
        else
          success = "var result = request.responseJSON; $('#{sanitized_object_name}_captcha_question').update = result.captcha_challenge; $('#{sanitized_object_name}_captcha_challenge').value = result.captcha_challenge; $('#{sanitized_object_name}_captcha_solution').value = '';"
          link_to_remote text, options.reverse_merge(:url => regenerate_path, :method => :get, :success => success), html_options
        end
      end

      private
        def regenerate_path #:nodoc:
          '/captchas/regenerate'
        end

        # This is needed by +link_to_remote+ called in +render_regenerate_link+.
        def protect_against_forgery? #:nodoc:
          false
        end

        def solve(challenge) #:nodoc:
          Array.wrap(self.class.questions_and_answers[challenge]).first
        end
    end
  end
end

