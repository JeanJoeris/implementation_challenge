1) This requires Postgres (9.4+) & Rails(4.2+), so if you don't already have both installed, please install them.

2) Surf over to https://datahub.io/dataset/street-cafes-licences-in-leeds, and upload the data there into a table called street_cafes in Postgres (remove the headers and name them yourself).

I chose to initially create a table and import the data via rails, as I thought this would make the later tasks easier. I'm happy to provide what I did in rails or equivalent raw sql. I created a migration with new names and imported the data through the rails seed file. However, I could have done the same in raw sql via CREATE TABLE and COPY.

3) Add a varchar column to the table called 'category'.

I did this via a migration to add a column, `rails g migration add_category_to_street_cafe category`, and this could have been done in sql with `ALTER TABLE street_cafes ADD category VARCHAR;`

4) Create a view with the following columns[provide the view SQL]

* post_code: The Post Code
* total_places: The number of places in that Post Code
* total_chairs: The total number of chairs in that Post Code
* chairs_pct: Out of all the chairs at all the Post Codes, what percentage does this Post Code represent (should sum to 100% in the whole view)
* place_with_max_chairs: The name of the place with the most chairs in that Post Code
* max_chairs: The number of chairs at the place_with_max_chairs

```
CREATE VIEW cafe_data
AS
  WITH chairs
       AS (SELECT SUM(num_chairs) total
           FROM   street_cafes),
       biggest_cafes
       AS (SELECT DISTINCT ON (post_code) name,
                                          post_code
           FROM   street_cafes
           ORDER  BY post_code,
                     num_chairs DESC)
  SELECT street_cafes.post_code,
         Count(*)                                          AS total_places,
         SUM(street_cafes.num_chairs)                      AS total_chairs,
         SUM(street_cafes.num_chairs + 0.0) / chairs.total AS chairs_pct,
         biggest_cafes.name                                AS
         place_with_max_chairs,
         Max(street_cafes.num_chairs)                      AS max_chairs
  FROM   chairs,
         street_cafes
         INNER JOIN biggest_cafes
                 ON street_cafes.post_code = biggest_cafes.post_code
  GROUP  BY biggest_cafes.name,
            street_cafes.post_code,
            chairs.total;
```

I built this query starting with just post code, total places and total chairs, which was fairly easy built by grouping on post code.

For chairs percentage, I realized I had to have the total number of chairs already calculated to calculate the percentage. I'm not especially happy with the solution I found (particularly grouping by chairs.total at the end), and I feel like there might be an simpler/faster solution. The addition of 0.0 to the number of chairs was to make sure float, not integer, division was performed. I could have also done this with casing to float.

The max chairs per post code could be found from the post code grouped table. However I couldn't figure out how to also get the name where this number of chairs occurred. The solution I ended up deciding on was creating biggest_cafes where the name of the biggest cafe was already associated with the post code. I then joined the tables on post code.

I'm not sure how to best generate this view, but selecting from the same table 3 times feels inefficient.

5) Write a Rails script to categorize the cafes and write the result to the category according to the rules:[provide the script]

  * If the Post Code is of the LS1 prefix type:
    * number of chairs less than 10: category = 'ls1 small'
    * number of chairs greater than or equal to 10, less than 100: category = 'ls1 medium'
    * number of chairs greater than or equal to 100: category = 'ls1 large'
  * If the Post Code is of the LS2 prefix type:
    * number of chairs below the 50th percentile for ls2: category = 'ls2 small'
    * number of chairs above the 50th percentile for ls2: category = 'ls2 large'
  * For Post Code is something else:
    * category = 'other'

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
      "ls1 small"
    elsif num_chairs < 100
      "ls1 medium"
    else
      "ls1 large"
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
    ls2_locations = StreetCafe.where("post_code LIKE 'LS2%'").order(num_chairs: :desc)
    ls2_locations.to_a[ls2_locations.count/2].num_chairs
  end

  def post_code_prefix(post_code)
    post_code.split(" ").first
  end
end
```
This is run via the following rake task
```
namespace :cafes do
  task :categorize_cafes => :environment do
    categorizer = Categorizer.new(StreetCafe.all)
    categorizer.categorize_cafes
  end
end
```

Rake tasks seemed like a natural way to execute this script, but the logic seemed complex enough it warranted a separate class. I thought the class should have a narrow public interface - giving the object data and having it categorize data.

For each cafe, I found its postal code prefix. Based on this prefix I used the appropriate method to find the cafe category. These methods only take number of chairs as this is all that is needed to categorize a cafe given its postal code prefix.

For categorizing cafes in LS2 post codes, I needed the 50th percentile of number of chairs. I found the median number of chairs by sorting by chair number and grabbing middle element. This gave me the number of chairs that has an equal number of data points above and below.

By the end I felt the script was large enough it could have been refactored into a few smaller classes. I ended up leaving it in once class as the request for "a Rails script" made me think there should be one file.

6) Write a custom view to aggregate the categories [provide view SQL AND the results of this view]
    category: The category column
    total_places: The number of places in that category
    total_chairs: The total chairs in that category

```
CREATE VIEW category_aggregates
AS
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
```

Having already added categories to the cafes, I could group by category. From there, totals per category were straight forward

7) Write a script in rails to:

  * For street_cafes categorized as small, write a script that exports their data to a csv and deletes the records

  * For street cafes categorized as medium or large, write a script that concatenates the category name to the beginning of the name and writes it back to the name column


```
namespace :cafes do
  task :process_small_cafes => :environment do
    require 'csv'

    small_cafes = StreetCafe.where("category like '%small'")
    timestamp = Time.now.strftime("%Y-%M-%d")
    CSV.open("./data/small_cafes_#{timestamp}.csv", 'w') do |csv|
      csv << small_cafes.attribute_names
      small_cafes.each do |cafe|
        csv << cafe.attributes.values
        cafe.destroy
      end
    end
  end

  task :process_larger_cafes => :environment do
    larger_cafes = StreetCafe.StreetCafe.where("category LIKE '%large' OR category LIKE '%medium'")
    larger_cafes.map do |cafe|
      cafe.update(name: "#{cafe.category}: #{cafe.name}")
    end
  end
end
```

As with the other rails script, rake tasks felt like a natural place. This time, however, the logic felt simple enough that the logic could live in the task.

In both tasks, I query to find the cafes of the appropriate size, and then iterate over them performing the logic. I chose to timestamp the csv to be closer to initial csv, and to avoid issues of overwriting a old file. I left the database primary key in the csv as I thought it might be helpful if someone later wanted to use that csv to consult the database. It could be removed by specifying which attributes to shovel into the csv.
