Ext.define("Compass.ErpApp.Shared.Crm.PartyDetailsPanel", {
    extend: "Ext.panel.Panel",
    alias: 'widget.crmpartydetailspanel',
    cls: 'crmpartydetailspanel',
    layout: 'border',
    items: [],
    contactWidgetXtypes: [
        'phonenumbergrid',
        'emailaddressgrid',
        'postaladdressgrid'
    ],

    /**
     * @cfg {String} applicationContainerId
     * The id of the root application container that this panel resides in.
     */
    applicationContainerId: 'crmTaskTabPanel',

    /**
     * @cfg {Int} partyId
     * Id of party being edited.
     */
    partyId: null,

    /**
     * @cfg {String} detailsUrl
     * Url to retrieve details for these parties.
     */
    detailsUrl: '/erp_app/organizer/crm/base/get_party_details/',

    /**
     * @cfg {Array | Object} partyRelationships
     * Party Relationships to include in the details of this party, is an config object with the following options
     *
     * @param {String} title
     * title of tab
     *
     * @param {String} relationshipType
     * relationship type internal_identifier
     *
     * @param {String} relationshipDirection {from | to}
     * if we are getting the to or from side of relationships
     *
     * @param {String} toRoleType
     * RoleType internal_identifier for to side
     *
     * @param {String} fromRoleType
     * RoleType internal_identifier for from side
     *
     * @example
     * {
            title: 'Employees',
            relationshipType: 'employee_customer',
            toRoleType: 'customer',
            fromRoleType: 'employee'
        }
     */
    partyRelationships: [],

    initComponent: function () {
        var me = this,
            tabPanels = [];

        contactsPanel = Ext.create('widget.panel', {
            title: 'Contacts',
            layout: 'border',
            itemId: 'contactsContainer',
            items: [
                {
                    xtype: 'panel',
                    collapsible: true,
                    region: 'west',
                    width: 155,
                    items: Ext.create('widget.dataview', {
                        autoScroll: true,
                        store: Ext.create('Ext.data.SimpleStore', {
                            fields: ['title', 'xtype', 'iconSrc'],
                            data: [
                                ['Phone Numbers', 'phonenumbergrid', '/images/icons/phone/phone_16x16.png'],
                                ['Email Addresses', 'emailaddressgrid', '/images/icons/mail/mail_16x16.png'],
                                ['Postal Addressses', 'postaladdressgrid', '/images/icons/home/home_16x16.png']
                            ]
                        }),
                        selModel: {
                            mode: 'SINGLE',
                            listeners: {
                                selectionchange: function (dataView, selection) {
                                    if (selection) {
                                        selection = selection.first();

                                        var selectedContactContainer = me.down('#contactsContainer').down('#selectedContactContainer'),
                                            selectedContact = selectedContactContainer.down(selection.data.xtype);

                                        selectedContactContainer.layout.setActiveItem(selectedContact);
                                    }
                                }
                            }
                        },
                        listeners: {
                            viewready: function (dataView) {
                                dataView.getSelectionModel().select(dataView.store.first());
                            }
                        },
                        trackOver: true,
                        cls: 'crm-contacts-list',
                        itemSelector: '.crm-contacts-list-item',
                        overItemCls: 'crm-contacts-list-item-hover',
                        tpl: '<tpl for="."><img class="crm-contacts-list-icon" src="{iconSrc}" /><div class="crm-contacts-list-item">{title}</div></tpl>'
                    })
                },
                {
                    xtype: 'panel',
                    flex: 1,
                    itemId: 'selectedContactContainer',
                    cls: 'selectedContactContainer',
                    region: 'center',
                    layout: 'card',
                    items: [
                        {xtype: 'phonenumbergrid', partyId: me.partyId, listeners:{'contactdatawrite':{fn:me.loadDetails,scope:me}}},
                        {xtype: 'emailaddressgrid', partyId: me.partyId, listeners:{'contactdatawrite':{fn:me.loadDetails,scope:me}}},
                        {xtype: 'postaladdressgrid', partyId: me.partyId, listeners:{'contactdatawrite':{fn:me.loadDetails,scope:me}}}
                    ]
                }
            ]
        });

        tabPanels.push(contactsPanel);
        tabPanels.push({xtype: 'shared_notesgrid', partyId: me.partyId});

        me.partyDetailsPanel = Ext.create('widget.panel', {
            //flex: 1,
            //height: 300,
            itemId: 'partyDetails',
            html: 'Party Details',
            border: false,
            frame: false,
            region: 'center',
            autoScroll: true
        });

        Ext.each(me.partyRelationships, function (partyRelationship) {
            tabPanels.push({
                xtype: 'crmpartygrid',
                title: partyRelationship.title,
                applicationContainerId: me.applicationContainerId,
                addBtnDescription: 'Add ' + Ext.String.capitalize(partyRelationship.fromRoleType),
                searchDescription: 'Search ' + partyRelationship.title,
                toRole: partyRelationship.toRoleType,
                toPartyId: me.partyId,
                relationshipTypeToCreate: partyRelationship.relationshipType,
                partyRole: partyRelationship.fromRoleType,
                canAddParty: partyRelationship.canAddParty || true,
                canEditParty: partyRelationship.canEditParty || true,
                canDeleteParty: partyRelationship.canDeleteParty || true,
                listeners: {
                    partycreated: function (comp, partyId) {
                        this.store.load();
                    },
                    partyupdated: function (comp, partyId) {
                        this.store.load();
                    }
                }
            });
        });

        me.partyDetailsTabPanel = Ext.create('widget.tabpanel', {
            //flex: 1,
            height: 400,
            collapsible: true,
            region: 'south',
            items: tabPanels
        });

        me.items = [me.partyDetailsPanel, me.partyDetailsTabPanel];

        this.callParent(arguments);
    },

	loadDetails: function(){
		var me = this,
			detailsUrl = me.detailsUrl,
			partyDetails = me.down('#partyDetails');
		
		var myMask = new Ext.LoadMask(partyDetails, {msg:"Please wait..."});
		myMask.show();
		
		// Load html of party
        Ext.Ajax.request({
            url: detailsUrl + me.partyId,
            disableCaching: false,
            method: 'GET',
            success: function (response) {
                myMask.hide();
				partyDetails.update(response.responseText);
            }
        });
	},

    loadParty: function () {
        var me = this,
            tabPanel = me.down('tabpanel');

        me.loadDetails();

        // Load contact stores
        for (i = 0; i < me.contactWidgetXtypes.length; i += 1) {
            var widget = tabPanel.down(me.contactWidgetXtypes[i]);
            if (!Ext.isEmpty(widget)) {
                widget.store.load();
            }
        }
    }
});