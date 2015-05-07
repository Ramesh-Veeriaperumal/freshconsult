/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = {

    onVisit: function (data) {
      if (App.namespace === "solution/articles/new") {
        this.eventsForNewPage();
      } else if (App.namespace === "solution/articles/show") {
        this.showPage();
        this.showPage2();
      } else if (App.namespace === "solution/articles/edit") {
        this.defaultFolderValidate();
      }
    },

    bindHandlers: function () {
    },
    
    showPage2: function() {
      var $this = this;
      $('.masterversion').height(parseInt(jQuery(document).height()));

      $('.masterversion-link').on('click', function(){
        $this.animateMasterver(35);
        $(this).addClass('disable');
      });

      $('.close-link').live('click', function(){
        $this.animateMasterver(470);
        $('.masterversion-link').removeClass('disable');
      });
      $(document).keyup(function(e){
        if(( e.keyCode == 27 ) && $('.masterversion-link').hasClass('disable') ){
          $('.close-link').trigger('click');
        }
      });

      var eTop = $('#editortool').offset().top;
      $(window).scroll(function(){
        if($(window).scrollTop() > 190 && $('#editortool').is(':visible')){
          $('#editortool').addClass('fixtoolbar');
        }else {
          $('#editortool').removeClass('fixtoolbar');
        }
      });

      $('.article-edit-btn').on('click', function(){
        $this.switchArticle('article-edit', 'article-view');
      });

      $('.edit-cancel').on('click', function(){
        $this.switchArticle('article-view', 'article-edit');
      });

      $('.article-view').dblclick(function() {
       $('.article-edit-btn').trigger('click');
      });
      
      $('#solution-article-edit').redactor({
        toolbarExternal: "#editortool",
        buttons:['formatting','bold','italic','underline','deleted','unorderedlist', 'orderedlist','fontcolor', 'backcolor','insert_table']
      });
    },
    animateMasterver: function(distance){
      if(jQuery('html').attr('dir') === 'rtl'){
        jQuery('.master-content').animate({
          right: distance
        });
      }else{
        jQuery('.master-content').animate({
          left: distance
        });
      }
    },
    
    switchArticle: function(show, hide){
      $('.'+hide).addClass('hide');
      $('.'+show).removeClass('hide');
    },

    onLeave: function (data) {
      $('body').off('.articles');
    },

    eventsForNewPage: function () {
      this.bindPropertiesToggle();
      this.formatSeoMeta();
      this.select2Tags();
    },
    
    bindPropertiesToggle: function () {
      $('body').on('click.articles', '#solution-properties-show', function (ev) {
        var visiblility = $('#solution-properties').is(":visible");
        $('#show-hide-button')
          .toggleClass("arrow-right", visiblility)
          .toggleClass("arrow-down", !visiblility);
        $('#solution-properties').toggle('fast', function () {});
      });
    },

    select2Tags: function () {
      $("#tags_name").select2({
        tags: $("#tags_name").data('tags').split(","),
        tokenSeparators: [',']
      });
    },

    formatSeoMeta: function () {
      $('body').on('click.articles', '#article-form', function (ev) {
        $('#solution_article_seo_data_meta_description').val(
          $('#solution_article_seo_data_meta_description').val().replace(/\n+/g, " ").trim()
        );
      });
    },

    cancelDraft: function () {
      var $this = this;
      $("#edit-cancel-button").bind('click', function () {
        $(".article-edit-form")[0].reset();
        $(".redactor_editor").html($("#solution_article_description").val());
        $this.articleDraftAutosave.contentChanged = false;
      });
    },

    autosaveInitialize: function (data) {
      var draft_options = {
        autosaveInterval: 5000,
        autosaveUrl: data.autosavePath,
        monitorChangesOf: {
          description: "#solution_article_description",
          title: "#solution_article_title"
        },
        extraParams: {timestamp: data.timestamp},
        responseCallback: this.autosaveDomManipulate
      };

      this.articleDraftAutosave  = $.autoSaveContent(draft_options);
      this.cancelDraft();
      this.unsavedContentNotif();
      this.attachmentAutosaveTrigger();
      return this.articleDraftAutosave;
    },

    attachmentAutosaveTrigger: function () {
      var $this = this;
      $(".hidden_upload").on('change.articles', function () {
        if ($this.articleDraftAutosave.successCount > 0) {
          $(".hidden_upload").unbind('change.articles');
        } else {
          $this.articleDraftAutosave.getContent();
        }
      });
    },

    autosaveDomManipulate: function (response) {

      var changeDom = {
        mainElement: $(".draft-info-box"),
        msgElement: $(".autosave-notif"),
        lastSuccess: false,
        liveTimeStamp: function () {
          var ts = Math.round((new Date()).getTime() / 1000);
          return $('<span />').attr('data-livestamp', ts)
                    .attr("title", moment().format('ddd, Do MMMM [at] h:mm A'))
                    .addClass('tooltip');
        },
        reloadButton: function () {
          return $('<span />').attr('onclick', 'window.location.reload();').
            html("Reload").attr('class', 'btn btn-small reload-btn');
        },
        message: function (msg, success) {
          return $('<span />').html(msg).attr('class', (success ? "" : "delete-confirm-warning-icon"));
        },
        htmlToStr: function (element) {
          return element.wrap('<div/>').parent().html();
        },
        themeChange: function (isError) {
          this.mainElement
            .toggleClass('error', isError)
            .toggleClass('success', isError)
            .show();
        },
        lastUpdatedAt: function (response) {
          if(response.timestamp){
            $("#last-updated-at").val(response.timestamp);
          }
        },
        toggleButtons: function (flag) {
          var $flag = flag;
          $.each(['#edit-cancel-button', '#save-as-draft-btn', '.btn-primary'], function(index, el){
            $(el).prop('disabled', !$flag);
          });
          $('.confirm-delete').attr('disabled', !$flag);
        },
        manipulate: function (response, success) {
          var content = "";
          if (response.msg) {
            content = this.htmlToStr(this.message(response.msg, success));
            content += this.htmlToStr(success ? this.liveTimeStamp() : this.reloadButton()) ;

            this.msgElement.html(content).show();
            this.themeChange(!success);
            this.lastUpdatedAt(response);
            this.toggleButtons(success);
          }
        }

      };

      if (typeof (response) === 'object') {
        if (response.success) {
          changeDom.manipulate(response, true);
        } else {
          autoSaveArticleDraft.lastSaveStatus = false;
          changeDom.manipulate(response, false);
        }
      } else {
         autoSaveArticleDraft.lastSaveStatus = false;
        changeDom.manipulate({ msg: "Something is wrong."}, false);
      }
    },

    showPage: function () {
      if ($("#folder-section").height() > $("#article-section").height()) {
        $("#article-section").css("minHeight", $("#folder-section").height());
      }
      highlight_code();
    },

    articleProperties: function () {
      var $this = this;
      setTimeout(function () {
        $this.formatSeoMeta();
        $this.select2Tags();
        $("#article-properties-cancel").bind("click", function () {
          $('#article-properties-content #article-form').resetForm();
          $('#article-properties-content #article-form .select2').trigger('change');
        });
      }, 50);
    },

    unsavedContent: function () {
      // Check if there is an error, in that case return false.
      if(!this.articleDraftAutosave.lastSaveStatus){
        return false;
      }
      // return (this.articleDraftAutosave.contentChanged || ($(".hidden_upload input").length > 1));
      return ($(".hidden_upload input").length > 1);
    },

    unsavedContentNotif: function () {
      var $this = this;

      $(window).on('beforeunload.articles', function (e) {
        if ($this.unsavedContent()) {
          var msg = "You have unsaved content in this page.";
          e = e || window.event;
          if (e) {
            e.returnValue = msg;
          }
          return msg;
        }
      });

      $('body').on('submit.articles', '.article-edit-form', function () {
        $(window).off('beforeunload.articles');
      });

      $(document).on('pjax:beforeSend', function (event, xhr, settings, options) {
        if ($this.unsavedContent()) {
          if (!confirm('You have unsaved content in this page. Do you want to leave this page?')) {
            Fjax.resetLoading();
            return false;
          }
        }
      });
    },

    defaultFolderValidate: function () {
      $('body').on('click.articles', '#article-publish-btn', function() {
        if ( $("#article-form").data().defaultFolder ) {
          if ( $('#solution_article_folder_id').val() == "" ) {
            $('.select-folder').show();
            return false;
          }
        }
        return true;
      });
    }

  };
}(window.jQuery));