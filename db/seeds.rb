require 'CSV'
CSV.foreach("./data/street_cafes_2015-16.csv", {headers: true}) do |row|
  StreetCafe.create(name: row["Caf�/Restaurant Name"], street_address: row["Street Address"], post_code: row["Post Code"], num_chairs: row["Number of Chairs"])
end
