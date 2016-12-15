Create a view with the following columns[provide the view SQL]

```
WITH chairs
     AS (SELECT SUM(num_chairs) total
         FROM   street_cafes),
     biggest_cafes
     AS (SELECT DISTINCT ON (post_code) name,
                                        post_code,
                                        num_chairs
         FROM   street_cafes
         ORDER  BY post_code,
                   num_chairs DESC)
SELECT street_cafes.post_code,
       Count(*)                                          AS total_places,
       SUM(street_cafes.num_chairs)                      AS total_chairs,
       SUM(street_cafes.num_chairs + 0.0) / chairs.total AS chairs_pct,
       biggest_cafes.name                                AS place_with_max_chairs,
       Max(street_cafes.num_chairs)                      AS max_chairs
FROM   chairs,
       street_cafes
       inner join biggest_cafes
               ON street_cafes.post_code = biggest_cafes.post_code
GROUP  BY biggest_cafes.name,
          street_cafes.post_code,
          chairs.total;
```
Write a Rails script to categorize the cafes and write the result to the category according to the rules:[provide the script]
```
class Categorizer
  def initialize(street_cafes)
    @street_cafes = street_cafes
  end

  def categorize_cafes
    street_cafes.map do |street_cafe|
      category = get_category(street_cafe)
      street_cafe.update(category: category)
    end
  end

  private
  attr_reader :street_cafes

  def get_category(street_cafe)
    prefix = post_code_prefix(street_cafe.post_code)
    if prefix == "LS1"
      get_ls1_category(street_cafe.num_chairs)
    elsif prefix == "LS2"
      get_ls2_category(street_cafe.num_chairs)
    else
      "other"
    end
  end

  def get_ls1_category(num_chairs)
    if num_chairs < 10
      'ls1 small'
    elsif num_chairs < 100
      'ls1 medium'
    else
      'ls1 large'
    end
  end

  def get_ls2_category(num_chairs)
    if num_chairs < median_ls2_chairs
      "ls2 small"
    else
      "ls2 large"
    end
  end

  def median_ls2_chairs
    StreetCafe.order(num_chairs: :desc).to_a[StreetCafe.count/2].num_chairs
  end

  def post_code_prefix(post_code)
    post_code.split(" ").first
  end
end
```
This is script is run via the rake task `rake cafes:categorize_cafes`
```
namespace :cafes do
  task :categorize_cafes => :environment do
    categorizer = Categorizer.new(StreetCafe.all)
    categorizer.categorize_cafes
  end
end
```


Write a custom view to aggregate the categories [provide view SQL AND the results of this view]
```
SELECT category,
       Count(*)        AS total_places,
       SUM(num_chairs) AS total_chairs
FROM   street_cafes
GROUP  BY category;

 category  | total_places | total_chairs
-----------+--------------+--------------
ls1 medium |           49 |         1223
ls2 large  |            8 |          549
ls1 small  |           11 |           64
ls2 small  |            2 |           24
ls1 large  |            1 |          152
other      |            2 |           67
(6 rows)
```

Write a script in rails to:
  * For street_cafes categorized as small, write a script that exports their data to a csv and deletes the records
    ```
    namespace :cafes do
      task :process_small_cafes => :environment do
        require 'csv'

        small_cafes = StreetCafe.where("category like '%small'")
        CSV.open('./data/small_cafes.csv', 'a') do |csv|
          csv << small_cafes.attribute_names
          small_cafes.each do |cafe|
            csv << cafe.attributes.values
            cafe.destroy
          end
        end
      end
    end
    ```
  * For street cafes categorized as medium or large, write a script that concatenates the category name to the beginning of the name and writes it back to the name column
    ```
    namespace :cafes do
      task :process_larger_cafes => :environment do
        larger_cafes = StreetCafe.where("category like '%large' OR category like '%medium'")
        larger_cafes.map do |cafe|
          new_name = "#{cafe.category}: #{cafe.name}"
          cafe.update(name: new_name)
        end
      end
    end
    ```
