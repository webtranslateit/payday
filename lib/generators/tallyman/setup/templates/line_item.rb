class <%= options.line_item_name.singularize %> < ActiveRecord::Base
  include Tallyman::LineItemable
  
  belongs_to :<%= options.invoice_name.underscore %>
end