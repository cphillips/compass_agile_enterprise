class PostalAddressObserver < ActiveRecord::Observer
 def after_save(postal_address)
   begin
     #Rescued because callbacks on postal address create has a contact but
     #may not have a party yet
     PartySearchFact.update_search_fact(postal_address.contact.party)
   rescue
   end
 end

 def after_destroy(postal_address)
   begin
     party = Party.find(postal_address.contact.party.id)
     #Rescued because callbacks on postal address create has a contact but
     #may not have a party yet
     PartySearchFact.update_search_fact(party)
   rescue
   end
 end
end