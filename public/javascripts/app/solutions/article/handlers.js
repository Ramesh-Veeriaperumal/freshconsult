/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax, invokeRedactor, invokeEditor */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = $.extend(App.Solutions.Article, {

    handleEdit: function () {
      if (window.location.hash === "#edit") {
        $(".article-edit-btn").trigger('click');
        $('.breadcrumb').addClass('breadcrumb-edit');
      }
    },
    
    resetData: function () {
      this.data.title = null;
      this.data.description = null;
    },

    highlightCode: function () {
      if (window.location.hash !== "#edit") {
        highlight_code();
      }
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
			$('.article-edit, .article-view, .breadcrumb-btns, .edit-container, #show_master_article').toggleClass('hide');
		},

    setToolBarPosition: function() {
      if($('.article-edit').is(':visible')) {
        var offset = jQuery('.article-edit-form .editor-body').position().top;

        if($('#sticky_redactor_toolbar .fr-toolbar').is(':visible')){
          $('#sticky_redactor_toolbar .fr-toolbar').css("top", offset);
        }else{
          $('#sticky_redactor_toolbar .redactor_toolbar').css("top", offset);
        }
      }
    },
    
    startEditing: function () {
      $('#sticky_redactor_toolbar').removeClass('hide');
      if ($('#solution-notification-bar .article-view-edit').is(':visible')) {
        $('.sticky_editor_toolbar').addClass('has-notification');
      }
      $('#solution_article_title').focus();
      
      this.setFormValues();

      if($('#solution_article_description').data('newEditor')) {
        invokeEditor('solution_article_description', 'solution');
      } else {
        invokeRedactor('solution_article_description', 'solution');
      }


      this.toggleViews();
      this.setToolBarPosition();

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
      var html = this.data.description;
      $('#solution_article_title').val(this.data.title);
      $('#solution_article_description').text(html.replace(/<p>\s*?<\/p>/g,'').replace(/<div>\s*?<\/div>/g,''));
    },

    cancel_UI_toggle: function () {
      this.toggleViews();

      if($('#solution_article_description').data('newEditor')) {
        $('#solution_article_description').froalaEditor('destroy');
      } else {
        jQuery('#solution_article_description').destroyEditor()
      }
      
      $('#sticky_redactor_toolbar').addClass('hide');
      $('.article-view-edit:hidden').show();
      $(".autosave-notif:visible").hide();
    },

    unsavedContent: function () {
      // Check if there is an error, in that case return false.
      if (this.autoSave && !this.autoSave.lastSaveStatus) {
        return false;
      }
      if (App.namespace === "solution/articles/new" || App.namespace === "solution/articles/create") {
        
        var isEmpty, element = $("#solution_article_description");
        if (element.data('redactor')) {
          isEmpty = element.data('redactor').isNotEmpty();
        } else if(element.data('froala.editor')){
          isEmpty = !element.data('froala.editor').core.isEmpty();
        }

        var flag =  isEmpty || $('#solution_article_title').val().length > 0;
        if (flag) {
          return true;
        }
      }
      return this.checkAttachments();
    },

    checkAttachments: function () {
      var att_el = ["#article-attach-container", "#dropboxjs", "#boxjs", ".hidden_upload"], i, el;
      for (i = 0; i < att_el.length; i += 1) {
        el = $(att_el[i] + " input");
        if (el.length > 1) {
          return true;
        }
      }
      return false;
    }
  });
}(window.jQuery));