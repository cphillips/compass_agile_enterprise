Compass.ErpApp.Utility.createNamespace("Knitkit");

Knitkit.InlineEditing = {
    contentDiv: null,
    websiteId: null,
    contentId: null,

    closeEditor: function (editor) {
        editor.destroy();
        jQuery('#editableContentContainer').remove();
        jQuery('#editableContentOverlay').remove();
    },

    saved: function (editor, result, status, xhr) {
        jQuery('#editableContentOverlay').css('z-index', '1001');

        if (result.success === true) {
            this.closeEditor(editor);
        }
        else {
            jQuery('#inlineEditSaveResult').html(" Could not update.  Please try again.");
        }
    },

    error: function (xhr, status, error) {
        jQuery('#inlineEditSaveResult').html(" Could not update.  Please try again.");
    },

    closeEditorClick: function () {
        //make sure modal is not already showing
        if (jQuery("#warning-modal").length === 0) {
            var editor = CKEDITOR.instances['inlineEditTextarea'];
            if (editor.checkDirty()) {
                jQuery('#editableContentOverlay').css('z-index', '1003');

                var warningModal = jQuery('<div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true"></div>'),
                    modalDialog = jQuery('<div class="modal-dialog"></div>'),
                    modalContent = jQuery('<div class="modal-content"></div>'),
                    modalHeader = jQuery('<div class="modal-header"><h4 class="modal-title" id="myModalLabel">Please Confirm</h4></div>'),
                    modalBody = jQuery('<div class="modal-body">You have unsaved changes. Are you sure you want to exit?</div>'),
                    footer = jQuery('<div class="modal-footer"></div>'),
                    yesBtn = jQuery('<button type="button" class="btn btn-default" data-dismiss="modal">Yes</button>'),
                    noBtn = jQuery('<button type="button" class="btn btn-primary" data-dismiss="modal">No</button>');

                footer.append(yesBtn);
                footer.append(noBtn);
                modalContent.append(modalHeader);
                modalContent.append(modalBody);
                modalContent.append(footer);
                modalDialog.append(modalContent);
                warningModal.append(modalDialog);

                noBtn.bind('click', function () {
                    warningModal.modal('hide');
                    warningModal.remove();
                    jQuery('#editableContentOverlay').css('z-index', '1001');
                });

                yesBtn.bind('click', function () {
                    Knitkit.InlineEditing.closeEditor(editor);
                    warningModal.modal('hide');
                    warningModal.remove();
                });

                jQuery("body").append(warningModal);

                warningModal.modal({backdrop:false});
            }
            else {
                Knitkit.InlineEditing.closeEditor(editor);
            }
        }
        return false;
    },

    setup: function (websiteId) {
        var content = jQuery('div.knitkit_content'),
            body = jQuery("body");

        this.websiteId = websiteId;

        content.bind('mouseenter', function () {
            var div = jQuery(this);
            div.addClass('knitkit-inlineedit-editable');
        });

        content.bind('mouseleave', function () {
            var div = jQuery(this);
            div.removeClass('knitkit-inlineedit-editable');
        });

        content.bind('click', function () {
            var self = Knitkit.InlineEditing;
            var div = jQuery(this);
            self.contentId = div.attr('contentid');
            self.lastUpdate = div.attr('lastupdate');
            var data = div.html();

            var textarea = jQuery('<textarea name="inline-edit-textarea" id="inlineEditTextarea" ></textarea>');
            var closeLink = jQuery("<a class='inline-edit-close'><img src='images/knitkit/close_window.png' /></a>");
            var messageSpan = jQuery("<span class='inline-edit-message' id='inlineEditMessage'>Last Update: <span id='inlineEditLastUpdate'>" + self.lastUpdate + "</span><span id='inlineEditSaveResult'></span></span>");

            var editableContentContainer = jQuery("<div id='editableContentContainer' style='font-size:12px;' class='modal-container'></div>");
            var ckeditorWrapper = jQuery("<div class='ckeditor_wrapper'></div>");
            var actionResultDiv = jQuery("<div class='editable-content-actionresult'></div>");

            editableContentContainer.append(ckeditorWrapper);
            ckeditorWrapper.append(textarea);
            editableContentContainer.append(actionResultDiv);
            actionResultDiv.append(closeLink);
            actionResultDiv.append(messageSpan);

            var overlay = jQuery("<div id='editableContentOverlay' class='modal-overlay'></div>");

            body.append(editableContentContainer);
            body.append(overlay);

            closeLink.bind('click', self.closeEditorClick);

            CKEDITOR.replace('inline-edit-textarea',
                {
                    height: 320,
                    enterMode: CKEDITOR.ENTER_BR,
                    extraPlugins: 'inlineeditsave,jwplayer,codemirror',
                    toolbar: [
                        { name: 'document', items: [ 'Source', '-', 'InlineEditSave', 'NewPage', 'DocProps', 'Preview', 'Print', '-', 'Templates' ] },
                        { name: 'clipboard', items: [ 'Cut', 'Copy', 'Paste', 'PasteText', 'PasteFromWord', '-', 'Undo', 'Redo' ] },
                        { name: 'editing', items: [ 'Find', 'Replace', '-', 'SelectAll', '-', 'SpellChecker', 'Scayt' ] },
                        { name: 'forms', items: [ 'Form', 'Checkbox', 'Radio', 'TextField', 'Textarea', 'Select', 'Button', 'ImageButton',
                            'HiddenField' ] },
                        '/',
                        { name: 'basicstyles', items: [ 'Bold', 'Italic', 'Underline', 'Strike', 'Subscript', 'Superscript', '-', 'RemoveFormat' ] },
                        { name: 'paragraph', items: [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent', '-', 'Blockquote', 'CreateDiv',
                            '-', 'JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock', '-', 'BidiLtr', 'BidiRtl' ] },
                        { name: 'links', items: [ 'Link', 'Unlink', 'Anchor' ] },
                        { name: 'insert', items: [ 'Image', 'Flash', 'jwplayer', 'Table', 'HorizontalRule', 'Smiley', 'SpecialChar', 'PageBreak', 'Iframe' ] },
                        '/',
                        { name: 'styles', items: [ 'Styles', 'Format', 'Font', 'FontSize' ] },
                        { name: 'colors', items: [ 'TextColor', 'BGColor' ] },
                        { name: 'tools', items: [ 'Maximize', 'ShowBlocks', '-', 'About' ] }
                    ],
                    on: {
                        instanceReady: function (ev) {
                            Knitkit.InlineEditing.contentDiv = div;
                            this.setData(data);
                            this.focus();
                        },
                        dataReady: function (ev) {
                            this.resetDirty();
                        }
                    }

                });

        });
    }
};
