class CreateStreetCafe < ActiveRecord::Migration[5.0]
  def change
    create_table :street_cafes do |t|
      t.string :name
      t.string :street_address
      t.string :post_code
      t.integer :num_chairs
    end
  end
end
