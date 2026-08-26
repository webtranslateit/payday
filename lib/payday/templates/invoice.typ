// Payday's invoice layout.
//
// All data arrives as JSON through sys.inputs, where Typst inserts string values as literal
// text rather than markup. Never interpolate invoice data into this file's source, and never
// call eval() on a value that came from an invoice.

#let d = json(bytes(sys.inputs.invoice))

// Prawn page-size names mapped onto Typst paper names.
#let papers = ("LETTER": "us-letter", "A4": "a4", "LEGAL": "us-legal")

#set document(title: "Invoice", date: none)
#set page(
  paper: papers.at(d.page_size, default: "a4"),
  margin: 2cm,
  numbering: none,
)
#set text(font: "Noto Sans", size: 10pt)

// Renders the styled runs produced by Payday::Markup.
#let render-runs(runs) = {
  if runs == none { return }
  for r in runs {
    let body = text(
      size: if "size" in r { r.size * 1pt } else { 1em },
      fill: if "color" in r { rgb(r.color) } else { black },
      weight: if r.at("bold", default: false) { "bold" } else { "regular" },
      style: if r.at("italic", default: false) { "italic" } else { "normal" },
      r.text,
    )
    if "link" in r { link(r.link, body) } else { body }
  }
}

// --- logo and company identity ---------------------------------------------------
#grid(
  columns: (1fr, auto),
  align: (left + top, right + top),
  if d.logo != none {
    image(
      d.logo.name,
      width: if d.logo.width != none { d.logo.width * 1pt } else { auto },
      height: if d.logo.height != none { d.logo.height * 1pt } else { auto },
      fit: "contain",
    )
  },
  [
    #text(weight: "bold", size: 12pt)[#d.company_name] \
    #d.company_details
  ],
)

// --- status stamp -----------------------------------------------------------------
#if d.stamp != none {
  place(center, dy: -30pt, rotate(15deg,
    text(fill: rgb("cc0000"), size: 25pt, weight: "bold")[#d.stamp]))
}

#v(20pt)

// --- bill to / ship to -------------------------------------------------------------
#grid(
  columns: (1fr, auto),
  align: (left + top, right + top),
  [#text(weight: "bold")[#d.labels.bill_to] \ #d.bill_to],
  if d.ship_to != none [#text(weight: "bold")[#d.labels.ship_to] \ #d.ship_to],
)

#v(20pt)

// --- invoice details ---------------------------------------------------------------
#if d.details.len() > 0 {
  table(
    columns: 2,
    stroke: none,
    inset: (x: 0pt, y: 1pt),
    column-gutter: 10pt,
    align: (left, right),
    ..d.details.map(row => (
      text(weight: "bold")[#row.at(0)],
      text(weight: "bold")[#row.at(1)],
    )).flatten()
  )
}

#v(20pt)

// --- line items ---------------------------------------------------------------------
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  inset: (x: 10pt, y: 5pt),
  stroke: (x, y) => (
    left: none,
    right: none,
    top: 0.5pt + rgb("F6F9FC"),
    bottom: 0.5pt + rgb("BCC6D0"),
  ),
  fill: (x, y) => if y == 0 { white } else if calc.odd(y) { rgb("F6F9FC") } else { white },
  table.header(
    text(weight: "bold")[#d.labels.description],
    text(weight: "bold")[#d.labels.unit_price],
    text(weight: "bold")[#d.labels.quantity],
    text(weight: "bold")[#d.labels.amount],
  ),
  ..d.line_items.map(li => (
    render-runs(li.description), [#li.price], [#li.quantity], [#li.amount],
  )).flatten()
)

#v(10pt)

// --- totals ---------------------------------------------------------------------------
#align(right, table(
  columns: 2,
  stroke: none,
  inset: (x: 4pt, y: 2pt),
  align: (left, right),
  ..d.totals.map(row => {
    let size = if row.at(2) { 12pt } else { 10pt }
    (text(weight: "bold", size: size)[#row.at(0)], text(size: size)[#row.at(1)])
  }).flatten()
))

// --- notes ------------------------------------------------------------------------------
#if d.notes != none {
  v(30pt)
  text(weight: "bold")[#d.labels.notes]
  v(3pt)
  line(length: 100%, stroke: 0.5pt + rgb("cccccc"))
  v(10pt)
  render-runs(d.notes)
}

// --- QR code ------------------------------------------------------------------------------
#if d.qr_code != none {
  v(10pt)
  image("qr.png", width: 100pt)
}

// --- page numbers, only when the invoice runs to more than one page -------------------------
#context if counter(page).final().first() > 1 {
  set page(numbering: "1 / 1")
}
