# frozen_string_literal: true

# Include this module into your line item implementation to make sure that Tallyman stays happy
# with it, or just make sure that your line item implements the amount method.
module Tallyman

  module LineItemable

    # Returns the total amount for this {LineItemable}, or +price * quantity+
    def amount
      return predefined_amount if predefined_amount

      price * quantity
    end

  end

end
