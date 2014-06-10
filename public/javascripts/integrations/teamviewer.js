var TeamViewerWidget = Class.create();
var teamviewerSession = {};
TeamViewerWidget.prototype = {
    TechConsole: new Template(
            '<div class="remote_support">Start a new TeamViewer Session and copy instructions to the ticket' +
            '<div class="session_data">' +
            '<div class="pin_submit"><input type="submit" id="pinsubmit" class="uiButton" value="New Remote Session" onclick="teamviewerWidget.generateSessionCode();return false;" /></div>' +
            '<div class="tech_console"><a target="_blank" href="https://login.teamviewer.com/">Launch Management Console...</a></div></div>' +
            '<div class="session_pin hide">' +
            '<span class="seperator"></span>' +
            '<span class="active_header">Last generated session</span>' +
            '<div class="active_session_pin">' +
            '<div class="pincode">Session Code : #{sessionCode}</div>' +
            '<div class="pintime">Generated <abbr data-livestamp=#{livestamp}>#{pintime}</abbr></div></div>' +
            '<div class="resend"><a href="#" id="teamviewer_copy_to_tkt">Resend Instructions</a></div>' +
            '<div class="tech_console"><a target="_blank" href="#{techTicket}">Launch Supporter Software...</a></div>' +
            '</div></div>'
            ),
    SessionInstructions: new Template(
            '<hr /><b>Remote Session Instructions</b><br />' +
            'SessionCode : #{sessionCode}<br/><br/>' +
            'Click the link below to start your remote session<br/>' +
            '<a href=\"#{endCustomerLink}">#{endCustomerLink}</a><br /><br />' +
            '<hr/><br/>'
            ),
    initialize: function(teamviewerBundle) {
        jQuery("#teamviewer_widget").addClass('loading-fb');
        teamviewerWidget = this;
        this.teamviewerBundle = teamviewerBundle;
        this.freshdeskWidget = new Freshdesk.Widget({
            //application_id:teamviewerBundle.application_id,
            //widget_name: "test_widget",
            //integratable_type: "remote_support",
            //anchor: "teamviewer_widget",
            app_name: "TeamViewer",
            domain: "webapi.teamviewer.com",
            ssl_enabled: "true",
            auth_type: "OAuth",
            oauth_token: teamviewerBundle.token,
            header_auth: true,
            useBearer: true
        });
        this.getSessions();
    },
    getSessions: function() {
        sessionsEndpoint = "api/v1/sessions?full_list=true";
        this.freshdeskWidget.request({
            rest_url: sessionsEndpoint,
            on_failure: this.processFailure,
            on_success: this.processSessions.bind(this),
        });
    },
    processSessions: function(response) {
        if (response.status == 200) {
            response = response.responseJSON;
            existing = response.sessions.length;
            if (existing) {
                teamviewerSession = response.sessions.shift();
            }
            else {
                teamviewerSession = {
                    supporter_link: null,
                    end_customer_link: null,
                    code: null,
                    created_at: null,
                    valid_until: null,
                    state: "Closed"
                };
            }
            this.renderTechConsole();
            jQuery("#teamviewer_widget").removeClass('loading-fb');
        }
        else
            this.handleError(response);
    },
    renderTechConsole: function() {
        var livestamp_time = new Date(teamviewerSession.created_at).getTime() / 1000;
        this.freshdeskWidget.options.application_html = function() {
            return teamviewerWidget.TechConsole.evaluate({
                techTicket: teamviewerSession.supporter_link,
                sessionCode: teamviewerSession.code,
                livestamp: livestamp_time,
                pintime: teamviewerSession.created_at
            });
        };
        this.freshdeskWidget.options.init_requests = null;
        this.freshdeskWidget.display();
        if (this.isSessionCodeValid()) {
            jQuery('.session_pin').removeClass("hide");
            jQuery("#teamviewer_copy_to_tkt").click(function(ev) {
                ev.preventDefault();
                teamviewerWidget.copySessionCode(teamviewerSession.code);
            });
        }
    },
    generateSessionCode: function() {
        jQuery('#pinsubmit').prop('value', 'Generating SessionCode...');
        jQuery('#pinsubmit').attr('disabled', 'disabled');
        sessionCodeEndpoint = "api/v1/sessions";
        params = {
            groupname: "Freshdesk",
            custom_api: teamviewerBundle.ticketId,
            description: teamviewerBundle.ticketSubject,
            end_customer: {
                name: teamviewerBundle.reqName,
                email: teamviewerBundle.reqEmail
            }
        };
        this.freshdeskWidget.request({
            rest_url: sessionCodeEndpoint,
            on_failure: this.processFailure,
            on_success: this.processSessionCode.bind(this),
            method: "post",
            body: JSON.stringify(params)
        });
    },
    processSessionCode: function(response) {
        if (response.status == 200) {
            response = response.responseJSON;
            jQuery('#pinsubmit').prop('value', 'New Remote Session');
            jQuery('#pinsubmit').removeAttr('disabled');
            teamviewerSession = response;
            teamviewerSession.created_at = new Date().toString();
            this.copySessionCode(teamviewerSession.code);
            this.renderTechConsole();
        }
        else
            this.handleError(response);
    },
    copySessionCode: function() {
        var sessionCodeInstructions = teamviewerWidget.SessionInstructions.evaluate({sessionCode: teamviewerSession.code, endCustomerLink: teamviewerSession.end_customer_link});
        jQuery('#ReplyButton').trigger("click");
        insertIntoConversation(sessionCodeInstructions, 'cnt-reply-body');
    },
    isSessionCodeValid: function() {
        if (typeof teamviewerSession.state == 'undefined' || teamviewerSession.state.toLowerCase() == "open") {
            if (new Date(teamviewerSession.valid_until) > new Date()) {
                return true;
            }
        }
        return false;
    },
    handleError: function(response) {
        if (response.status == 401)
            errorMsg = "Authorisation failed. Please verify your token and try again";
        if (response.status == 500)
            errorMsg = "TeamViewer Error. Please try again later";
        else
            errorMsg = "Unable to contact TeamViewer. Please try again later";

        this.freshdeskWidget.alert_failure(errorMsg);
    }
};
teamviewerWidget = new TeamViewerWidget(teamviewerBundle);