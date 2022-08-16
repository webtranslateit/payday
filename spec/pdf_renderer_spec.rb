# frozen_string_literal: true

require 'spec_helper'

module Payday

  describe PdfRenderer do
    describe '.number_to_currency' do
      it 'formats numbers to currency currectly' do
        expect(described_class.number_to_currency(20, nil)).to eq('$20.00')
      end
    end
  end

end
