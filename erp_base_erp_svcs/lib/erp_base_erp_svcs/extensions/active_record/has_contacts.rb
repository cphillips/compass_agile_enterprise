module ErpBaseErpSvcs
  module Extensions
    module ActiveRecord
      module HasContacts

        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def has_contacts
            extend HasContacts::SingletonMethods
            include HasContacts::InstanceMethods

            after_initialize :build_contact_methods

            has_many :contacts, :as => :contact_record, :dependent => :destroy

          end
        end

        module SingletonMethods

          # Return record that match the passed Email value
          # 
          # @param [Hash] email Email to search by
          # @param [ContactPurpose] [contact_purpose] Contact Purpose to filter by
          # @return [Object] Record if found by email address
          #
          def find_by_email(email, contact_purpose=nil)
            if contact_purpose
              self.joins(:contacts => [:contact_purposes])
              .joins("INNER JOIN email_addresses on email_addresses.id = contacts.contact_mechanism_id
                and contacts.contact_mechanism_type = 'EmailAddress'")
              .where('contact_mechanism_type = ?', 'EmailAddress')
              .where('contact_purposes.internal_identifier = ?', contact_purpose)
              .where('email_address = ?', email).readonly(false).first
            else
              self.joins(:contacts)
              .joins("INNER JOIN email_addresses on email_addresses.id = contacts.contact_mechanism_id
                and contacts.contact_mechanism_type = 'EmailAddress'")
              .where('contact_mechanism_type = ?', 'EmailAddress')
              .where('email_address = ?', email).readonly(false).first
            end
          end

          # Return records that match the passed Postal Address values
          # 
          # @param [Hash] postal_address_values Hash with values of postal address to search for {address_line_1: '4437 Barbados Loop'}
          # @param [ContactPurpose] [contact_purpose] Contact Purpose to filter by
          # @return [Array] Array of records with the passed Postal Address values
          #
          def find_by_postal_address(postal_address_values, contact_purpose=nil)
            if contact_purpose
              self.joins(:contacts => [:contact_purposes])
              .joins("INNER JOIN postal_addresses on postal_addresses.id = contacts.contact_mechanism_id
                and contacts.contact_mechanism_type = 'PostalAddress'")
              .where('contact_mechanism_type = ?', 'PostalAddress')
              .where('contact_purposes.internal_identifier = ?', contact_purpose)
              .where(postal_addresses: postal_address_values).readonly(false).uniq
            else
              self.joins(:contacts)
              .joins("INNER JOIN postal_addresses on postal_addresses.id = contacts.contact_mechanism_id
                and contacts.contact_mechanism_type = 'PostalAddress'")
              .where('contact_mechanism_type = ?', 'PostalAddress')
              .where(postal_addresses: postal_address_values).readonly(false).uniq
            end
          end

        end

        module InstanceMethods

          def postal_addresses
            find_all_contacts_by_contact_mechanism(PostalAddress)
          end

          def emails
            find_all_contacts_by_contact_mechanism(EmailAddress)
          end

          def phone_numbers
            find_all_contacts_by_contact_mechanism(PhoneNumber)
          end

          def has_phone_number?(phone_number)
            result = nil
            self.contacts.each do |c|
              if c.contact_mechanism_type == 'PhoneNumber'
                if c.contact_mechanism.phone_number == phone_number
                  result = true
                end
              end
            end
            result
          end

          def has_zip_code?(zip)
            result = nil
            self.contacts.each do |c|
              if c.contact_mechanism_type == 'PostalAddress'
                if c.contact_mechanism.zip == zip
                  result = true
                end
              end
            end
            result
          end

          # Check if record has contact with purpose
          #
          # @param contact_mechanism_klass [Class] the contact mechanism class (Email, PhoneNumber, PostalAddress)
          #  the passed contact purposes)
          #
          # @return result [Boolean] True if record has contact false if not
          def has_contact?(contact_mechanism_klass, contact_purpose)
            !contact_mechanisms_to_hash(contact_mechanism_klass, [contact_purpose]).empty?
          end

          # Converts PhoneNumber contact mechanisms related to this record to an array of hashes
          # containing the contact records data
          #
          # @param contact_purposes [Array] an array of contact purposes to filter by (only return contacts with
          #  the passed contact purposes)
          #
          # @return contact_mechanisms_data [Array] an Array of hashes containing contact data
          def phone_numbers_to_hash(contact_purposes=nil)
            contact_mechanisms_to_hash(PhoneNumber, contact_purposes)
          end

          # Converts EmailAddress contact mechanisms related to this record to an array of hashes
          # containing the contact records data
          #
          # @param contact_purposes [Array] an array of contact purposes to filter by (only return contacts with
          #  the passed contact purposes)
          #
          # @return contact_mechanisms_data [Array] an Array of hashes containing contact data
          def email_addresses_to_hash(contact_purposes=nil)
            contact_mechanisms_to_hash(EmailAddress, contact_purposes)
          end

          # Converts PostalAddress contact mechanisms related to this record to an array of hashes
          # containing the contact records data
          #
          # @param contact_purposes [Array] an array of contact purposes to filter by (only return contacts with
          #  the passed contact purposes)
          #
          # @return contact_mechanisms_data [Array] an Array of hashes containing contact data
          def postal_addresses_to_hash(contact_purposes=nil)
            contact_mechanisms_to_hash(PostalAddress, contact_purposes)
          end

          # Converts contact mechanisms related to this record to an array of hashes
          # containing the contact records data
          #
          # @param contact_mechanism_klass [Class] the contact mechanism class (Email, PhoneNumber, PostalAddress)
          # @param contact_purposes [Array] an array of contact purposes to filter by (only return contacts with
          #  the passed contact purposes)
          #
          # @return contact_mechanisms_data [Array] an Array of hashes containing contact data
          def contact_mechanisms_to_hash(contact_mechanism_klass, contact_purposes=nil)
            contact_mechanisms_data = []

            # if the passed contact purpose is a string convert to an Array
            if contact_purposes && contact_purposes.is_a?(String)
              contact_purposes = [contact_purposes]
            end

            if contact_purposes
              contact_purposes.each do |contact_purpose|
                contact_mechanisms = find_contact_mechanisms_with_purpose(contact_mechanism_klass, contact_purpose)

                unless contact_mechanisms.empty?
                  contact_mechanisms.collect do |item|
                    data = item.to_data_hash
                    data[:contact_purpose] = contact_purpose

                    contact_mechanisms_data.push(data)
                  end
                end
              end
            else
              contact_mechanisms = find_all_contacts_by_contact_mechanism(contact_mechanism_klass)
              contact_mechanisms.each do |contact_mechanism|
                data = contact_mechanism.to_data_hash
                data[:contact_purpose] = contact_mechanism.contact.contact_purposes.first.internal_identifier

                contact_mechanisms_data.push(data)
              end
            end

            contact_mechanisms_data
          end

          def primary_phone_number
            contact_mechanism = nil

            contact = self.get_primary_contact(PhoneNumber)
            contact_mechanism = contact.contact_mechanism unless contact.nil?

            contact_mechanism
          end

          alias primary_phone primary_phone_number

          def primary_phone_number=(phone_number)
            self.set_primary_contact(PhoneNumber, phone_number)
          end

          alias primary_phone= primary_phone_number=

          def primary_email_address
            contact_mechanism = nil

            contact = self.get_primary_contact(EmailAddress)
            contact_mechanism = contact.contact_mechanism unless contact.nil?

            contact_mechanism
          end

          alias primary_email primary_email_address

          def primary_email_address=(email_address)
            self.set_primary_contact(EmailAddress, email_address)
          end

          alias primary_email= primary_email_address=

          def primary_postal_address
            contact_mechanism = nil

            contact = self.get_primary_contact(PostalAddress)
            contact_mechanism = contact.contact_mechanism unless contact.nil?

            contact_mechanism
          end

          alias primary_address primary_postal_address

          def primary_postal_address=(postal_address)
            self.set_primary_contact(PostalAddress, postal_address)
          end

          alias primary_address= primary_postal_address=

          def set_primary_contact(contact_mechanism_class, contact_mechanism_instance)
            # set is_primary to false for any current primary contacts of this type
            primary_contact_mechanism = get_primary_contact(contact_mechanism_class)
            if primary_contact_mechanism
              primary_contact_mechanism.is_primary = false
              primary_contact_mechanism.save!
            end

            contact_mechanism_instance.is_primary = true
            contact_mechanism_instance.save!

            contact_mechanism_instance
          end

          def get_primary_contact(contact_mechanism_class)
            table_name = contact_mechanism_class.name.tableize

            self.contacts.joins("inner join #{table_name} on #{table_name}.id = contact_mechanism_id and contact_mechanism_type = '#{contact_mechanism_class.name}'")
            .where('contacts.is_primary = ?', true).readonly(false).first
          end

          # find first contact mechanism with purpose
          def find_contact_mechanism_with_purpose(contact_mechanism_class, contact_purpose)
            contact = self.find_contact_with_purpose(contact_mechanism_class, contact_purpose)

            contact.contact_mechanism unless contact.nil?
          end

          # find all contact mechanisms with purpose
          def find_contact_mechanisms_with_purpose(contact_mechanism_class, contact_purpose)
            contacts = self.find_contacts_with_purpose(contact_mechanism_class, contact_purpose)

            contacts.empty? ? [] : contacts.collect(&:contact_mechanism)
          end

          # find first contact with purpose
          def find_contact_with_purpose(contact_mechanism_class, contact_purpose)
            #if a symbol or string was passed get the model
            unless contact_purpose.is_a? ContactPurpose
              contact_purpose = ContactPurpose.find_by_internal_identifier(contact_purpose.to_s)
            end

            self.find_contact(contact_mechanism_class, nil, [contact_purpose])
          end

          def has_contact_with_purpose?(contact_mechanism_class, contact_purpose)
            !find_contact_with_purpose(contact_mechanism_class, contact_purpose).nil?
          end

          # find all contacts with purpose
          def find_contacts_with_purpose(contact_mechanism_class, contact_purpose)
            #if a symbol or string was passed get the model
            unless contact_purpose.is_a? ContactPurpose
              contact_purpose = ContactPurpose.find_by_internal_identifier(contact_purpose.to_s)
            end

            self.find_contacts(contact_mechanism_class, nil, [contact_purpose])
          end

          # find all contacts by contact mechanism
          def find_all_contacts_by_contact_mechanism(contact_mechanism_class)
            table_name = contact_mechanism_class.name.tableize

            contacts = self.contacts.joins("inner join #{table_name} on #{table_name}.id = contact_mechanism_id and contact_mechanism_type = '#{contact_mechanism_class.name}'")

            contacts.collect(&:contact_mechanism)
          end

          # find first contact
          def find_contact(contact_mechanism_class, contact_mechanism_args={}, contact_purposes=[])
            find_contacts(contact_mechanism_class, contact_mechanism_args, contact_purposes).first
          end

          # find all contacts
          def find_contacts(contact_mechanism_class, contact_mechanism_args={}, contact_purposes=[])
            table_name = contact_mechanism_class.name.tableize

            query = self.contacts.joins("inner join #{table_name} on #{table_name}.id = contact_mechanism_id and contact_mechanism_type = '#{contact_mechanism_class.name}'
                                   inner join contact_purposes_contacts on contact_purposes_contacts.contact_id = contacts.id
                                   and contact_purposes_contacts.contact_purpose_id in (#{contact_purposes.collect { |item| item.attributes["id"] }.join(',')})")

            contact_mechanism_args.each do |key, value|
              next if key == 'updated_at' or key == 'created_at' or key == 'id' or key == 'is_primary'
              query = query.where("#{table_name}.#{key} = ?", value) unless value.nil?
            end unless contact_mechanism_args.nil?

            query
          end

          # Adds contact
          def add_contact(contact_mechanism_class, contact_mechanism_args={}, contact_purposes=[])
            is_primary = contact_mechanism_args['is_primary']
            contact_purposes = [contact_purposes] if !contact_purposes.kind_of?(Array) # gracefully handle a single purpose not in an array

            contact_mechanism_args.delete_if { |k, v| ['created_at', 'updated_at', 'is_primary'].include? k.to_s }
            contact_mechanism = contact_mechanism_class.new(contact_mechanism_args)
            contact_mechanism.contact.contact_record = self
            contact_purposes.each do |contact_purpose|
              if contact_purpose.is_a?(String)
                contact_mechanism.contact.contact_purposes << ContactPurpose.iid(contact_purpose)
              else
                contact_mechanism.contact.contact_purposes << contact_purpose
              end
            end
            contact_mechanism.contact.save!
            contact_mechanism.save!

            set_primary_contact(contact_mechanism_class, contact_mechanism) if is_primary

            contact_mechanism
          end

          # tries to update contact by purpose
          # if contact doesn't exist, it adds it
          def update_or_add_contact_with_purpose(contact_mechanism_class, contact_purpose, contact_mechanism_args)
            contact_mechanism = update_contact_with_purpose(contact_mechanism_class, contact_purpose, contact_mechanism_args)

            unless contact_mechanism
              contact_mechanism = add_contact(contact_mechanism_class, contact_mechanism_args, [contact_purpose])
            end

            contact_mechanism
          end

          # looks for a contact matching on purpose
          # if it exists, it updates it, if not returns false
          def update_contact_with_purpose(contact_mechanism_class, contact_purpose, contact_mechanism_args)
            contact = find_contact_with_purpose(contact_mechanism_class, contact_purpose)
            contact.nil? ? false : update_contact(contact_mechanism_class, contact, contact_mechanism_args)
          end

          def update_contact(contact_mechanism_class, contact, contact_mechanism_args)
            set_primary_contact(contact_mechanism_class, contact.contact_mechanism) if contact_mechanism_args[:is_primary] == true

            contact_mechanism_args.delete_if { |k, v| ['client_utc_offset'].include? k.to_s }
            contact.contact_mechanism.update_attributes!(contact_mechanism_args)

            contact.contact_mechanism
          end

          #
          # Builds methods based on contacts and contact purposes associated to this record
          # For example if there is a PhoneNumber with a contact purpose of Home associated it would
          # create a method like home_phone_number
          #
          def build_contact_methods
            self.contacts.each do |contact|
              contact.contact_purposes.each do |contact_purpose|
                klass = contact.contact_mechanism.class.name

                self.class.send 'define_method', "#{contact_purpose.internal_identifier}_#{contact.contact_mechanism.class.name.underscore}" do
                  _klass_const = klass.camelize.constantize
                  _contact_purpose = contact_purpose
                  find_contact_mechanism_with_purpose(_klass_const, _contact_purpose)
                end

              end

            end
          end # build_contact_methods

        end

      end # HasContacts
    end # ActiveRecord
  end # Extensions
end # ErpBaseErpSvcs
