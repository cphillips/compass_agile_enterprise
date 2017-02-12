Category.class_eval do

  # Count of ProductTypes classified by this category
  #
  def product_type_count(context={})
    statement = CategoryClassification.joins("inner join product_types on product_types.id = category_classifications.classification_id
                                             and category_classifications.classification_type = 'ProductType'")
    .where(category_id: self.id)

    if context[:only_available_on_web]
      statement = statement.where(product_types: {available_on_web: true})
    end

    statement.count('category_classifications.id')
  end

end

module ErpProducts
  module Extensions

    module CategoryExtension

      def to_data_hash(context={})
        data = super(context)

        data[:product_type_count] = product_type_count

        data
      end

    end

  end
end

Category.class_eval do
  prepend ErpProducts::Extensions::CategoryExtension
end