#### Table Definition ###########################
#  create_table :invoices do |t|
#    t.string     :invoice_number
#    t.string     :description
#    t.string     :message
#    t.date       :invoice_date
#    t.date       :due_date
#    t.string     :external_identifier
#    t.string     :external_id_source
#    t.references :product
#    t.references :invoice_type
#    t.references :billing_account
#    t.references :invoice_payment_strategy_type
#    t.references :balance
#    t.references :calculate_balance_strategy_type
#
#    t.timestamps
#  end
#################################################

class Invoice < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  has_file_assets
  can_be_generated

  has_tracked_status

  tracks_created_by_updated_by

  belongs_to :billing_account
  belongs_to :invoice_type
  belongs_to :invoice_payment_strategy_type
  belongs_to :balance_record, :class_name => "Money", :foreign_key => 'balance_id', :dependent => :destroy
  belongs_to :calculate_balance_strategy_type
  has_many :invoice_payment_term_sets, :dependent => :destroy
  has_many :payment_applications, :as => :payment_applied_to, :dependent => :destroy do
    def successful
      all.select { |item| item.financial_txn.has_captured_payment? }
    end

    def pending
      all.select { |item| item.is_pending? }
    end
  end
  has_many :invoice_items, :dependent => :destroy do
    def by_date
      order('created_at')
    end

    def unpaid
      select { |item| item.balance > 0 }
    end
  end
  has_many :invoice_party_roles, :dependent => :destroy
  has_many :parties, :through => :invoice_party_roles

  alias :items :invoice_items
  alias :type :invoice_type
  alias :party_roles :invoice_party_roles
  alias :payment_strategy :invoice_payment_strategy_type

  class << self

    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement=nil)
      if statement.nil?
        statement = self
      end

      unless filters[:status].blank?
        if filters[:status] == 'open'
          statement = statement.open
        end

        if filters[:status] == 'closed'
          statement = statement.closed
        end
      end

      statement
    end

    # generate an invoice from a order_txn
    # options include
    # message - Message to display on Invoice
    # invoice_date - Date of Invoice
    # due_date - Due date of Invoice
    # taxation - context for taxation
    #   {
    #     is_online_sale: true,
    #         origin_address: {
    #         state: "FL"
    #     },
    #         destination_address: {
    #         state: "FL"
    #     }
    #   }
    #
    def generate_from_order(order_txn, options={})
      ActiveRecord::Base.connection.transaction do
        invoice = Invoice.new

        # create invoice
        invoice.invoice_number = next_invoice_number
        invoice.description = "Invoice for #{order_txn.order_number.to_s}"
        invoice.message = options[:message]
        invoice.invoice_date = options[:invoice_date]
        invoice.due_date = options[:due_date]
        invoice.invoice_type = InvoiceType.iid('acct_receivable')

        invoice.save

        invoice.current_status = 'invoice_statuses_open'

        # add customer relationship
        party = order_txn.find_party_by_role('order_roles_customer')
        invoice.add_party_with_role(party, RoleType.customer)

        dba_organization = options[:dba_organization] || order_txn.find_party_by_role(RoleType.iid('dba_org'))
        invoice.add_party_with_role(dba_organization, RoleType.dba_org)

        order_txn.order_line_items.each do |line_item|
          invoice_item = InvoiceItem.new

          invoice_item.invoice = invoice

          charged_item = line_item.inventory_entry || line_item.product_instance || line_item.product_offer || line_item.product_type 

          if charged_item.is_a? InventoryEntry
            invoice_item.item_description = charged_item.product_type.description
          else
            invoice_item.item_description = charged_item.description
          end
          
          invoice_item.quantity = line_item.quantity
          invoice_item.unit_price = line_item.sold_price
          invoice_item.amount = line_item.total_amount
          invoice_item.taxed = line_item.taxed?
          invoice_item.biz_txn_acct_root = charged_item.try(:revenue_gl_account)
          invoice_item.add_invoiced_record(charged_item)

          invoice.invoice_items << invoice_item

          invoice_item.save
        end

        # handles everything but shipping charge lines, multiple invoice items created from all iterations
        order_txn.all_charge_lines.select { |charge_line| charge_line.charge_type && charge_line.charge_type.internal_identifier != 'shipping' }.each do |charge_line|
          invoice_item = InvoiceItem.new

          invoice_item.invoice = invoice
          charged_item = charge_line.charged_item
          invoice_item.item_description = charge_line.description
          invoice_item.type = InvoiceItemType.find_or_create(charge_line.charge_type.internal_identifier, charge_line.charge_type.description)

          # set data based on charged item either a OrderTxn or OrderLineItem
          if charged_item.is_a?(OrderLineItem)
            invoice_item.quantity = charged_item.quantity
            invoice_item.unit_price = charged_item.sold_price
            invoice_item.amount = charged_item.sold_amount
            invoice_item.add_invoiced_record(charged_item.line_item_record)
            invoice_item.taxed = charged_item.taxed?
          elsif charged_item.is_a?(OrderTxn)
            invoice_item.quantity = 1
            invoice_item.unit_price = charge_line.money.amount
            invoice_item.amount = charge_line.money.amount
            invoice_item.add_invoiced_record(charge_line)
          end

          invoice.invoice_items << invoice_item

          invoice_item.save!
        end

        # handles shipping charge lines, one invoice item created from all iterations
        shipping_charges = order_txn.all_charge_lines.select { |charge_line| charge_line.charge_type && charge_line.charge_type.internal_identifier == 'shipping' }
        if shipping_charges.length > 0
          shipping_invoice_item = InvoiceItem.new
          shipping_charges.each do |charge_line|
            shipping_invoice_item.item_description = charge_line.description
            shipping_invoice_item.invoice = invoice
            shipping_invoice_item.quantity = 1
            shipping_invoice_item.amount = shipping_invoice_item.unit_price.nil? ? charge_line.money.amount : shipping_invoice_item.unit_price + charge_line.money.amount
            shipping_invoice_item.unit_price = shipping_invoice_item.unit_price.nil? ? charge_line.money.amount : shipping_invoice_item.unit_price + charge_line.money.amount
            shipping_invoice_item.taxed = charge_line.taxed?
            shipping_invoice_item.biz_txn_acct_root = BizTxnAcctRoot.where(internal_identifier: 'shipping', biz_txn_acct_type_id: BizTxnAcctType.iid('gl_account')).first
            shipping_invoice_item.add_invoiced_record(charge_line)

            invoice.invoice_items << shipping_invoice_item
          end
          shipping_invoice_item.save
        end

        invoice.generated_by = order_txn

        # calculate taxes
        if options[:taxation]
          invoice.calculate_tax!(options[:taxation])
        end

        invoice
      end
    end

    def next_invoice_number
      max_id = maximum('id')

      current_invoice = where(Invoice.arel_table[:invoice_number].matches("%#{max_id}%")).first

      if current_invoice
        while current_invoice
          max_id = max_id + 1
          current_invoice = where(Invoice.arel_table[:invoice_number].matches("%#{max_id}%")).first
        end
      else
        if max_id
          max_id = max_id + 1
        else
          max_id = 1
        end
      end

      "Inv-#{max_id}"
    end

    def open
      Invoice.with_current_status(['invoice_statuses_open'])
    end

    def closed
      Invoice.with_current_status(['invoice_statuses_closed'])
    end

    def hold
      Invoice.with_current_status(['invoice_statuses_hold'])
    end

    def sent
      Invoice.with_current_status(['invoice_statuses_sent'])
    end
  end

  def has_invoice_items?
    !self.items.empty?
  end

  def has_payments?(status=:all)
    selected_payment_applications = self.get_payment_applications(status)

    !(selected_payment_applications.nil? or selected_payment_applications.empty?)
  end

  def get_payment_applications(status=:all)
    selected_payment_applications = case status.to_sym
    when :pending
      self.payment_applications.pending
    when :successful
      self.payment_applications.successful
    when :all
      self.payment_applications
    end

    unless self.items.empty?
      unless self.items.collect { |item| item.get_payment_applications(status) }.empty?
        selected_payment_applications = (selected_payment_applications | self.items.collect { |item| item.get_payment_applications(status) }).flatten!
      end
    end

    selected_payment_applications
  end

  def sub_total
    if items.empty?
      if self.balance_record
        self.balance_record.amount
      else
        0
      end
    else
      self.items.all.sum(&:sub_total).round(2)
    end
  end

  def total_amount
    if items.empty?
      if self.balance_record
        self.balance_record.amount
      else
        0
      end
    else
      self.items.all.sum(&:total_amount).round(2)
    end
  end

  def balance
    if items.empty?
      if self.balance_record
        self.balance_record.amount
      else
        0
      end
    else
      self.items.all.sum(&:total_amount).round(2)
    end
  end

  alias payment_due balance

  def balance=(amount, currency=Currency.usd)
    if self.balance_record
      self.balance_record.amount = amount
    else
      self.balance_record = Money.create(:amount => amount, :currency => currency)
    end
    self.balance_record.save
  end

  def total_payments
    self.get_payment_applications(:successful).sum { |item| item.money.amount }
  end

  # calculates tax for each line item and save to sales_tax
  def calculate_tax!(ctx={})
    tax = 0

    self.invoice_items.each do |line_item|
      tax += line_item.calculate_tax!(ctx)
    end

    self.sales_tax = tax
    self.save

    tax
  end

  def calculate_balance
    unless self.calculate_balance_strategy_type.nil?
      case self.calculate_balance_strategy_type.internal_identifier
      when 'invoice_items_and_payments'
        (self.items.all.sum(&:total_amount) - self.total_payments).round(2)
      when 'payable_balances_and_payments'
        (self.payable_balances.all.sum(&:balance).amount - self.total_payments).round(2)
      when 'payments'
        (self.balance - self.total_payments).round(2)
      else
        self.balance
      end
    else
      unless self.balance.nil?
        (self.balance - self.total_payments).round(2)
      end
    end
  end

  def transactions
    transactions = []

    self.items.each do |item|
      transactions << {
        :date => item.created_at,
        :description => item.item_description,
        :quantity => item.quantity,
        :amount => item.amount
      }
    end

    self.get_payment_applications(:successful).each do |item|
      transactions << {
        :date => item.financial_txn.payments.last.created_at,
        :description => item.financial_txn.description,
        :quantity => 1,
        :amount => (0 - item.financial_txn.money.amount)
      }
    end

    transactions.sort_by { |item| [item[:date]] }
  end

  def add_party_with_role(party, role_type)
    self.invoice_party_roles << InvoicePartyRole.create(:party => party, :role_type => convert_role_type(role_type))
    self.save
  end

  def find_parties_by_role_type(role_type)
    if role_type.is_a? RoleType
      role_types = RoleType.find_child_role_types([role_type.internal_identifier])
    else
      role_types = RoleType.find_child_role_types([role_type])
    end

    self.invoice_party_roles.where(role_type_id: role_types).all.collect(&:party)
  end

  def find_party_by_role(role_type)
    parties = find_parties_by_role_type(role_type)

    unless parties.empty?
      parties.first
    end
  end

  def dba_organization
    find_parties_by_role_type('dba_org').first
  end
  alias :tenant :dba_organization

  def to_data_hash
    to_hash(only: [:id, :created_at, :updated_at, :description, :invoice_number, :invoice_date, :due_date])
  end

  # Make payment on invoice
  #
  # @param {User} current_user Current User
  # @param {String} payment_method Payment Method cash, check, credit
  # @param {Float} amount Amount of payment
  # @param {String} [token] Token from Payment Gateway
  # @param {Boolean} [one_time_payment] If this is a one time payment
  # @param {Hash} [card_information] Card information
  # @param {Integer} [customer_id] Id of Customer
  # @param {Integer} [website_id] Id of Website
  # @return {Hash} results
  def make_payment(current_user, payment_method, amount, token=nil, one_time_payment=false, card_information={}, customer_id=nil, website_id=nil)
    begin
      # create money and financial txn records
      money = Money.new
      money.currency = Currency.usd
      money.amount = amount
      money.description = "Invoice ##{self.invoice_number} Payment"
      money.save!

      financial_txn = FinancialTxn.new
      financial_txn.money = money
      financial_txn.apply_date = Date.today
      financial_txn.save!

      biz_txn_event = financial_txn.root_txn

      # tie financial_txn to dba_org
      dba_org_role_type = BizTxnPartyRoleType.find_or_create('dba_org', 'Doing Business As Organization')
      tpr = BizTxnPartyRole.new
      tpr.biz_txn_event = biz_txn_event
      tpr.party = current_user.party.dba_organization
      tpr.biz_txn_party_role_type = dba_org_role_type
      tpr.save

      # tie financial_txn to customer
      biz_txn_role_type = BizTxnPartyRoleType.iid('payor')
      tpr = BizTxnPartyRole.new
      tpr.biz_txn_event = biz_txn_event
      tpr.party = self.find_party_by_role('customer')
      tpr.biz_txn_party_role_type = biz_txn_role_type
      tpr.save

      # set txn type
      if payment_method == 'cash' or payment_method == 'check'
        financial_txn.root_txn.txn_type = BizTxnType.find_or_create(payment_method, payment_method.humanize, BizTxnType.iid('payment_transaction'))
      else
        financial_txn.root_txn.txn_type = BizTxnType.find_or_create('credit_card', 'Credit Card', BizTxnType.iid('payment_transaction'))
      end

      financial_txn.save

      if payment_method == 'cash' or payment_method == 'check'
        authorization_code = reference_number = "#{payment_method}_#{SecureRandom.hex(5)}"

        payment = Payment.new
        payment.success = true
        payment.reference_number = reference_number
        payment.authorization_code = authorization_code
        payment.financial_txn = financial_txn
        payment.capture
        payment.save!

      else
        stripe_external_system = ExternalSystem.with_party_role(current_user.party.dba_organization, RoleType.iid('owner'))
        .where('external_systems.internal_identifier' => 'stripe').first

        if payment_method == 'credit' && token
          if one_time_payment
            credit_card = CreditCard.new(credit_card_token: token)
            credit_card.card_number = card_information[:card_number]
            credit_card.expiration_month = card_information[:exp_month]
            credit_card.expiration_year = card_information[:exp_year]

            result = CreditCardAccount.new.purchase(financial_txn,
                                                    nil,
                                                    CompassAeBusinessSuite::ActiveMerchantWrappers::StripeWrapper,
                                                    {
                                                      private_key: stripe_external_system.private_key,
                                                      public_key: stripe_external_system.public_key
            }, credit_card)
          else
            credit_card = nil
            customer = Party.find(customer_id)

            # we need to store the new card and then charge it
            result = CreditCard.validate_and_update({
                                                      party: customer,
                                                      card_number: card_information[:card_number],
                                                      token: token,
                                                      cvc: nil,
                                                      name_on_card: card_information[:name_on_card],
                                                      exp_month: card_information[:exp_month],
                                                      exp_year: card_information[:exp_year],

                                                    },
                                                    customer.primary_credit_card,
                                                    [stripe_external_system])

            # if adding the card was successful then retrieve it
            # if not leave it nil and message will be returned
            if result[:success]
              credit_card = result[:credit_card]
              # manually save credit card to stripe because we need to use it to purchase
              credit_card_handler = MasterDataManagement::ExternalSystems::EventHandlers::Stripe::CreditCard.new(credit_card.mdm_entity, stripe_external_system)
              if credit_card_handler.create(credit_card, {}) === false
                credit_card.notify_except(stripe_external_system)
                credit_card.destroy!
                credit_card = nil
              end
            end
          end

        else
          credit_card = CreditCard.find(payment_method)
        end

        # if we have a stored credit card charge it
        if credit_card && !one_time_payment
          credit_card_account = credit_card.credit_card_account_party_role.credit_card_account
          # check if the credit card as a stripe mapping, if it does purchase with existing else do
          # one time purchase but save the txn to the card as it will by synced to Stripe later.
          result = credit_card_account.purchase_with_existing_card(financial_txn,
                                                                   CompassAeBusinessSuite::ActiveMerchantWrappers::StripeWrapper,
                                                                   {
                                                                     private_key: stripe_external_system.private_key,
                                                                     public_key: stripe_external_system.public_key
          })

          # add financial txn to CreditCardAccount
          credit_card_account.account_root.biz_txn_events << financial_txn.root_txn
          credit_card_account.account_root.save
        end

        payment = result[:payment]
      end

      if payment && payment.success
        payment_application = PaymentApplication.new
        payment_application.financial_txn = financial_txn
        payment_application.payment_applied_to = self
        payment_application.applied_money_amount_id = money.id
        payment_application.save!

        payment_application.apply_payment

        if self.calculate_balance == 0
          self.current_status = 'invoice_statuses_closed'
        end

        PaymentMailer.delay.payment_success(payment_application.id, website_id)
      else
        PaymentMailer.delay.payment_failure(self.id, self.find_party_by_role('customer').id, website_id)
      end

      # touch payment to trigger sync
      payment.touch
      payment.force_sync!

      {success: true}

    rescue Stripe::CardError => e
      {success: false, message: e.message}
    end
  end

  private

  def convert_role_type(role_type)
    role_type = RoleType.iid(role_type) if role_type.is_a? String
    raise "Role type does not exist" if role_type.nil?

    role_type
  end

end
