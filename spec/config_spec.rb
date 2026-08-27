# frozen_string_literal: true

require 'spec_helper'

module Payday

  describe Config do
    before { described_class.default.reset }

    # The default logo used to point into spec/assets, which only resolved because the gemspec
    # shipped the spec suite. Anything the defaults reference has to live under lib.
    it 'defaults to a logo that ships with the gem' do
      expect(File.exist?(described_class.default.invoice_logo)).to be true
    end

    it 'keeps the default logo under lib, where the packaged gem can reach it' do
      expect(described_class.default.invoice_logo).to include('/lib/payday/assets/')
    end

    it 'defaults to a page size the template understands' do
      expect(described_class.default.page_size).to eq('LETTER')
    end
  end

end
