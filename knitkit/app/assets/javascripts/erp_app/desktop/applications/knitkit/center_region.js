Ext.define("Compass.ErpApp.Desktop.Applications.Knitkit.CenterRegion", {
    extend: "Ext.panel.Panel",
    id: 'knitkitCenterRegion',
    alias: 'widget.knitkit_centerregion',
    ckEditorExtraPlugins: 'codemirror,syntaxhighlight',
    ckEditorToolbar: [
        ['Source', '-', 'Preview', 'Print'],
        ['Cut', 'Copy', 'Paste', 'PasteText', 'PasteFromWord'],
        ['Undo', 'Redo'],
        ['Find', 'Replace'],
        ['SpellChecker', '-', 'SelectAll'],
        ['TextColor', 'BGColor'],
        ['Bold', 'Italic', 'Underline', 'Strike'],
        ['Subscript', 'Superscript', '-'],
        ['Image', 'Table', 'NumberedList', 'BulletedList'],
        ['Outdent', 'Indent', 'Blockquote'],
        ['JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock'],
        ['BidiLtr', 'BidiRtl'],
        ['Link', 'Unlink', 'Anchor'],
        ['HorizontalRule', 'SpecialChar', 'PageBreak'],
        ['ShowBlocks', 'RemoveFormat'],
        ['Format', 'Font', 'FontSize'],
        ['Maximize', '-', 'About'],
        ['Syntaxhighlight']
    ],

    setWindowStatus: function (status) {
        this.findParentByType('statuswindow').setStatus(status);
    },

    clearWindowStatus: function () {
        this.findParentByType('statuswindow').clearStatus();
    },

    viewSectionLayout: function (title, template) {
        this.workArea.add({
            title: title + ' - Layout',
            disableToolbar: true,
            xtype: 'codemirror',
            mode: 'rhtml',
            sourceCode: template,
            closable: true
        });
        this.workArea.setActiveTab(this.workArea.items.length - 1);
        return false;
    },

    /* sections */

    saveSectionLayout: function (id, codeMirrorComp, content) {
        var self = this;
        this.setWindowStatus('Saving...');
        Ext.Ajax.request({
            url: '/knitkit/erp_app/desktop/section/save_layout',
            method: 'POST',
            params: {
                id: id,
                content: content
            },
            success: function (response) {
                self.clearWindowStatus();
                var obj = Ext.decode(response.responseText);
                if (obj.success) {
                    var activeTab = self.workArea.getActiveTab();
                    var versionsGrid = activeTab.down('knitkit_versionswebsitesectiongridpanel');
                    if (!Ext.isEmpty(versionsGrid)) {
                        versionsGrid.store.load();
                    }
                }
                else {
                    Ext.Msg.alert('Error', obj.message);
                }

                codeMirrorComp.focus();
            },
            failure: function (response) {
                self.clearWindowStatus();
                Ext.Msg.alert('Error', 'Error saving layout');
            }
        });
    },

    editSectionLayout: function (sectionName, websiteId, websiteSectionId, content, tbarItems) {
        var self = this;
        var itemId = 'section-' + websiteSectionId;
        var item = this.workArea.query('#' + itemId).first();

        if (Compass.ErpApp.Utility.isBlank(item)) {
            item = Ext.create("Ext.panel.Panel", {
                layout: 'border',
                title: sectionName,
                save: function (comp) {
                    var codeMirrorComp = comp.down('codemirror');
                    var content = codeMirrorComp.getValue();
                    self.saveSectionLayout(websiteSectionId, codeMirrorComp, content);
                },
                closable: true,
                itemId: itemId,
                items: [
                    {
                        title: sectionName + ' - Layout',
                        tbarItems: tbarItems,
                        disableSave: true,
                        listeners: {
                            save: function (codeMirrorComp, content) {
                                self.saveSectionLayout(websiteSectionId, codeMirrorComp, content);
                            }
                        },
                        xtype: 'codemirror',
                        mode: 'rhtml',
                        region: 'center',
                        sourceCode: content
                    },
                    {
                        xtype: 'knitkit_versionswebsitesectiongridpanel',
                        websiteSectionId: websiteSectionId,
                        region: 'south',
                        height: 150,
                        collapsible: true,
                        centerRegion: self,
                        siteId: websiteId
                    }
                ]
            });

            this.workArea.add(item);
        }

        this.workArea.setActiveTab(item);
        return false;
    },

    /* documentation using markdown */

    saveDocumentationMarkdown: function (id, comp, content, siteId) {
        var self = this;
        this.setWindowStatus('Saving...');
        Ext.Ajax.request({
            url: '/knitkit/erp_app/desktop/content/update',
            method: 'POST',
            params: {
                id: id,
                html: content,
                site_id: siteId
            },
            success: function (response) {
                var obj = Ext.decode(response.responseText);
                if (obj.success) {
                    self.clearWindowStatus();
                    var activeTab = self.workArea.getActiveTab();
                    var versionsGrid = activeTab.down('knitkit_versionsarticlegridpanel');
                    versionsGrid.getStore().load();
                }
                else {
                    Ext.Msg.alert('Error', 'Error saving contents');
                    self.clearWindowStatus();
                }
                comp.ckEditorInstance.focus();
            },
            failure: function (response) {
                self.clearWindowStatus();
                Ext.Msg.alert('Error', 'Error saving contents');
            }
        });
    },

    editDocumentationMarkdown: function (sectionName, websiteId, contentId, content, tbarItems) {
        var self = this;
        var itemId = 'markdown-' + contentId;
        var item = this.workArea.query('#' + itemId).first();

        if (Compass.ErpApp.Utility.isBlank(item)) {
            item = Ext.create("Ext.panel.Panel", {
                layout: 'border',
                title: sectionName,
                save: function (comp) {
                    var content = comp.down('codemirror').getValue();
                    self.saveDocumentationMarkdown(contentId, comp, content, websiteId);
                },
                closable: true,
                itemId: itemId,
                items: [
                    {
                        title: sectionName + ' - Markdown',
                        tbarItems: tbarItems,
                        disableSave: true,
                        listeners: {
                            save: function (comp, content) {
                                self.saveDocumentationMarkdown(contentId, comp, content, websiteId);
                            }
                        },
                        xtype: 'codemirror',
                        mode: 'rhtml',
                        region: 'center',
                        sourceCode: content
                    },
                    {
                        xtype: 'knitkit_versionsarticlegridpanel',
                        contentId: contentId,
                        region: 'south',
                        height: 150,
                        collapsible: true,
                        centerRegion: self,
                        siteId: websiteId
                    }
                ]
            });

            this.workArea.add(item);
        }

        this.workArea.setActiveTab(item);
        return false;
    },

    /* templates */

    saveTemplateFile: function (path, comp, content) {
        var self = this;
        this.setWindowStatus('Saving...');
        Ext.Ajax.request({
            url: '/knitkit/erp_app/desktop/theme/update_file',
            method: 'POST',
            params: {
                node: path,
                content: content
            },
            success: function (response) {
                var obj = Ext.decode(response.responseText);
                self.clearWindowStatus();
                if (!obj.success) {
                    Ext.Msg.alert('Error', obj.message);
                }

                comp.focus();
            },
            failure: function (response) {
                self.clearWindowStatus();
                Ext.Msg.alert('Error', 'Error saving contents');
            }
        });
    },

    editTemplateFile: function (node, content, tbarItems, themeId) {
        var self = this,
            pathArr = node.data.id.split('/'),
            containerDir = pathArr[pathArr.length - 2],
            fileName = pathArr.pop(),
            baseName = fileName.split('.')[0],
            fileType = node.data.id.split('.').pop(),
            filePathHash = Compass.ErpApp.Utility.Encryption.MD5(node.data.id),
            templatePath = node.data.id.replace(new RegExp("/public/sites/.+/themes/"), ""),

            itemId = baseName + "_" + filePathHash, // Using a hash will allow files with same name to be opened concurrently
            item = this.workArea.query('#' + itemId).first();

        mode = Compass.ErpApp.Shared.CodeMirror.determineCodeMirrorMode(node.data.id);

        // If this file isn't already an existing tab, let's open it
        if (Compass.ErpApp.Utility.isBlank(item)) {
            item = Ext.create('Ext.panel.Panel', {
                closable: true,
                title: baseName,
                baseName: baseName,
                fileName: fileName,
                containerDir: containerDir,
                filePathHash: filePathHash,
                itemId: itemId,
                layout: 'fit',
                save: function (comp) {
                    var codeMirrorComp = comp.down('codemirror');
                    var content = codeMirrorComp.getValue();
                    self.saveTemplateFile(node.data.id, codeMirrorComp, content);
                },
                items: [
                    {
                        tbarItems: tbarItems,
                        disableSave: true,
                        xtype: 'codemirror',
                        listeners: {
                            save: function (codeMirrorComp, content) {
                                self.saveTemplateFile(node.data.id, codeMirrorComp, content);
                            }
                        },
                        mode: mode,
                        sourceCode: content
                    }
                ],
                bbar: {
                    items: [
                        templatePath
                    ]
                }
            });

            this.workArea.add(item);
        }

        this.workArea.setActiveTab(item);
        return false;
    },

    /* excerpts */

    saveExcerpt: function (id, comp, content, siteId) {
        var self = this;
        this.setWindowStatus('Saving...');
        Ext.Ajax.request({
            url: '/knitkit/erp_app/desktop/content/save_excerpt',
            method: 'POST',
            params: {
                id: id,
                html: content,
                site_id: siteId
            },
            success: function (response) {
                var obj = Ext.decode(response.responseText);
                if (obj.success) {
                    self.clearWindowStatus();
                    var activeTab = self.workArea.getActiveTab();
                    var panel = activeTab.query('knitkit_versionsbloggridpanel');
                    if (panel.length === 0) {
                        panel = activeTab.query('knitkit_nonpublishedversionswebsitesectiongridpanel');
                    }
                    panel[0].getStore().load();
                    comp.ckEditorInstance.focus();
                }
                else {
                    Ext.Msg.alert('Error', 'Error saving excerpt');
                    self.clearWindowStatus();
                }
            },
            failure: function (response) {
                self.clearWindowStatus();
                Ext.Msg.alert('Error', 'Error saving excerpt');
            }
        });
    },

    editExcerpt: function (title, id, content, siteId, contentGridStore) {
        var self = this;
        var itemId = 'editExcerpt-' + id;
        var item = this.workArea.query('#' + itemId).first();

        if (Compass.ErpApp.Utility.isBlank(item)) {
            var ckEditor = Ext.create("Compass.ErpApp.Shared.CKeditor", {
                autoHeight: true,
                ckEditorConfig: {
                    extraPlugins: self.ckEditorExtraPlugins,
                    toolbar: self.ckEditorToolbar
                },
                listeners: {
                    save: function (comp, content) {
                        self.saveExcerpt(id, comp, content, siteId);
                        if (!Ext.isEmpty(contentGridStore)) contentGridStore.load();
                    },
                    ckeditordrop: function (ckeditorPanel, dropEvent) {
                        var dataTransfer = dropEvent.dataTransfer;
                        var files = dataTransfer.files;
                        for (var i = 0; i < files.length; i++) {
                            var loadMask = new Ext.LoadMask(ckeditorPanel, {msg: "Please wait..."});
                            loadMask.show();

                            var file = files[i];
                            var reader = new FileReader();

                            Compass.ErpApp.Utility.addEventHandler(reader, 'loadend', function (e, file) {
                                var bin = this.result;

                                Ext.Ajax.request({
                                    headers: {'Content-Type': file.type},
                                    url: '/knitkit/erp_app/desktop/image_assets/shared/upload_file',
                                    jsonData: bin,
                                    params: {
                                        name: file.name,
                                        directory: 'root_node',
                                        is_drag_drop: true
                                    },
                                    success: function (result) {
                                        loadMask.hide();
                                        resultObj = Ext.JSON.decode(result.responseText);
                                        if (resultObj.success) {
                                            ckeditorPanel.insertHtml('<img src=' + resultObj.url + ' height="200" width="200" />');
                                            var sharedImageAssetsDataView = self.up('#knitkit').down('knitkit_ImageAssetsPanel').sharedImageAssetsDataView,
                                                sharedImageAssetsTreePanel = self.up('#knitkit').down('knitkit_ImageAssetsPanel').sharedImageAssetsTreePanel;

                                            sharedImageAssetsDataView.getStore().load({
                                                params: {
                                                    directory: sharedImageAssetsDataView.directory
                                                }
                                            });
                                            sharedImageAssetsTreePanel.getStore().load({
                                                callback: function () {
                                                    sharedImageAssetsTreePanel.getView().refresh();
                                                }
                                            });
                                        }
                                        else {
                                            Ext.Msg.alert('Error', 'Could not upload image');
                                        }
                                    },
                                    failure: function (result) {
                                        loadMask.hide();
                                        Ext.Msg.alert('Error', 'Could not upload image');
                                    }
                                });
                            }.bindToEventHandler(file));

                            reader.readAsDataURL(file);
                        }
                    }
                }
            });

            ckEditor.setValue(content);

            var items = [
                {
                    xtype: 'panel',
                    layout: 'fit',
                    split: true,
                    region: 'center',
                    items: ckEditor,
                    autoDestroy: true
                }
            ];

            if (!Compass.ErpApp.Utility.isBlank(siteId)) {
                items.push({
                    xtype: 'knitkit_versionsbloggridpanel',
                    contentId: id,
                    region: 'south',
                    height: 150,
                    collapsible: true,
                    collapsed: true,
                    centerRegion: self,
                    siteId: siteId
                });
            }
            else {
                items.push({
                    xtype: 'knitkit_nonpublishedversionswebsitesectiongridpanel',
                    contentId: id,
                    region: 'south',
                    height: 150,
                    collapsible: true,
                    collapsed: true,
                    centerRegion: self
                });
            }

            item = Ext.create("Ext.panel.Panel", {
                layout: 'border',
                title: title,
                closable: true,
                items: items,
                save: function (comp) {
                    if (currentUser.hasCapability('edit_html', 'Content')) {
                        var content = comp.down('ckeditor').getValue();
                        self.saveExcerpt(id, comp, content, siteId);
                        if (!Ext.isEmpty(contentGridStore)) contentGridStore.load();
                    } else {
                        currentUser.showInvalidAccess();
                    }
                },
                itemId: itemId
            });

            this.workArea.add(item);
        }

        this.workArea.setActiveTab(item);

    },

    /* image */

    showImage: function (node, themeId) {
        var self = this;
        var fileName = node.data.id.split('/').pop().split('.')[0];
        var fileType = node.data.id.split('.').pop();
        var itemId = Compass.ErpApp.Utility.Encryption.MD5(node.data.id);
        var item = this.workArea.query('#' + itemId).first();

        if (Compass.ErpApp.Utility.isBlank(item)) {
            item = Ext.create('Ext.panel.Panel', {
                closable: true,
                title: fileName + '.' + fileType,
                itemId: itemId,
                layout: 'fit',
                html: '<img src="' + node.get('url') + '&token=' +  Math.round(Math.random() * 10000000) + '" />'
            });

            self.workArea.add(item);
        }

        self.workArea.setActiveTab(item);
        return false;
    },

    /* content */

    saveContent: function (id, comp, content, contentType, siteId) {
        var self = this;
        this.setWindowStatus('Saving...');
        Ext.Ajax.request({
            url: '/knitkit/erp_app/desktop/content/update',
            method: 'POST',
            params: {
                id: id,
                html: content,
                site_id: siteId
            },
            success: function (response) {
                var obj = Ext.decode(response.responseText);
                if (obj.success) {
                    self.clearWindowStatus();
                    if (!Compass.ErpApp.Utility.isBlank(contentType)) {
                        var activeTab = self.workArea.getActiveTab();
                        var versionsGrid = activeTab.down('knitkit_versions' + contentType + 'gridpanel');
                        if (Ext.isEmpty(versionsGrid)) {
                            versionsGrid = activeTab.down('knitkit_nonpublishedversionswebsitesectiongridpanel');
                        }

                        if (!Ext.isEmpty(versionsGrid)) {
                            versionsGrid.getStore().load();
                        }
                    }
                    //comp.ckEditorInstance.focus();
                }
                else {
                    Ext.Msg.alert('Error', 'Error saving contents');
                    self.clearWindowStatus();
                }
            },
            failure: function (response) {
                self.clearWindowStatus();
                Ext.Msg.alert('Error', 'Error saving contents');
            }
        });
    },

    viewContent: function (title, content) {
        var ckEditor = Ext.create("Compass.ErpApp.Shared.CKeditor", {
            autoHeight: true,
            value: content,
            ckEditorConfig: {
                toolbar: [
                    ['Preview']
                ]
            }
        });

        var item = Ext.create('Ext.panel.Panel', {
            closable: true,
            layout: 'fit',
            title: title,
            split: true,
            items: ckEditor,
            autoDestroy: true
        });

        this.workArea.add(item);
        this.workArea.setActiveTab(item);
    },

    openIframeInTab: function (title, url) {

        var item = Ext.create('Ext.panel.Panel', {
            iframeId: 'themes_iframe',
            closable: true,
            layout: 'fit',
            title: title,
            html: '<iframe height="100%" width="100%" frameBorder="0" src="' + url + '"></iframe>'
        });

        this.workArea.add(item);
        this.workArea.setActiveTab(item);
    },

    editContent: function (title, id, content, siteId, contentType, contentGridStore) {
        var self = this;
        var itemId = 'editContent-' + id;
        var item = this.workArea.query('#' + itemId).first();

        if (Compass.ErpApp.Utility.isBlank(item)) {
            var ckEditor = Ext.create("Compass.ErpApp.Shared.CKeditor", {
                autoHeight: true,
                //value:content,
                ckEditorConfig: {
                    extraPlugins: self.ckEditorExtraPlugins,
                    toolbar: self.ckEditorToolbar
                },
                listeners: {
                    save: function (comp, content) {
                        self.saveContent(id, comp, content, contentType, siteId);
                        if (!Ext.isEmpty(contentGridStore)) contentGridStore.load();
                    },
                    ckeditordrop: function (ckeditorPanel, dropEvent) {
                        var dataTransfer = dropEvent.dataTransfer;
                        var files = dataTransfer.files;
                        for (var i = 0; i < files.length; i++) {
                            var loadMask = new Ext.LoadMask(ckeditorPanel, {msg: "Please wait..."});
                            loadMask.show();

                            var file = files[i];
                            var reader = new FileReader();

                            Compass.ErpApp.Utility.addEventHandler(reader, 'loadend', function (e, file) {
                                var bin = this.result;

                                Ext.Ajax.request({
                                    headers: {'Content-Type': file.type},
                                    url: '/knitkit/erp_app/desktop/image_assets/shared/upload_file',
                                    jsonData: bin,
                                    params: {
                                        name: file.name,
                                        directory: 'root_node',
                                        is_drag_drop: true
                                    },
                                    success: function (result) {
                                        loadMask.hide();
                                        resultObj = Ext.JSON.decode(result.responseText);
                                        if (resultObj.success) {
                                            ckeditorPanel.insertHtml('<img src=' + resultObj.url + ' height="200" width="200" />');
                                            var sharedImageAssetsDataView = self.up('#knitkit').down('knitkit_ImageAssetsPanel').sharedImageAssetsDataView,
                                                sharedImageAssetsTreePanel = self.up('#knitkit').down('knitkit_ImageAssetsPanel').sharedImageAssetsTreePanel;

                                            sharedImageAssetsDataView.getStore().load({
                                                params: {
                                                    directory: sharedImageAssetsDataView.directory
                                                }
                                            });
                                            sharedImageAssetsTreePanel.getStore().load({
                                                callback: function () {
                                                    sharedImageAssetsTreePanel.getView().refresh();
                                                }
                                            });
                                        }
                                        else {
                                            Ext.Msg.alert('Error', 'Could not upload image');
                                        }
                                    },
                                    failure: function (result) {
                                        loadMask.hide();
                                        Ext.Msg.alert('Error', 'Could not upload image');
                                    }
                                });
                            }.bindToEventHandler(file));

                            reader.readAsDataURL(file);
                        }
                    }
                }
            });

            ckEditor.setValue(content);

            var items = [
                {
                    xtype: 'panel',
                    layout: 'fit',
                    split: true,
                    region: 'center',
                    items: ckEditor,
                    autoDestroy: true
                }
            ];

            if (!Compass.ErpApp.Utility.isBlank(siteId)) {
                items.push({
                    xtype: 'knitkit_versions' + contentType + 'gridpanel',
                    contentId: id,
                    region: 'south',
                    height: 200,
                    collapsible: true,
                    collapsed: true,
                    centerRegion: self,
                    siteId: siteId
                });
            }
            else {
                items.push({
                    xtype: 'knitkit_nonpublishedversionswebsitesectiongridpanel',
                    contentId: id,
                    region: 'south',
                    height: 200,
                    collapsible: true,
                    collapsed: true,
                    centerRegion: self
                });
            }

            item = Ext.create('Ext.panel.Panel', {
                xtype: 'panel',
                layout: 'border',
                title: title,
                itemId: itemId,
                closable: true,
                items: items,
                save: function (comp) {
                    if (currentUser.hasCapability('edit_html', 'Content')) {
                        var content = comp.down('ckeditor').getValue();
                        self.saveContent(id, comp, content, contentType, siteId);
                        if (contentGridStore) {
                            contentGridStore.load();
                        }

                    } else {
                        currentUser.showInvalidAccess();
                    }
                }
            });
            this.workArea.add(item);
        }
        this.workArea.setActiveTab(item);
    },

    showComment: function (comment) {
        var activeTab = this.workArea.getActiveTab();
        var cardPanel = activeTab.query('panel')[0];
        cardPanel.removeAll(true);
        cardPanel.add({
            xtype: 'panel',
            html: '<div style="padding:10px;">'+comment+'</div>'
        });
        cardPanel.getLayout().setActiveItem(0);
    },

    viewContentComments: function (contentId, title) {
        var self = this;
        var itemId = 'contentComments-' + contentId;
        var item = this.workArea.query('#' + itemId).first();

        if (Compass.ErpApp.Utility.isBlank(item)) {
            item = Ext.create("Ext.panel.Panel", {
                layout: 'border',
                itemId: itemId,
                title: title,
                closable: true,
                items: [
                    {
                        xtype: 'panel',
                        layout: 'card',
                        split: true,
                        region: 'center',
                        items: [],
                        autoDestroy: true
                    },
                    {
                        xtype: 'knitkit_commentsgridpanel',
                        contentId: contentId,
                        region: 'south',
                        height: 300,
                        collapsible: true,
                        centerRegion: self
                    }
                ]
            });
            this.workArea.add(item);
        }

        this.workArea.setActiveTab(item);
    },

    viewWebsiteInquiries: function (websiteId, title) {
        var self = this;
        var itemId = 'websiteInqueries-' + websiteId;
        var item = this.workArea.query('#' + itemId).first();

        if (Compass.ErpApp.Utility.isBlank(item)) {
            item = Ext.create("Ext.panel.Panel", {
                layout: 'border',
                title: title + " Inquiries",
                itemId: itemId,
                closable: true,
                items: [
                    {
                        xtype: 'panel',
                        layout: 'card',
                        split: true,
                        region: 'center',
                        items: [],
                        autoDestroy: true
                    },
                    {
                        xtype: 'knitkit_inquiriesgridpanel',
                        websiteId: websiteId,
                        region: 'south',
                        height: 300,
                        collapsible: true,
                        centerRegion: self
                    }
                ]
            });

            this.workArea.add(item);
        }

        this.workArea.setActiveTab(item);
    },

    insertHtmlIntoActiveCkEditor: function (html) {
        var activeTab = this.workArea.getActiveTab();
        if (Compass.ErpApp.Utility.isBlank(activeTab)) {
            Ext.Msg.alert('Error', 'No editor');
        }
        else {
            if (activeTab.query('ckeditor').length === 0) {
                Ext.Msg.alert('Error', 'No ckeditor found');
            }
            else {
                activeTab.query('ckeditor')[0].insertHtml(html);
            }
        }
        return false;
    },

    replaceHtmlInActiveCkEditor: function (html) {
        var activeTab = this.workArea.getActiveTab();
        if (Compass.ErpApp.Utility.isBlank(activeTab)) {
            Ext.Msg.alert('Error', 'No editor');
        }
        else {
            if (activeTab.query('ckeditor').length === 0) {
                Ext.Msg.alert('Error', 'No ckeditor found');
            }
            else {
                activeTab.query('ckeditor')[0].setValue(html);
            }
        }
        return false;
    },

    replaceContentInActiveCodeMirror: function (content) {
        var activeTab = this.workArea.getActiveTab();
        if (Compass.ErpApp.Utility.isBlank(activeTab)) {
            Ext.Msg.alert('Error', 'No editor');
        }
        else {
            if (activeTab.query('codemirror').length === 0) {
                Ext.Msg.alert('Error', 'No codemirror found.');
            }
            else {
                activeTab.query('codemirror')[0].setValue(content);
            }
        }
        return false;
    },

    addContentToActiveCodeMirror: function (content) {
        var activeTab = this.workArea.getActiveTab();
        if (Compass.ErpApp.Utility.isBlank(activeTab)) {
            Ext.Msg.alert('Error', 'No editor');
        }
        else {
            if (activeTab.query('codemirror').length === 0) {
                Ext.Msg.alert('Error', 'No codemirror found. Note that a widget can only be added to a Layout.');
            }
            else {
                activeTab.query('codemirror')[0].insertContent(content);
            }
        }
    },

    insertHtmlIntoActiveCkEditorOrCodemirror: function (html) {
        var activeTab = this.workArea.getActiveTab();
        if (Compass.ErpApp.Utility.isBlank(activeTab)) {
            Ext.Msg.alert('Error', 'No editor');
        }
        else {
            if (activeTab.down('ckeditor')) {
                activeTab.down('ckeditor').insertHtml(html);
            }
            else if (activeTab.down('codemirror')) {
                activeTab.down('codemirror').insertContent(html);
            }
            else {
                Ext.Msg.alert('Error', 'No ckeditor or codemirror found');
            }
        }
        return false;
    },

    saveCurrent: function () {
        var activeTab = this.workArea.getActiveTab();
        if (!Ext.isEmpty(activeTab) && !Ext.isEmpty(activeTab.initialConfig.save)) {
            activeTab.initialConfig.save(activeTab);
        }
    },

    saveAll: function () {
        this.workArea.items.each(function (comp) {
            if (!Ext.isEmpty(comp) && !Ext.isEmpty(comp.initialConfig.save)) {
                comp.initialConfig.save(comp);
            }
        });
    },

    constructor: function (config) {
        region = this;
        this.workArea = Ext.createWidget('tabpanel', {
            autoDestroy: true,
            region: 'center',
            plugins: Ext.create('Ext.ux.TabCloseMenu', {
                extraItemsTail: [
                    '-',
                    {
                        text: 'Closable',
                        checked: true,
                        hideOnClick: true,
                        handler: function (item) {
                            currentItem.tab.setClosable(item.checked);
                        }
                    },
                    '-',
                    {
                        text: 'Enabled',
                        checked: true,
                        hideOnClick: true,
                        handler: function (item) {
                            currentItem.tab.setDisabled(!item.checked);
                        }
                    }
                ],
                listeners: {
                    beforemenu: function (menu, item) {
                        var enabled = menu.child('[text="Enabled"]');
                        menu.child('[text="Closable"]').setChecked(item.closable);
                        if (item.tab.active) {
                            enabled.disable();
                        } else {
                            enabled.enable();
                            enabled.setChecked(!item.tab.isDisabled());
                        }

                        currentItem = item;
                    }
                }
            }),
            listeners: {
                add: function () {
                    this.smartRenameTabs();
                },
                remove: function () {
                    this.smartRenameTabs();
                },
                tabchange: function (tabPanel, newPanel, oldPanel, eOpts) {
                    // check if the panel has ckEditor
                    var ckEditor = newPanel.down('ckeditor');
                    if (ckEditor) {
                        CKEDITOR.domReady(function () {
                            ckEditor.ckEditorInstance.focus();
                        });
                    }
                }
            },

            smartRenameTabs: function () {
                var tabs = this.queryBy(function (record) {
                        // If no filePathHash is found, this item is not an actual tab element, don't collect it into tabs array
                        if (record.filePathHash != undefined) {
                            return true;
                        } else {
                            return false;
                        }
                    }),
                    baseNames = {},
                    fileNames = {};

                // Collect counts for each unique baseName and fileName
                Ext.each(tabs, function (tab) {
                    if (!baseNames[tab.baseName]) {
                        baseNames[tab.baseName] = 1;
                    } else {
                        baseNames[tab.baseName]++;
                    }

                    if (!fileNames[tab.fileName]) {
                        fileNames[tab.fileName] = 1;
                    } else {
                        fileNames[tab.fileName]++;
                    }
                });

                // Rename each tab as needed
                Ext.each(tabs, function (tab) {
                    if (baseNames[tab.baseName] > 1) {
                        // Duplicate fileName, use fileName + container directory in title
                        if (fileNames[tab.fileName] > 1) {
                            tab.setTitle(tab.fileName + " (" + tab.containerDir + ")");
                        } else { // Duplicate baseName but unique fileName, use fileName for title
                            tab.setTitle(tab.fileName);
                        }
                    } else { // Unique basename, use it for titles
                        tab.setTitle(tab.baseName);
                    }
                });
            }
        });

        startupPanel = Ext.createWidget('knitkit_splash_screen', {
            closable: true,
            centerRegion: region
        });
        this.workArea.add(startupPanel);
        this.workArea.setActiveTab(startupPanel);

        config = Ext.apply({
            id: 'knitkitCenterRegion',
            autoDestroy: true,
            layout: 'border',
            region: 'center',
            //split:true,
            items: [this.workArea]
        }, config);

        this.callParent([config]);
    }
});
