class AddCategoryToStreetCafe < ActiveRecord::Migration[5.0]
  def change
    add_column :street_cafes, :category, :string
  end
end
