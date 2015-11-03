/*global
  Class, jQuery, UIUtil, Template, Freshdesk, githubBundle, trim, freshdate, alert, escapeHtml
*/

var GithubWidget = Class.create();

GithubWidget.prototype = {
  GITHUB_FORM: new Template(
    '<div id = "github-create-link">' +
      '<ul class="nav nav-tabs nav-justified">' +
      '<li class="active"><a href="#github_issue_create" data-toggle="tab">Create Issue</a></li>' +
      '<li><a href="#github_issue_link" id="github_issue_toggle_link" data-toggle="tab">Link Issue</a></li>' +
      '</ul>' +
      '<div class = "tab-content">' +
      '<div class="field">' +
      '<label for="github-repositories">Repository</label> ' +
      '<select  class="full select2" data-dropdown-css-class="github_select_dropdown" id="github-repositories"> </select> ' +
      '</div>' +
      '<div id="github_issue_create" class="tab-pane fade in active">' +
      '#{github_milestone}' +
      '<div class="field">' +
      '<label>Title</label>' +
      '<input type="text" id="github-issue-title" value="#{github_title}" />' +
      '</div>' +
      '<div class="field button-container">' +
      '<input type="submit" id="github-create-submit" class="btn btn-primary"  value="Create Issue" disabled>' +
      '</div>' +
      '</div>' +
      '<div id="github_issue_link" class="tab-pane fade" > ' +
      '<div class="field">' +
      '<label>Issue ID</label>' +
      '<input type="text" id="github-issue-id"></input>' +
      '</div>' +
      '<div class="field button-container">' +
      '<input type="button" id="github-link-submit" class="btn btn-primary" value="Link Issue">' +
      '</div></div></div></div>' +
      '<div class="sloading loading-block loading-small loading-align" id="github-loading"></div>'
  ),

  GITHUB_ISSUE: new Template(
    '<div class="hide" id = "github-issue-display">' +
      '<div>' +
      '<span id="github-issue-title"></span>' +
      '<a id="github-unlink"> Unlink </a>' +
      '</div>' +
      '<ul>' +
      '<li>Repository:' +
      '<span id="github-issue-repository"></span>' +
      '</li>' +
      '<li>Status:' +
      '<span id="github-issue-status"></span>' +
      '</li>' +
      '<li>Milestone:' +
      '<span id="github-issue-milestone"></span>' +
      '</li>' +
      '<li>Assignee:' +
      '<span id="github-issue-assignee"></span>' +
      '</li>' +
      '</ul>' +
      '<div id="github-tracker"></div>' +
      '</div>' +
      '<div class="sloading loading-block loading-small loading-align" id="github-loading"></div>'
  ),

  GITHUB_MILESTONE_TEMPLATE: '<div class="field">' +
    '<label for="github-milestones">Milestone</label> ' +
    '<select  class="full select2" data-dropdown-css-class="github_select_dropdown" id="github-milestones" ></select> ' +
    '<div class="loading-fb" id="github-milestones-spinner"> </div></div>',

  initialize: function () {
    var init_reqs = [{
      source_url: "/integrations/service_proxy/fetch",
      event: 'integrated_resource',
      payload: JSON.stringify({ticket_id: githubBundle.ticket_rawId}),
      on_success: this.processResourceFetch.bind(this)
    }];
    this.widget_name = 'github_side_bar_widget';
    this.freshdeskWidget = new Freshdesk.Widget({
      app_name: "github",
      domain: githubBundle.domain,
      application_id: githubBundle.application_id,
      use_server_password: true,
      auth_type: 'NoAuth',
      login_html: null,
      widget_name: this.widget_name,
      init_requests: init_reqs
    });

    jQuery('#'+this.widget_name).on('change', '#github-repositories', this.repositoryChanged.bind(this))
      .on('click', '#github-create-submit', this.createIssue.bind(this))
      .on('click', '#github-link-submit', this.linkIssue.bind(this))
      .on('click', '#github-unlink', this.unlinkIssue.bind(this));
  },

  displayIssueRequest: function () {
    var options = githubBundle.remote_integratable_id.split('/issues/');
    return [{
      source_url: "/integrations/service_proxy/fetch",
      event: 'issue',
      payload: JSON.stringify({repository: options[0], number: options[1]}),
      on_failure: this.processIssueNotFound.bind(this),
      on_success: this.displayIssue.bind(this)
    }];
  },

  selectedRepository: function () {
    return jQuery('#github-repositories').val();
  },

  loadRepositories: function () {
    var data = githubBundle.repositories.map(function (x) {
      return {name: trim(x)};
    });
    UIUtil.constructDropDown(data, "json", "github-repositories", null, "name", ["name"], null, "");
    UIUtil.hideLoading('github', 'repositories', '');
    this.repositoryChanged();
  },

  repositoryChanged: function () {
    if (githubBundle.can_set_milestone === "1") {
      var repository = this.selectedRepository();
      jQuery('#github-create-submit').attr("disabled", true);
      UIUtil.showLoading("github", "milestones", "");
      jQuery("#github-milestones").select2("container").hide();
      this.freshdeskWidget.request({
        source_url: '/integrations/service_proxy/fetch',
        event: 'milestones',
        payload: JSON.stringify({repository: repository}),
        on_success: this.loadMilestones.bind(this),
        on_failure: this.processFailure.bind(this)
      });
      return;
    }
    jQuery('#github-create-submit').prop('disabled', false);
  },

  loadMilestones: function (resData) {
    var response = resData.responseJSON || [];
    response.map(
      function (milestone) {
        milestone.title += milestone.due_on ? " (" + new Date(milestone.due_on).toDateString() + ")" : ' <No Due Date>';
        return milestone;
      }
    );
    UIUtil.constructDropDown(response, "json", "github-milestones", null, "number", ["title"], null, "");
    UIUtil.addDropdownEntry("github-milestones", "", "-None-", true);
    jQuery("#github-milestones").select2("val", "");
    UIUtil.hideLoading('github', 'milestones', '');
    jQuery("#github-milestones").select2("container").show();
    jQuery('#github-create-submit').prop('disabled', false);
  },

  createIssue: function () {
    var repository = this.selectedRepository(),
      milestone = jQuery('#github-milestones').val(),
      title = jQuery('#github-issue-title').val(),
      issue = {
        repository: repository,
        local_integratable_id: githubBundle.ticket_rawId,
        title: title,
        body: jQuery("#github-note").text(),
        options: {
          milestone: milestone
        }
      };
    this.showSpinner();
    this.freshdeskWidget.request({
      source_url: "/integrations/service_proxy/fetch",
      app_name: 'github',
      event: 'create_issue',
      payload: JSON.stringify(issue),
      on_success: this.createOrLinkIssueSuccess.bind(this),
      on_failure: this.processFailure.bind(this),
    });
    return false;
  },

  createOrLinkIssueSuccess: function (resData) {
    var resJson = resData.responseJSON;
    githubBundle.integrated_resource_id = resJson.id;
    githubBundle.remote_integratable_id = resJson.remote_integratable_id;
    this.renderDisplayIssueWidget();
  },

  renderDisplayIssueWidget: function () {
    this.freshdeskWidget.options.init_requests = this.displayIssueRequest();
    this.freshdeskWidget.options.application_html = this.GITHUB_ISSUE.evaluate({});
    this.freshdeskWidget.display();
    this.freshdeskWidget.call_init_requests();

    //Show loading
    this.showSpinner();

  },

  displayIssue: function (resData) {
    var resJson = resData.responseJSON,
        issueLink = resJson.html_url,
        issueTitleHTML = "<a target='_blank' href='" + issueLink + "'>"  + " #" + resJson.number + " - " + escapeHtml(resJson.title) + "</a>",
        issueStatus = resJson.state,
        issueMilestone = resJson.milestone ? resJson.milestone.title : "<None>",
        issueAssignee = resJson.assignee ? resJson.assignee.login : "<No one>",
        repoRegex = /https:\/\/github\.com\/(.*)\/issues\/\d*$/,
        issueRepository = repoRegex.exec(issueLink)[1],
        tracker_ticket = resJson.tracker_ticket,
        tracker_html = "Track issue updates on Freshdesk Ticket <a target='_blank' href='" + tracker_ticket.link + "'>#" + tracker_ticket.id + "<a>";
    if (resJson.milestone) {
      issueMilestone += resJson.milestone.due_on ? " (" + new Date(resJson.milestone.due_on).toDateString() + ")" : ' <No Due Date>';
    }
    jQuery('#github-issue-title').html(issueTitleHTML);
    jQuery('#github-issue-status').text(issueStatus);
    jQuery('#github-issue-repository').text(issueRepository);
    jQuery('#github-issue-milestone').text(issueMilestone);
    jQuery('#github-issue-assignee').text(issueAssignee);

    if (tracker_ticket && tracker_ticket.id != githubBundle.ticketId) {
      jQuery('#github-tracker').html(tracker_html);
    }
    this.displayIssueWidgetStatus = false;
    this.hideSpinner();
  },

  displayCreateWidget: function () {
    this.freshdeskWidget.options.application_html = this.displayFormContent();
    this.freshdeskWidget.display();
    jQuery('#github-tabs').tabs();
    this.loadRepositories();
    this.hideSpinner();
  },

  displayIssueContent: function () {
    return this.GITHUB_ISSUE.evaluate({});
  },

  displayFormContent: function () {
    return this.GITHUB_FORM.evaluate({
      github_milestone: githubBundle.can_set_milestone === '1' ? this.GITHUB_MILESTONE_TEMPLATE : '',
      github_title: githubBundle.ticketSubject
    });
  },

  displayLinkWidget: function () {
    this.displayCreateWidget();
    jQuery('#github_issue_toggle_link').click();
  },

  linkIssue: function () {
    var repository = this.selectedRepository(),
      issue_id = jQuery('#github-issue-id').val(),
      payload = {
        repository: repository,
        local_integratable_id: githubBundle.ticket_rawId,
        number: issue_id
      };

    this.showSpinner();
    this.freshdeskWidget.request({
      source_url: "/integrations/service_proxy/fetch",
      event: 'link_issue',
      payload: JSON.stringify(payload),
      on_success: this.createOrLinkIssueSuccess.bind(this),
      on_failure: this.processFailure.bind(this),
    });
    return false;
  },

  unlinkIssue: function () {
    this.showSpinner();
    if (githubBundle.integrated_resource_id) {
      this.freshdeskWidget.request({
        source_url: "/integrations/service_proxy/fetch",
        event: 'unlink_issue',
        payload: JSON.stringify({integrated_resource_id: githubBundle.integrated_resource_id}),
        on_success: this.unlinkIssueSuccess.bind(this),
        on_failure: this.processFailure.bind(this)
      });
    }
  },

  unlinkIssueSuccess: function () {
    githubBundle.integrated_resource_id = "";
    githubBundle.remote_integratable_id = "";
    this.displayCreateWidget();
  },

  showSpinner: function () {
    jQuery('#github-create-link, #github-issue-display').hide();
    jQuery('#github-loading').show();
    jQuery('#github_side_bar_widget .error').html('');
  },

  hideSpinner: function () {
    jQuery('#github-loading').hide();
    jQuery('#github-create-link, #github-issue-display').show();
  },

  processFailure: function (evt) {
    this.freshdeskWidget.alert_failure("The following error was reported: " + evt.responseJSON.message || evt.responseJSON);
    this.hideSpinner();
    this.freshdeskWidget.content_element.innerHTML = '';
  },

  processIssueNotFound: function (evt) {
    if (evt.status === 404) {
      this.freshdeskWidget.delete_integrated_resource(githubBundle.integrated_resource_id);
    }
    this.processFailure(evt);
  },

  processResourceFetch: function (resData) {
    var resJson = resData.responseJSON;
    if (resJson.id) {
      githubBundle.integrated_resource_id = resJson.id;
      githubBundle.remote_integratable_id = resJson.remote_integratable_id;
      this.renderDisplayIssueWidget();
    } else {
      this.displayCreateWidget();
    }
  }
};
