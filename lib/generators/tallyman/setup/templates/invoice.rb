class <%= options.invoice_name.singularize %> < ActiveRecord::Base
  include Tallyman::Invoiceable
  
  has_many :<%= options.line_item_name.pluralize.underscore %>
end