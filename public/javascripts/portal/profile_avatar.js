// PROFILE AVATARS 
(function($){
  "use strict";
  
  window.AvatarReader = function(options) {
    var defaults = {
      confirmDeleteMessage : 'Are you sure you want to delete this picture?',
      ie9FileChangeMessage : 'You have selected %{filename}. Click save to see the changes.',
      // Path of the default avatar pic
      defaultPath: portal['image_placeholders']['profile_medium'],
      // Array of supported image formats
      supportedImageFormats : ['image/jpeg', 'image/png'],
      // Selector that wraps the avatar options change & delete
      avatarContainer: '.avatar-span',
      // Selector of the form
      formContainer: 'form.form-unsaved-changes-trigger',
      // Selectors of the innerfields
      fields: {
        // Img Tag to show the pic
        avatarPic : '.avatar-pic img',
        // Input File Tag
        avatarFile : '.avatar-file',
        // Remove Pic link
        avatarRemove : '.remove-avatar',
        // destroy param to indicate whether the avatar is removed
        avatarDestroy : '.avatar-destroy',
        avatarText : '.avatar-text',
        ie9FileChangeElmt: '.ie9-file-change-msg',
        avatarDropdown : '.dropdown',
        // Default button without dropdown
        defaultBtn : '.default-pic'
      }
    };
    this.options = $.extend({}, defaults, options);
  };

  AvatarReader.prototype = {
    onFileChange : function(e, element) {
      var fileField = e.currentTarget,
          fileName = element.val(),
          isIE9 = $('html').hasClass('ie9'),
          extension = '';
      if( (isIE9 && fileName != "" ) || 
            (fileField.files && fileField.files[0] && this.checkSupportedImageFormats(fileField.files[0].type)) ){
            if(isIE9) {
              fileName = fileName.replace(/^.*\\/, "");
              extension = fileName.match(/\.[0-9a-z]{1,5}$/i);
              fileName = (fileName.length > 25) ? fileName.substring(0,25) + '...' + extension : fileName;
              fileName = this.options.ie9FileChangeMessage.replace('%{filename}', '<b>' + fileName + '</b>');
              this.setDefaultPic();
              (this.options.fields.ie9FileChangeElmt).html(fileName).show();
            }
            else {
              this.readLocalFile(fileField.files[0]);
            }
            this.updateDestroyValue("0");
            this.toggleElement(this.options.fields.avatarDropdown, 'removeClass');
            this.toggleElement(this.options.fields.defaultBtn, 'addClass');
      }
      else {
        this.setDefaultPic();
        this.toggleElement(this.options.fields.avatarDropdown, 'addClass');
      }
    },
    readLocalFile : function(file) {
      var fileReader = new FileReader(),
          self = this;
      fileReader.readAsDataURL(file);
      fileReader.onload = function(evt) {
        self.localFileOnLoad(evt);
      }
    },
    localFileOnLoad : function(e) {
      (this.options.fields.avatarPic).attr('src', e.target.result);
    },
    checkSupportedImageFormats : function(fileType) {
      return ($.inArray(fileType, this.options.supportedImageFormats) !== -1)
    },
    toggleElement : function(element, option) {
      element[option]('hide');
    },
    updateDestroyValue : function(value) {
      if((this.options.fields.avatarDestroy).val() != -1) {
        (this.options.fields.avatarDestroy).val(value);
        this.updateFormChanges(true);
      }
    },
    updateFormChanges : function(option) {
      (this.options.formContainer).data('formChanged', option);
    },
    setDefaultPic : function() {
      (this.options.fields.avatarPic).attr('src', this.options.defaultPath);
    },
    resetPicField : function() {
      $.each(this.options.fields.avatarFile, function(idx, item) {
        $(item).replaceWith( $(item).clone( true ) );
      });
      (this.options.fields.ie9FileChangeElmt).html('').hide();
    },
    removePic : function() {
      var confDelete = confirm(this.options.confirmDeleteMessage);
      if(confDelete) {
        this.resetPicField();
        this.updateDestroyValue("1");
        this.setDefaultPic();
        this.toggleElement(this.options.fields.avatarDropdown, 'addClass');
        this.toggleElement(this.options.fields.defaultBtn, 'removeClass');
      }
    },
    init : function() {
      var self = this;
      for(var prop in this.options.fields) {
        if(prop == 'avatarPic' || prop == 'ie9FileChangeElmt') {
          this.options.fields[prop] = $(this.options.fields[prop]);
        }
        else {
          this.options.fields[prop] = $(this.options.avatarContainer).find(this.options.fields[prop]);
        }
      }
      this.options.formContainer = $(this.options.avatarContainer).parents(this.options.formContainer);
      $(document).on('change.avatar-reader', (this.options.fields.avatarFile).selector, function(e) {
        self.onFileChange(e, $(this));
      });
      $(document).on('click.avatar-reader', (this.options.fields.avatarRemove).selector, function(e) {
        e.preventDefault();
        self.removePic();
      });
    },
    destroy : function() {
      $(document).off('click.avatar-reader');
      $(document).off('change.avatar-reader');
    }
  };
})(window.jQuery);