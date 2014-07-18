/*jslint browser: true, devel: true */
/*global  App, FreshWidget, escapeHtml */

window.App = window.App || {};

(function ($) {
    "use strict";
    
    App.ProductNotification = {
        suggestDelay : null,
        url : "https://support.freshdesk.com",
        articles: [{title : "Rebranding your support portal to reflect your theme", url : ""},
                   {title : "Single Sign On / Remote Authentication in Freshdesk", url : ""},
                   {title : "Customizing Ticket Form", url : ""},
                   {title : "How to Publish your FreshTheme to the Themes Gallery?", url : ""}],
        contacts: [{country : "America", phone : "+1 866 832-3090"},
                   {country : "Europe", phone : "+44 800 808-5790"},
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
                    jQuery("#notifiication-icon").addClass("notification_present");
                } 
            } else {
                 jQuery("#notifiication-icon").addClass("notification_present");
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
                }
            });
        },
        bindNotification: function () {
            jQuery(document).on("click.productnotification","#notifiication-icon",function(ev){
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
            })
        },
        bindFeedbackLink: function () {
            $(document).on("click.productnotification", "#notify-feedback", function () {
                $("#popoverContent").addClass("hide");
                FreshWidget.show();
            });
        },
        bindSearchField: function () {
            jQuery(document).on("keydown.productnotification change.productnotification paste.productnotification", "#notification-article" ,$.proxy(function(ev){
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