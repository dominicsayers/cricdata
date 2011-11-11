class Search
  include Mongoid::Document
  field :occasion, :type => Time
  field :maxpage, :type => Integer
  field :games, :type => Array
end
