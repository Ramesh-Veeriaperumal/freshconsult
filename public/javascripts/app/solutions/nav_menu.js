/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Solutions = window.App.Solutions || {};
(function ($) {
  "use strict";

  App.Solutions.NavMenu = {
    activeFolder: null,
    categoriesLoaded: false,
    sidebarActive: false,
    
    start: function () {
      this.setupStaticSidebar();
      this.bindHandlers();
      this.setCurrentPage();
      this.sidebarActive = false;
      $('#cm-sb-solution-list').trigger('afterShow');
    },

    setupStaticSidebar: function () {
      var $this = this;
      $this.setSidebarHeight($("#body-container").height() - 20);

      $(document).on("sticky_kit:stick.solutions.sidebar", "#cm-solutions-wrapper", function (ev) {
        $this.setSidebarHeight($(window).height() - 20);
      });

      $(document).on("sticky_kit:unstick.solutions.sidebar", "#cm-solutions-wrapper", function (ev) {
        $this.setSidebarHeight($("#body-container").height() - 20);
      });
    },

    setSidebarHeight: function (height) {
      $("#community-solutions-sidebar").height(height);
      $("#cm-sb-solution-list").height(height - ($("#community-solutions-sidebar .cm-sb-title").outerHeight(true) + 10));
    },

    setCurrentPage: function () {
      var folder_id, category_id;
      $('#community-solutions-sidebar li').removeClass('active toggle-open');
      switch (App.namespace) {
      case 'solution/categories/index':
        $('#community-solutions-sidebar [data-page-name=home]').parent().addClass('active');
        break;
      case 'solution/categories/manage':
        $('#community-solutions-sidebar [data-page-name=manage]').parent().addClass('active');
        break;
      case 'solution/drafts/index':
        if (window.location.pathname === '/solution/drafts/all') {
          $('#community-solutions-sidebar [data-page-name=all_drafts]').parent().addClass('active');
        } else {
          $('#community-solutions-sidebar [data-page-name=my_drafts]').parent().addClass('active');
        }
        break;
      case 'solution/categories/show':
      case 'solution/categories/edit':
        category_id = parseInt(window.location.pathname.replace('/solution/categories/', ''), 10);
        $('#sb-solutions-category-' + category_id).parent().addClass('active toggle-open');
        break;
      case 'solution/folders/show':
      case 'solution/folders/edit':
        folder_id = parseInt(window.location.pathname.replace('/solution/folders/', ''), 10);
        $('#sb-solutions-folder-' + folder_id).parent().addClass('active toggle-open');
        break;
          
      default:
        if (this.activeFolder !== null) {
          $('#sb-solutions-folder-' + this.activeFolder).parent().addClass('active');
        }
        break;
      }
      
      $('#community-solutions-sidebar li.active').parents('.cm-sb-cat-item').addClass('toggle-open');
      if (!$('#community-solutions-sidebar .cm-sb-cat-item').hasClass('toggle-open')) {
        $('#community-solutions-sidebar .cm-sb-cat-item').first().addClass('toggle-open');
      }
      
    },

    setCurrentPageAs: function (page) {
      this.activeFolder = null;
      $('#community-solutions-sidebar li').removeClass('active');
      $('#community-solutions-sidebar [data-page-name=' + page + ']').parent().addClass('active');
    },

    setActiveFolderAs: function (folder_id) {
      this.activeFolder = parseInt(folder_id, 10);
      $('#community-solutions-sidebar li').removeClass('active');
      $('#community-solutions-sidebar [data-folder-id=' + folder_id + ']').parent().addClass('active');
    },

    bindHandlers: function () {
      this.bindToggleButton();
      this.bindOutsideClick();
      this.bindExpandLink();
      this.bindItemClick();
      this.bindSidebarClose();
      this.bindSidebarLoaded();
    },
    
    bindSidebarLoaded: function () {
      var $this = this;
      $('#cm-sb-solution-list').on('remoteLoaded', function () {
        $this.setCurrentPage();
        $this.categoriesLoaded = true;
      });
    },

    bindToggleButton: function () {
      var $this = this;
      $("body").on('click.solutions.sidebar', '#cm-sb-solutions-toggle', function () {
        $this.toggle();
      });
    },

    bindOutsideClick: function () {
      var $this = this;

      $(document).on('click.solutions.sidebar', function (ev) {
        var container = $('#community-solutions-sidebar'), sidebarToggle = $('#cm-sb-solutions-toggle');
        if (!container.is(ev.target) && container.has(ev.target).length === 0 && !sidebarToggle.is(ev.target)) {
          $this.hide();
        }
      });
    },

    bindExpandLink: function () {
      $(document).on('click.solutions.sidebar', '.forum_expand', function (ev) {
        ev.stopPropagation();
        $(this).parent().toggleClass("toggle-open");
      });
    },

    bindItemClick: function () {
      $(document).on('click.solutions.sidebar', '#community-solutions-sidebar a', function (ev) {
        $('#community-solutions-sidebar').find(".active").removeClass("active");
        $(this).parent().addClass('active');
      });
    },

    bindSidebarClose: function () {
      var $this = this;
      $(document).on('click.solutions.sidebar', '#cm-sb-solutions-close', function (ev) {
        $this.hide();
      });
    },
    
    show: function () {
      if (!this.categoriesLoaded) {
        $('#cm-sb-solution-list').trigger('afterShow');
      }
      $('body').addClass('cs-show');
      this.sidebarActive = true;
    },

    hide: function () {
      $('body').removeClass('cs-show');
			this.sidebarActive = false;
    },
    
    toggle: function () {
      if (this.sidebarActive) {
        this.hide();
      } else {
        this.show();
      }
    },
    
    reload: function () {
      $('#cm-sb-solution-list').trigger('reload');
    },

    leave: function (data) {
      this.activeFolder = null;
      this.hide();
      $(document).off('.solutions.sidebar');
      $(window).off('.solutions.sidebar');
      $('body').off('.solutions.sidebar');
    }
  };
}(window.jQuery));