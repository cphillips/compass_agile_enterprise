ProductType.class_eval do
  has_many :inventory_entries, dependent: :destroy
end
