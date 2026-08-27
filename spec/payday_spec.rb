# frozen_string_literal: true

require 'spec_helper'

describe Payday do
  # The load path has to resolve against the gem, not the working directory. When it did not,
  # requiring payday from anywhere but the gem root left I18n with no locales at all, which
  # made `I18n.t` raise InvalidLocale rather than fall back to the built-in defaults.
  describe 'translations' do
    it 'loads the locales that ship with the gem' do
      expect(I18n.t('payday.invoice.subtotal', locale: :en)).to eq('Subtotal:')
    end

    it 'loads the translated locales too' do
      expect(I18n.t('payday.line_item.quantity', locale: :es)).to eq('Cantidad')
    end

    it 'resolves the load path without depending on the working directory' do
      expect(I18n.load_path).to include(a_string_matching(%r{\A/.*/config/locales/payday\.en\.yml\z}))
    end
  end
end
