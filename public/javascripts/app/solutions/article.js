/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = {
    
    data: {},

    onVisit: function (data) {
      // Check if this is New Version.
//      if (App.namespace === "solution/articles/new") {
//        this.eventsForNewPage();
//      } else if (App.namespace === "solution/articles/show") {
//        // this.showPage();
//        // this.showPage2();
//      } else if (App.namespace === "solution/articles/edit") {
//        this.defaultFolderValidate();
//      }
			
      this.resetData();
      this.setDataFromPage();
      this.bindHandlers();
      highlight_code();
    },
    
    onLeave: function (data) {
      $('body').off('.articles');
    },
    
    resetData: function () {
      this.data.title = null;
      this.data.description = null;
    },
    
    setDataFromPage: function () {
      this.data = $('#article-form').data() || {};
      this.data.title = $('#current-article-title').text();
      this.data.description = $('#current-article-description').html();
    },

    bindHandlers: function () {
      var $this = this;
      this.bindForMasterVersion();
      $('body').on('click.articles', '.article-edit-btn', function () {
        $this.startEditing();
      });
    },
		
		scrollHandler: function () {
			$(window).on('scroll.articles', function () {
        if ($(window).scrollTop() > 190 && $('#editortool').is(':visible')) {
          $('#editortool').addClass('fixtoolbar');
        } else {
          $('#editortool').removeClass('fixtoolbar');
        }
      });
		},
		
		toggleViews: function () {
			$('.article-edit, .article-view').toggleClass('hide');
		},
    
    startEditing: function () {
      $('.sub-content.article-edit').html($('.sub-content.article-view').html());
      this.setFormValues();
      this.autosaveInitialize();
      var eTop = $('#editortool').offset().top;
			this.toggleViews();
      this.scrollHandler();
    },
    
    setFormValues: function () {
      $('#solution_article_title').val(this.data.title);
      $('#solution_article_description').setCode(this.data.description);
    },
    
    bindForMasterVersion: function () {
      var $this = this;
      $(window).on('resize.articles', function () {
        $('.masterversion').height(parseInt($(document).height(), 10));
      }).trigger('resize.article');

      $('body').on('click.articles', '.masterversion-link', function () {
        $this.animateMasterver(35);
        $(this).addClass('disable');
      });

      $('body').on('click.articles', '.close-link', function () {
        $this.animateMasterver(470);
        $('.masterversion-link').removeClass('disable');
      });
      // $(document).on('keyup.article',function(e){
      //   if(( e.keyCode == 27 ) && $('.masterversion-link').hasClass('disable') ){
      //     $('.close-link').trigger('click');
      //   }
      // });

    },
    animateMasterver: function (distance) {
      if ($('html').attr('dir') === 'rtl') {
        $('.master-content').animate({
          right: distance
        });
      } else {
        $('.master-content').animate({
          left: distance
        });
      }
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

    bindForCancel: function () {
      var $this = this;
      $("body").on('click.article', "#edit-cancel-button", function (ev) {
        ev.preventDefault();
				$this.articleDraftAutosave.stopSaving();
        $(".article-edit-form")[0].reset();
        $this.setFormValues();
				if ($this.hadDraft()) {
					$this.resetDraftRequest();
				} else {
					$this.discardDraftRequest();
				}
        $this.articleDraftAutosave.contentChanged = false;
				$(window).off('scroll.articles');
				$this.toggleViews();
      });
    },
    
    discardDraftRequest: function () {
      $.ajax({
        type: 'DELETE',
				url: this.data.discardDraftPath
      });
    },
		
		hadDraft: function () {
			return (this.data.timestamp && this.data.timestamp > 0);
		},
    
    resetDraftRequest: function () {
      
      // setFormValues
      // clearAttachments
      
      // No Previous Author => No Draft already
      
			//TODO-DraftUI If there was NO draft already, delete the autosaved record
      $.ajax({
        type: 'POST',
        data: $('#article-form').serialize()
      });
    },

    autosaveInitialize: function (data) {
      data = data || $('#article-form').data();
      var draft_options = {
        autosaveInterval: 5000,
        autosaveUrl: data.autosavePath,
        monitorChangesOf: {
          description: "#solution_article_description",
          title: "#solution_article_title"
        },
        extraParams: {timestamp: data.timestamp},
        responseCallback: $.proxy(this.autosaveDomManipulate, this)
      };

      this.articleDraftAutosave  = $.autoSaveContent(draft_options);
      this.bindForCancel();
      // Move these somewhere else
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
          if (response.timestamp) {
            $("#last-updated-at").val(response.timestamp);
          }
        },
        toggleButtons: function (flag) {
          var $flag = flag;
          $.each(['#edit-cancel-button', '#save-as-draft-btn', '.btn-primary'], function (index, el) {
            $(el).prop('disabled', !$flag);
          });
          $('.confirm-delete').attr('disabled', !$flag);
        },
        manipulate: function (response, success) {
          var content = "";
          response = response || { msg: "Something went wrong!"};
          if (response.msg) {
            content = this.htmlToStr(this.message(response.msg, success));
            content += this.htmlToStr(success ? this.liveTimeStamp() : this.reloadButton());

            this.msgElement.html(content).show();
            this.themeChange(!success);
            this.lastUpdatedAt(response);
            this.toggleButtons(success);
          }
        }

      };

      if (typeof (response) === 'object' && response.success) {
        changeDom.manipulate(response, true);
      } else {
        this.articleDraftAutosave.lastSaveStatus = false;
        changeDom.manipulate(response, false);
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
      if (!this.articleDraftAutosave.lastSaveStatus) {
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
      $('body').on('click.articles', '#article-publish-btn', function () {
        if ($("#article-form").data().defaultFolder) {
          if ($('#solution_article_folder_id').val() === "") {
            $('.select-folder').show();
            return false;
          }
        }
        return true;
      });
    }

  };
}(window.jQuery));