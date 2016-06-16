/*jslint browser: true, devel: true */
/*global  App, FreshWidget, escapeHtml */

window.App = window.App || {};

(function ($) {
    "use strict";
    
    App.ProductNotification = {
        suggestDelay : null,
        url : "https://support.freshdesk.com",

        articles: [{title : "Converting your Support Email into Freshdesk Tickets", url : "/support/solutions/articles/37541-converting-your-support-email-into-freshdesk-tickets"},
                   {title : "Rebranding your Support Portal to reflect your Theme", url : "/support/solutions/articles/37563-rebranding-your-support-portal-to-reflect-your-theme"},
                   {title : "Single Sign On / Remote Authentication in Freshdesk", url : "/support/solutions/articles/31166-single-sign-on-remote-authentication-in-freshdesk"},
                   {title : "Using a Vanity Support URL and pointing the CNAME", url : "/support/solutions/articles/37590-using-a-vanity-support-url-and-pointing-the-cname"},
                   {title : "Configuring and using Email Notifications", url : "/support/solutions/articles/37542-configuring-and-using-email-notifications"},
                   {title : "Customizing your ticket form", url : "/support/solutions/articles/37595-customizing-the-ticket-form"},
                   {title : "Creating an SPF record to ensure proper email delivery", url : "/support/solutions/articles/43170-creating-an-strong-spf-strong-strong-record-strong-to-ensure-proper-email-delivery"},
                   {title : "Using FreshPlugs to integrate third party Apps", url : "/support/solutions/articles/32031-using-freshplugs-to-integrate-third-party-apps"},
                   {title : "Getting feedback from your website (with the Feedback Widget)", url : "/support/solutions/articles/37690-getting-feedback-from-your-website-with-the-feedback-widget-"},
                   {title : "Adding new support agents", url : "/support/solutions/articles/37591-adding-new-support-agents-"}],

        contacts: [{country : "USA & Canada", phone : "+1 866 832-3090"},
                   {country : "UK", phone : "+44 800 808-5790"},
                   {country : "Australia", phone : "+61 894 687-228"}], 

        initialize: function () {
            this.bindDocumentClick();
            this.bindNotification();
            this.bindSearchField();
            this.bindTabClick();
            this.bindFeedbackLink();
            this.bindSeeAllOnSearch();
            this.renderArticleTemplate(this.articles);
            this.renderContactTemplate(this.contacts);
        },
        searchArticles: function (searchInput) {
            var searchString = searchInput.replace(/^\s+|\s+$/g, "");

            if (searchString !== '' && searchString.length > 2) {
                this.searchCallback(searchString);
            } else {
                $("#notify-result").empty();
                this.renderArticleTemplate(this.articles);
                $("#search-clear").addClass("hide");
                this.appendSearchHeader(0, "hide");
                $("#fra-result").removeClass("hide");
            }
        },
        searchCallback: function (string) {
            $("#notification-article").addClass("loading-right");
            $("#search-clear").addClass("hide");

            var term = string.trim(),
                suggest_url = this.url + "/support/search/solutions.json",
                request = { term: term };
            $.ajax({
                type: 'get',
                url: suggest_url,
                dataType: 'jsonp',
                data: request,
                success: $.proxy(function (data) {
                    this.suggestResponse(data, term);
                }, this)
            });
        },
        suggestResponse: function (data, term) {
            $("#fra-result").addClass("hide");

            if (data.length > 0) {
                this.appendSearchHeader(data.length, "show");
                $("#notify-result").html($.tmpl($("#article-tmpl").template(), data));
            } else {
                this.appendSearchHeader(0, "show");
                $("#notify-result").html("<p class='no_result'>No results for " + escapeHtml(term) + "</p>");
            }

            $("#notification-article").removeClass("loading-right");
            $("#search-clear").removeClass("hide");
        },
        appendSearchHeader: function (length, type) {
            var reverse_type = (type === "show") ? "hide" : "show";
            $("#search-result-header").html("")
                            .html("<span> ( " + length + " ) matching results </span><a target='_blank' id='seeAll' href='#'>See All</a>")
                            .removeClass(reverse_type).addClass(type);
        },
        addNotificationClass: function (timeStamp) {
            if(timeStamp != "") {
                var lastUpdatedDate = $($("#content-notify").children()[0]).data("timeStamp");
                if(lastUpdatedDate > timeStamp) {
                    jQuery('#notifiication-icon').click();
                } 
            } else {
                 jQuery('#notifiication-icon').click();
            }
        },
        addHref: function (ev, link) {
            $(ev.currentTarget).attr("href", this.url + link);
        },
        renderArticleTemplate: function (data) {
            $("#notify-result").html($.tmpl($("#article-tmpl").template(), data));
        },
        renderContactTemplate: function (data) {
            $("#help-us").html($.tmpl($("#help-us-tmpl").template(), data));
        },
        bindDocumentClick: function () {
            $(document).on("click.productnotification", function (ev) {
                var parent_check = $(ev.target).parents(".tabbable");
                if (!parent_check.get(0)) {
                    $("#popoverContent").addClass("hide");
                    $("#notifiication-icon").removeClass("active");
                }
            });
        },
        bindNotification: function () {
            $(document).on("click.productnotification","#notifiication-icon",function(ev){
                ev.stopPropagation();
                $("#popoverContent").toggleClass('hide');
                if ($(ev.currentTarget).hasClass("notification_present")) {
                    $.ajax({
                        type: "POST",
                        data: { "_method" : "put" },
                        url: "/profiles/notification_read",
                        success: function () {
                            $("#notifiication-icon").removeClass("notification_present");
                        }
                    });
                }
                $(ev.currentTarget).addClass("active");
            })
        },
        bindFeedbackLink: function () {
            $(document).on("click.productnotification", "#notify-feedback", function () {
                $("#popoverContent").addClass("hide");
                $("#notifiication-icon").removeClass("active");
                FreshWidget.show();
            });
        },
        bindSearchField: function () {
            $(document).on("keydown.productnotification change.productnotification paste.productnotification", "#notification-article" ,$.proxy(function(ev){
                var $this = jQuery(ev.currentTarget);
                clearTimeout(this.suggestDelay);
                this.suggestDelay = setTimeout($.proxy(function() {
                    this.searchArticles($this.val())
                },this), 500)

                if(ev.keyCode == 13){
                    ev.preventDefault();
                    return false;
                }
            },this));

            $(document).on("click.productnotification", "#search-clear", function (ev) {
                ev.preventDefault();
                ev.stopPropagation();
                $("#notification-article").val("");
                $(this).addClass("hide");
                $("#notification-article").trigger('change');
            });
        },
        bindTabClick: function () {
            $(document).on("click.productnotification", "#notify-remote-data", function (e) {
                e.preventDefault();
                e.stopPropagation();
                $("#notification-article")[0].focus();
            });
        },
        bindSeeAllOnSearch: function () {
            $(document).on("click.productnotification", "#seeAll", $.proxy(function (ev) {
                var link = "/support/search/solutions?term=" + $("#notification-article").val();
                this.addHref(ev, link);
            }, this));
        },
        destroy: function () {
            $(document).off(".productnotification");
        }
    };
}(window.jQuery));