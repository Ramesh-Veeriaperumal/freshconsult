(function($){
  "use strict";

  var FreddyEmailBot = function() {
    this.usefulness = {
      yes: true,
      no: false,
      no_response: undefined
    };
    this.requiredTab = "solutions"
    this.portal_url_vars = '';
    this.portal = portal;
    this.baseUrl = '/api/_/email-bots';
    this.filterUrl = '/support/bot_responses/filter';
    this.updateUrl = '/support/bot_responses/update_response';
    this.widgetHtml = "<div class='do-you-find-it-helpful'></div>";
    this.ticketHelptextHtml = "<strong>Does this article answer your query?</strong>";
    this.ticketContentHtml = "<p>If yes, we'll close your ticket.</p>";
    this.botTicketHtmlContent = "<div class='bot-image'></div><div class='bot-ticket-content'></div>";
    this.botArticleHtmlContent = "<div class='bot-article-content'></div>"
    this.buttonHtml = "<button class='btn btn-primary email-bot-helpful'>Yes, close ticket</button><button class='btn email-bot-helpful'>No</button>";
    this.articleHelpTextHtml = "<div class='help'><strong>Uh-oh. Maybe these articles can help you.</strong></div>";
    this.finalMessageUseful = "<div class='thanks-for-feedback'><div class='widget-vote up'></div><div><strong>We are glad this article was helpful in answering your query.</strong></div></div>";
    this.finalMessageNotUseful = "<div class='thanks-for-feedback'><div class='widget-vote down'></div><div><strong>We're sorry. Our team will reach out to you shortly.</strong></div></div>";
  }

  FreddyEmailBot.prototype = {
    showEmailBotHelpWidget : function() {
      var query_id = this.portal_url_vars.query_id;
      if (query_id) {
        var solution_id = this.portal.current_object_id;
        this.populateWidget(query_id, solution_id);
      }
    },
    getUrlVars : function() {
      var vars = [], hash;
      var hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split('&');
      for(var i = 0; i < hashes.length; i++) {
        hash = hashes[i].split('=');
        vars.push(hash[0]);
        vars[hash[0]] = hash[1];
      }
      this.portal_url_vars = vars;
    },
    getUrl : function(appendUrl){
      var pathname = window.location.pathname
      pathname = this.baseUrl + pathname.substr(0, pathname.indexOf('/support')) + appendUrl
      return window.origin + pathname
    },
    populateWidget : function() {
      var self = this;
      var params = {
        query_id: self.portal_url_vars.query_id,
        solution_id: self.portal.current_object_id
      };
      
      
      $.ajax({
        type: 'GET',
        url: self.getUrl(this.filterUrl),
        async: false,
        data: params,
        success: function(data){
          if( self.shouldNotConstructWidget(data) ) {
            return false;
          }
          self.constructWidget(self.portal.current_object_id, self.portal_url_vars.query_id, data.ticket_id);
          data.useful == self.usefulness.no_response ? 
            self.drawEmailBotTicketWidget(data.ticket_id) : 
            self.drawEmailBotArticleWidget(data.other_articles, self.portal_url_vars.query_id);
        }
      });
    },
    updateBotResponse : function(useful) {
      var self = this;
      var params = {
        useful: useful,
        query_id: self.portal_url_vars.query_id,
        solution_id: self.portal.current_object_id
      }
      $.ajax({
        type: 'PUT',
        url: self.getUrl(this.updateUrl),
        async: false,
        data: params,
        success: function(data) {
          (useful == self.usefulness.no && data.other_articles) ? 
            self.drawEmailBotArticleWidget(data.other_articles, self.portal_url_vars.query_id) : 
            self.closeBotHelpWidget(useful);
        }
      });
    },
    constructArticlesHref : function(other_articles, query_id) {
      var href = "";
      var self = this;
      other_articles.forEach(function(item) {
        var solution_url_with_query = item.url + "?query_id=" + query_id;
        href += "<li><a href='" + solution_url_with_query + "'><b>" + self.constructTitle(item.title) + "</b></a></li>";
      })
      return href;
    },
    shouldNotConstructWidget : function(data) {
      // do not construct widget if the ticket is closed or the all three articles are marked not-useful
      return data.ticket_closed || data.positive_feedback || (data.useful == this.usefulness.no && !data.other_articles) ? true : false;
    },
    fillHelpWidget : function(html) {
      $('.do-you-find-it-helpful').html(html);
    },
    botTicketContent : function() {
      $('.bot-ticket-content').html(this.ticketHelptextHtml + this.ticketContentHtml + this.buttonHtml);
    },
    drawEmailBotTicketWidget: function() {
      this.fillHelpWidget(this.botTicketHtmlContent);
      this.botTicketContent();
    },
    botArticleContent : function(other_articles, query_id) {
      var hrefs_html = this.constructArticlesHref(other_articles, query_id);
      $('.bot-article-content').html(this.articleHelpTextHtml + hrefs_html);
    },
    drawEmailBotArticleWidget : function(other_articles, query_id) {
      this.fillHelpWidget(this.botArticleHtmlContent);
      this.botArticleContent(other_articles, query_id);
    },
    constructTitle : function(title) {
      title = (title.length < 50) ? title : title.substr(0,50) + "...";
      return escapeHtml(title);
    },
    closeBotHelpWidget : function(useful) {
      useful ? $('.do-you-find-it-helpful').html(this.finalMessageUseful) : $('.do-you-find-it-helpful').html(this.finalMessageNotUseful);
    },
    constructWidget : function() {
      $(this.widgetHtml).appendTo("body");
    }
  }

  $(document).ready(function(){

    var freddyEmailBot = new FreddyEmailBot();

    freddyEmailBot.getUrlVars();

    if( freddyEmailBot.portal.current_tab == freddyEmailBot.requiredTab && freddyEmailBot.portal.falcon_portal_theme) {
      freddyEmailBot.showEmailBotHelpWidget();
    }

    $(document).on("click", ".email-bot-helpful", function(e){
      var useful = this.classList.contains("btn-primary");
      useful = (useful) ? freddyEmailBot.usefulness.yes : freddyEmailBot.usefulness.no;
      freddyEmailBot.updateBotResponse(useful);
    });
  });
})(jQuery);
