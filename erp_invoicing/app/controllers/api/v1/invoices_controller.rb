module API
  module V1
    class InvoicesController < BaseController

      def index
        query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys

        invoices = Invoice.apply_filters(query_filter)

        # scope by dba organization
        invoices = invoices.joins("inner join invoice_party_roles as invoice_party_reln on
                          (invoice_party_reln.invoice_id = invoices.id
                          and
                          invoice_party_reln.party_id in (#{current_user.party.dba_organization.id})
                          and
                          invoice_party_reln.role_type_id = #{RoleType.iid('dba_org').id}
                          )")

        total_count = invoices.count

        render json: {total_count: total_count, invoices: invoices.collect{|invoice| invoice.to_data_hash} }
      end

      #
      # Invoice actions
      #

      def next_invoice_number
        render :json => {success: true, invoice_number: Invoice.next_invoice_number}
      end

      def generate_invoice
        # clean up params
        message = params[:message].blank? ? '' : params[:message].strip
        invoice_date = Date.strptime(params[:invoice_date], '%m/%d/%Y')
        due_date = Date.strptime(params[:due_date], '%m/%d/%Y')

        invoice = Invoice.generate_from_order(OrderTxn.find(params[:order_id]),
                                              {
                                                dba_organization: current_user.party.dba_organization,
                                                invoice_date: invoice_date,
                                                due_date: due_date,
                                                message: message
                                              }
                                              )

        render :json => {success: true, invoice_id: invoice.id}
      end

      def print_invoice
        @invoice = Invoice.find(params[:id])
        @business_module = BusinessModule.find(params[:business_module_id])

        set_address_and_logo

        render :invoice
      end

      def generate_pdf
        @invoice = Invoice.find(params[:id])
        @business_module = BusinessModule.find(params[:business_module_id])

        set_address_and_logo

        pdf = WickedPdf.new.pdf_from_string(render_to_string(:layout => false, :action => "invoice_pdf.html.erb"),
                                            :margin => {:top => 0, :bottom => 15, :left => 10, :right => 10},
                                            :footer => {
                                              :right => 'Page [page] of [topage]'
        })

        @invoice_file_name = @invoice.invoice_number

        send_data(pdf,
                  :filename => "Invoice-##{@invoice_file_name}.pdf",
                  :type => "application/pdf",
                  :disposition => "inline")
      end

      def email_invoice
        from_email = params[:from_email].squish
        to_email = params[:to_email].squish
        cc_email = params[:cc_email].blank? ? nil : params[:cc_email].squish
        subject = params[:subject].squish
        email_message = params[:message].squish
        @invoice = Invoice.find(params[:id])
        @business_module = BusinessModule.find(params[:business_module_id])

        set_address_and_logo

        pdf = WickedPdf.new.pdf_from_string(render_to_string(:layout => false, :action => "invoice_pdf.html.erb"),
                                            :margin => {:top => 0, :bottom => 15, :left => 10, :right => 10},
                                            :footer => {
                                              :right => 'Page [page] of [topage]'
        })

        attachments = {"#{@invoice.invoice_number}.pdf" => pdf}
        unless params[:file_attachment_ids].blank?
          params[:file_attachment_ids].split(',').each do |file_asset_id|
            file_asset = FileAsset.find(file_asset_id)

            file_support = ErpTechSvcs::FileSupport::Base.new(:storage => Rails.application.config.erp_tech_svcs.file_storage)
            contents = file_support.get_contents(file_asset.data.path).first

            attachments["#{file_asset.name}"] = contents
          end
        end

        InvoiceMailer.email_invoice(from_email, to_email, cc_email, subject, @invoice, email_message, attachments).deliver

        unless @invoice.current_status == 'invoice_statuses_closed'
          @invoice.current_status = 'invoice_statuses_sent'
        end

        render :json => {success: true}
      end

      #
      # Payment actions
      #

      def customer_credit_cards
        customer = Party.find(params[:id])
        credit_cards = customer.credit_cards

        render json: {success: true,
                      credit_cards: credit_cards.collect { |credit_card| {last_four: credit_card.last_4, id: credit_card.id} }}
      end

      def make_payment
        begin
          amount = params[:amount].to_f
          payment_method = params[:payment_method]
          invoice = Invoice.find(params[:id])

          ActiveRecord::Base.transaction do

            card_information = {
              card_number: params[:card_number],
              name_on_card: params[:name_on_card],
              exp_month: params[:exp_month],
              exp_year: params[:exp_year]
            }

            result = invoice.make_payment(current_user,
                                          payment_method,
                                          amount,
                                          params[:token],
                                          params[:one_time_payment],
                                          card_information,
                                          params[:customer_id])

            if result[:success]
              render :json => {success: true, message: 'Charge Successful'}
            else
              render :json => {success: false, message: result[:message]}
            end

          end # transaction
        rescue Exception => e
          Rails.logger.error(e.message)
          Rails.logger.error(e.backtrace.join("\n"))

          render :json => {success: false, message: 'Could not process payment.  Please try again later.'}

        end # Begin

      end # make_payment

      protected

      def set_utc_offset
        @client_utc_offset = params[:client_utc_offset]
      end

      def set_address_and_logo
        @company_address = ''

        logo = current_user.party.dba_organization.files.scoped_by('logo', true).first

        if logo
          @logo_url = logo.fully_qualified_url
        end

        address = current_user.party.dba_organization.find_contact_mechanism_with_purpose(PostalAddress, ContactPurpose.billing)

        if address
          @company_address = address.to_label do |postal_address|
            buffer = postal_address.address_line_1
            unless postal_address.address_line_2.blank?
              buffer += "<br/>#{postal_address.address_line_2}"
            end
            buffer += "<br/>#{postal_address.city}, #{postal_address.state} #{postal_address.zip}"

            buffer
          end
        end
      end

    end # InvoicesController
  end # V1
end # API
