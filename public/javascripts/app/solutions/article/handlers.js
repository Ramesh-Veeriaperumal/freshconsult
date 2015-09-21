/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = $.extend(App.Solutions.Article, {

    handleEdit: function () {
      if (window.location.hash === "#edit") {
        $(".article-edit-btn").trigger('click');
      }
    },
    
    resetData: function () {
      this.data.title = null;
      this.data.description = null;
    },

    editUrlChange: function (editingFlag) {
      window.location.hash = (editingFlag ? "#edit" : "");
    },
    
    setDataFromPage: function () {
      this.data = $('#article-form').data() || {};
      this.data.title = $('#current-article-title').text();
      this.data.description = $('#current-article-description').html();
    },
		
		toggleViews: function () {
			$('.article-edit, .article-view, .breadcrumb-btns, .edit-container').toggleClass('hide');
		},
    
    startEditing: function () {
      $('#sticky_redactor_toolbar').removeClass('hide');
      if ($('#solution-notification-bar .article-view-edit').is(':visible')) {
        $('#sticky_redactor_toolbar').addClass('has-notification');
      }
      $('#solution_article_title').focus();
      
      this.setFormValues();

      invokeRedactor('solution_article_description', 'solution');

      this.toggleViews();

      //initilaizing autosave
      if (this.autoSave) {
        this.autoSave.startSaving();
      } else {
        this.autosaveInitialize();
      }
      this.unsavedContentNotif();
      this.editUrlChange(true);
      this.attachmentsDelEvents();
      this.disableDraftResetAttr();
      
    },

    disableDraftResetAttr:  function () {
      //Disbale the input for cancel draft changes by default
      $('#cancel_draft_changes_input').prop('disabled', true);
    },
    
    setFormValues: function () {
      $('#solution_article_title').val(this.data.title);
      $('#solution_article_description').text(this.data.description);
    },

    cancel_UI_toggle: function () {
      this.toggleViews();
      $('#solution_article_description').destroyEditor();
      $('#sticky_redactor_toolbar').addClass('hide');
      $('.article-view-edit:hidden').show();
      $(".autosave-notif:visible").hide();
    },

    unsavedContent: function () {
      // Check if there is an error, in that case return false.
      if (this.autoSave && !this.autoSave.lastSaveStatus) {
        return false;
      }
      return this.checkAttachments();
    },

    checkAttachments: function () {
      var att_el = ["#article-attach-container", "#dropboxjs", "#boxjs", ".hidden_upload"];
      for(var i = 0; i < att_el.length ; i ++) {
        var el = $(att_el[i]+" input");
        if(el.length > 1) {
          return true;
        }
      }
      return false;
    }
  });
}(window.jQuery));