class Solution::TemplatesMigrationWorker < BaseWorker
  sidekiq_options queue: :solution_templates_migration_worker, retry: 4, failures: :exhausted

  SAMPLE_TEMPLATES = [{ title: '[Sample] User Guide template', description: '<p class="fd-toc">You can make use of a user guide to help a user get a complete understanding of a feature or a product. For example, this is how a user guide might look for using article template</p><p><br></p><p class="fd-toc"><strong>TABLE OF CONTENTS</strong></p><ul><li><a href="#Introduction-to-templates">Introduction to templates</a></li><li><a href="#Creating-templates">Creating templates</a></li><li><a href="#Using-templates">Using templates</a></li></ul><p><br></p><h2 id="Introduction-to-templates">Introduction to templates</h2><p>Standardize your knowledge base by creating templates such as a simple FAQ-style article, step-by-step guides, How-To, Release notes, and a lot more. Your team can simply choose from the predefined templates and start creating their articles from there - saving them time.</p><p><br></p><h2 id="Creating-templates">Creating templates</h2><ol><li>Go to Knowledge Base</li><li>Click on the hamburger menu on the top left</li><li>Select Article templates</li><li>Click on New template and start creating your template</li></ol><p><br></p><pre class="fd-callout fd-callout--idea">Mark a template as default to load it automatically while creating a new article. </pre><p><br></p><h2 id="Using-templates">Using templates</h2><ol><li>Once you save a template, click on <strong>Use template </strong>to open the template as a new article</li><li>Make the relevant changes to the template and save the article</li></ol>' },
                      { title: "[Sample] 'How to' template", description: "<p>Give an introduction to the topic of this How-to article. For example, let's consider that this article explains how to use article template</p><p><br></p><h1 id=\"Instructions-to-use-article-templates\">Instructions to use article templates</h1><p><br></p><p>Create a step-by-step guide</p><div class=\"fd-toc\"><ul><li><a href=\"#Step-1%3A-Access-the-template-list-view\">Step 1: Access the template list view</a></li><li><a href=\"#Step-2%3A-Populate-the-content-in-the-template\">Step 2: Populate the content in the template</a></li><li><a href=\"#Step-3%3A-Using-the-template-in-your-article\">Step 3: Using the template in your article</a></li></ul></div><p><br></p><h3 id=\"Step-1:-Access-the-template-list-view\">Step 1: Access the template list view</h3><ul><li>Explain the relevant actions to be performed </li></ul><p><br></p><h3 id=\"Step-2:-Populate-the-content-in-the-template\">Step 2: Populate the content in the template</h3><ul><li>Explain the actions under this step</li></ul><p><br></p><h3 id=\"Step-3:-Using-the-template-in-your-article\">Step 3: Use the template in your article</h3><ul><li>Explain the actions under this step</li></ul><p><br></p><pre class=\"fd-callout fd-callout--note\">Use the callout cards to highlight anything important about any of the steps mentioned above</pre><p><br></p><p>Add a video to help users understand the steps visually</p><p><br></p><p><span class=\"fr-video fr-fvc fr-dvb fr-draggable\"><iframe width=\"640\" height=\"360\" src=\"https://www.youtube.com/embed/U0_6R8oVbGM?&amp;t=15s&amp;wmode=opaque\" frameborder=\"0\" allowfullscreen=\"\" class=\"fr-draggable\" sandbox=\"allow-scripts allow-forms allow-same-origin allow-presentation\"></iframe></span><br></p><p><br></p><p><br></p>" },
                      { title: '[Sample] FAQ template', description: "<pre class=\"fd-callout fd-callout--note\">Add your Table of content for your FAQ</pre><div class=\"fd-toc\"><p><a href=\"#Content-creation-FAQs\"><br></a></p><ul><li><a href=\"#Content-creation-FAQs\">Content creation FAQs</a></li><li><a href=\"#Content-management-FAQs\">Content management FAQs</a></li></ul></div><h3 id=\"Content-creation-FAQs\">Content creation FAQs</h3><ul><li>How to add callout cards to my content?<br>You can insert callout cards using <a href=\"https://support.freshdesk.com/support/solutions/articles/50000002051-using-advanced-formatting-options-in-the-knowledge-base\">quick insert</a></li></ul><p><br></p><ul><li>How to automatically generate a Table of content for my article?<br>The <a href=\"https://support.freshdesk.com/support/solutions/articles/50000002051-using-advanced-formatting-options-in-the-knowledge-base#A-quick-guide-to-using-Table-of-content\">Table of content</a> can be created based on the heading of each section in an article. Click on TOC on your text editor once you have added the headers using the paragraph format</li></ul><p><br></p><ul><li>How to track multiple versions for my article?<br>You can navigate to the Versions section of an article to access all the previous versions and to track <a href=\"https://support.freshdesk.com/support/solutions/articles/50000001088-working-with-article-versioning\">how your article has evolved </a></li></ul><p><br></p><ul><li>How to add a code snippet to my article?<br>To add a code snippet, click on the Insert code icon on the text editor in your knowledge base article. This will open a popup window where you can enter the code that has to be displayed in the snippet as shown below</li></ul><p><br></p><div><pre contenteditable=\"false\" data-code-brush=\"Html\" rel=\"highlighter\">&lt;body&gt;\n&lt;p&gt;This is a sample code snippet&lt;/p&gt;\n&lt;/body&gt;</pre><p><br></p></div><hr><h3 id=\"Content-management-FAQs\">Content management FAQs</h3><p><br></p><ul><li>How to filter articles based on its properties?<br>Go to the <a href=\"https://support.freshdesk.com/support/solutions/articles/50000000122-working-with-article-list-view\">article list views</a> and enter the values based on which the articles have to be filtered</li></ul><p><br></p><ul><li>How to reorder articles automatically?<br>Go to <strong>Manage</strong> under the <strong>Solutions tab</strong> and click on the edit button that appears when you hover over the relevant folder. In the window that opens, click on the Order articles drop-down and select how you want the article to be sorted</li></ul><p><br></p><ul><li>How to perform bulk actions on articles?<br>Go to the <a href=\"https://support.freshdesk.com/support/solutions/articles/50000000122-working-with-article-list-view\">article list views</a> and filter the articles on which you want to perform bulk actions. Then select the bulk action that you would like to perform from the button that appears over the list of articles</li></ul><p><br></p><ul><li>How to make my folder visible to a specific customer segment?<br>Click on the folder for which you would like to control the visibility and select the <strong>Visible to</strong> Drop-down. There you can select from the list of <a href=\"https://support.freshdesk.com/support/solutions/articles/235358-personalize-your-support-using-customer-segments\">customer/company segment</a> that you have already created</li></ul><p><br></p><p><br></p>" }].freeze

  def perform(args)
    args.symbolize_keys!
    @action = args[:action]
    Rails.logger.info "Running solution templates migration for [#{Account.current.id},#{@action}]"
    account_admin = Account.current.account_managers.first
    if account_admin.nil?
      Rails.logger.info "Not able to run migrations for [#{Account.current.id},#{@action}] since account admin not found"
      NewRelic::Agent.notice_error(e, account: Account.current.id, description: "Account admin not found for solution templates migration for [#{Account.current.id},#{@action}]")
    else
      account_admin.make_current
      safe_send("#{@action}_solutions_templates")
    end
  rescue => e # rubocop:disable RescueStandardError
    Rails.logger.info "Exception solutions_templates feature migration for [#{Account.current.id},#{@action}] #{e.message} - #{e.backtrace}"
    NewRelic::Agent.notice_error(e, account: Account.current.id, description: "Exception while solution templates migration for [#{Account.current.id},#{@action}] #{e.message} - #{e.backtrace}")
  ensure
    User.reset_current_user
  end

  private

    def add_solutions_templates
      SAMPLE_TEMPLATES.each do |sample_template|
        next unless Account.current.solution_templates.where(title: sample_template[:title]).first.nil?

        Account.current.solution_templates.build(
          title: sample_template[:title],
          description: sample_template[:description]
        )
      end
      Account.current.save!
    end

    def drop_solutions_templates
      Account.current.solution_templates.destroy_all
    end
end
