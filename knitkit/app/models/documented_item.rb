class DocumentedItem < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  belongs_to :online_document_section

  before_destroy :destroy_content

  def content
    if content?
      Content.find(documented_content_id)
    elsif klass?
      self.documented_klass
    end
  end
  
  def published_content(active_publication)
    if content?
      DocumentedContent.find_published_by_section(active_publication, online_document_section)
    elsif klass?
      self.documented_klass
    end
  end

  def klass?
    !!self.documented_klass
  end
  
  def content?
    !!self.documented_content_id
  end
  
  def self.find_by_section_id( website_section_id )
    DocumentedItem.where(["online_document_section_id = ?", website_section_id]).first
  end

  private

  def destroy_content
    if content?
      Content.find(documented_content_id).destroy
    end
  end

end