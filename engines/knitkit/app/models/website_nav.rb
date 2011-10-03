class WebsiteNav < ActiveRecord::Base
  belongs_to :website
  
  has_many :website_nav_items, :dependent => :destroy do
    def positioned
      find(:all, :conditions => 'parent_id is null', :order => 'position')
    end
  end
  
  def all_menu_items
    self.website_nav_items.collect{|item| item.self_and_descendants}.flatten
  end

  alias :items :website_nav_items
end
