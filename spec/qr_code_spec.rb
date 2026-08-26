# frozen_string_literal: true

require 'spec_helper'

module Payday

  describe QrCode do
    let(:payload) { 'https://example.com/verify/INV-2024-001' }
    let(:svg) { described_class.new(payload).to_svg }
    let(:matrix) { RQRCode::QRCode.new(payload).modules }

    it 'produces an SVG document' do
      expect(svg).to start_with('<svg xmlns="http://www.w3.org/2000/svg"')
    end

    it 'sizes the canvas to the matrix plus a quiet zone on both sides' do
      side = (matrix.length + (QrCode::QUIET_ZONE * 2)) * QrCode::UNIT
      expect(svg).to include(%(viewBox="0 0 #{side} #{side}"))
    end

    it 'paints a light background so the code keeps its contrast on any stock' do
      expect(svg).to include(%(fill="#{QrCode::LIGHT}"))
    end

    # The three finder patterns are what a scanner locks onto first. They are drawn as frames
    # rather than as individual modules, so they are counted separately below.
    it 'draws one rounded rect per dark module outside the finder patterns' do # rubocop:todo RSpec/ExampleLength
      size = matrix.length
      finders = [[0, 0], [0, size - 7], [size - 7, 0]]
      in_finder = lambda do |row, col|
        finders.any? { |r, c| row.between?(r, r + 6) && col.between?(c, c + 6) }
      end
      expected = matrix.each_with_index.sum do |cells, row|
        cells.each_with_index.count { |dark, col| dark && !in_finder.call(row, col) }
      end

      expect(svg.scan('<rect class="m"').length).to eq(expected)
    end

    it 'draws a ring for each finder pattern' do
      expect(svg.scan('<rect class="f"').length).to eq(3)
    end

    it 'draws a pupil for each finder pattern' do
      expect(svg.scan('<rect class="p"').length).to eq(3)
    end

    # Verified by rendering the SVG and sampling every module centre: at this radius the
    # rendered code is module-for-module identical to the encoder's matrix. Grow it and the
    # finder corners start reading differently, which is a scanning risk on a document whose
    # QR code is a tax compliance artifact.
    it 'keeps the finder corner modules inside the ring' do
      radius = QrCode::EYE_RADIUS / QrCode::UNIT.to_f
      corner_centre = radius * Math.sqrt(2)

      expect(corner_centre).to be_between(radius - 0.5, radius + 0.5)
    end

    it 'is deterministic for the same payload' do
      expect(described_class.new(payload).to_svg).to eq(svg)
    end

    it 'encodes different payloads differently' do
      expect(described_class.new('https://example.com/other').to_svg).not_to eq(svg)
    end
  end

end
