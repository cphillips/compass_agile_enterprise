Party.class_eval do

  has_many :product_type_pty_roles, dependent: :destroy
  has_many :product_types, through: :product_type_pty_roles

end
