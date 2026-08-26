# frozen_string_literal: true

require 'rqrcode'

module Payday

  # Draws a QR code as an SVG.
  #
  # The matrix comes straight from RQRCode, so the payload and its error correction level are
  # untouched and the code carries exactly the same data it always did. Only the drawing
  # changes: vector instead of a 200px raster, lightly rounded modules, and the three finder
  # patterns drawn as rounded frames.
  #
  # Rounding is kept deliberately slight. These codes are scanned off paper, sometimes off a
  # bad photocopy, and on a Verifactu invoice a code that will not scan is a compliance
  # problem rather than a cosmetic one. Modules keep their full square footprint apart from a
  # softened corner, so a scanner sees the same geometry the old raster produced.
  class QrCode

    QUIET_ZONE = 4    # modules of clear space; the QR spec's minimum
    UNIT = 10         # user units per module
    RADIUS = 1.5      # corner radius of a data module, out of UNIT
    FINDER = 7        # finder patterns are 7 modules square
    # Corner radius of a finder frame. Above roughly 1.2 modules the curve starts cutting the
    # corner module out of the ring, which changes what a scanner reads.
    EYE_RADIUS = 10
    DARK = '#111111'
    LIGHT = '#ffffff'

    def initialize(data)
      @modules = RQRCode::QRCode.new(data.to_s).modules
    end

    def to_svg
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{side} #{side}" shape-rendering="geometricPrecision">
        <rect width="#{side}" height="#{side}" fill="#{LIGHT}"/>
        #{(data_modules + finders).join("\n")}
        </svg>
      SVG
    end

    private

    def size
      @modules.length
    end

    def side
      (size + (QUIET_ZONE * 2)) * UNIT
    end

    def data_modules
      @modules.each_with_index.flat_map do |cells, row|
        cells.each_with_index.filter_map do |dark, col|
          module_rect(row, col) if dark && !finder?(row, col)
        end
      end
    end

    def module_rect(row, col)
      %(<rect class="m" x="#{x(col)}" y="#{x(row)}" width="#{UNIT}" height="#{UNIT}" ) +
        %(rx="#{RADIUS}" fill="#{DARK}"/>)
    end

    # A finder is a 7x7 ring with a 3x3 centre. Drawing it as two rounded rects rather than 33
    # separate modules is what gives the code its softer corners.
    def finders
      finder_origins.flat_map { |row, col| [ring(row, col), pupil(row, col)] }
    end

    def ring(row, col)
      %(<rect class="f" x="#{x(col) + (UNIT / 2)}" y="#{x(row) + (UNIT / 2)}" ) +
        %(width="#{UNIT * 6}" height="#{UNIT * 6}" rx="#{EYE_RADIUS}" ) +
        %(fill="none" stroke="#{DARK}" stroke-width="#{UNIT}"/>)
    end

    def pupil(row, col)
      %(<rect class="p" x="#{x(col + 2)}" y="#{x(row + 2)}" ) +
        %(width="#{UNIT * 3}" height="#{UNIT * 3}" rx="#{UNIT}" fill="#{DARK}"/>)
    end

    def finder_origins
      [[0, 0], [0, size - FINDER], [size - FINDER, 0]]
    end

    def finder?(row, col)
      finder_origins.any? do |r, c|
        row.between?(r, r + FINDER - 1) && col.between?(c, c + FINDER - 1)
      end
    end

    def x(index)
      (index + QUIET_ZONE) * UNIT
    end

  end

end
