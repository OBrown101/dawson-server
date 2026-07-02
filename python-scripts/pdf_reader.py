#
#  pdf_reader.py
#  DAWSON
#
#  Created by Ethan Brown on 7/1/26.
#

import fitz

def read_pdf(args):
    path = args.get("path")
    start_page = args.get("start_page")
    end_page = args.get("end_page")
    max_pages = int(args.get("max_pages", 10))
    search = args.get("search")
    context_pages = int(args.get("context_pages", 0))

    include_metadata = bool(args.get("include_metadata", False))
    include_outline = bool(args.get("include_outline", False))
    include_links = bool(args.get("include_links", False))
    include_annotations = bool(args.get("include_annotations", False))
    include_forms = bool(args.get("include_forms", False))
    include_attachments = bool(args.get("include_attachments", False))
    include_page_info = bool(args.get("include_page_info", False))
    extract_tables = bool(args.get("extract_tables", False))
    list_images = bool(args.get("list_images", False))

    if not path:
        return "Error: No path provided."

    doc = fitz.open(path)
    total_pages = len(doc)

    pages_to_read = _pages_to_read(
        doc=doc,
        total_pages=total_pages,
        start_page=start_page,
        end_page=end_page,
        max_pages=max_pages,
        search=search,
        context_pages=context_pages
    )

    if not pages_to_read:
        return f"No pages matched. PDF has {total_pages} pages."

    parts = [
        f"PDF: {path}",
        f"Pages: {total_pages}",
        f"Showing pages: {min(pages_to_read)}-{max(pages_to_read)}",
        ""
    ]

    if include_metadata:
        parts.append("--- Metadata ---")
        for key, value in doc.metadata.items():
            if value:
                parts.append(f"{key}: {value}")
        parts.append("")

    if include_outline:
        parts.append("--- Outline ---")
        outline = doc.get_toc()
        if outline:
            for level, title, page in outline:
                indent = "  " * max(0, level - 1)
                parts.append(f"{indent}- {title} (page {page})")
        else:
            parts.append("[No outline found]")
        parts.append("")

    if include_forms:
        parts.append("--- Forms ---")
        found_forms = False
        for page_index in range(total_pages):
            for widget in doc[page_index].widgets() or []:
                found_forms = True
                parts.append(f"Page {page_index + 1}: {widget.field_name}: {widget.field_value}")
        if not found_forms:
            parts.append("[No form fields found]")
        parts.append("")

    if include_attachments:
        parts.append("--- Attachments ---")
        names = doc.embfile_names()
        if names:
            for name in names:
                info = doc.embfile_info(name)
                parts.append(f"{name} ({info.get('size', 0)} bytes)")
        else:
            parts.append("[No attachments found]")
        parts.append("")

    for page_number in pages_to_read:
        page = doc[page_number - 1]
        text = page.get_text("text").strip()

        parts.append(f"--- Page {page_number} ---")

        if include_page_info:
            rect = page.rect
            parts.append(f"Size: {rect.width:g} x {rect.height:g}")
            parts.append(f"Rotation: {page.rotation}")
            parts.append("")

        parts.append(text if text else "[No extractable text found on this page]")
        parts.append("")

        if search:
            matches = page.search_for(search)
            if matches:
                parts.append(f"Search matches for \"{search}\": {len(matches)}")
                parts.append("")

        if include_links:
            links = page.get_links()
            if links:
                parts.append("Links:")
                for link in links:
                    uri = link.get("uri")
                    target_page = link.get("page")
                    if uri:
                        parts.append(f"- {uri}")
                    elif target_page is not None:
                        parts.append(f"- Internal link to page {target_page + 1}")
                parts.append("")

        if include_annotations:
            annotations = list(page.annots() or [])
            if annotations:
                parts.append("Annotations:")
                for annot in annotations:
                    info = annot.info or {}
                    content = info.get("content", "")
                    title = info.get("title", "")
                    parts.append(f"- {annot.type[1]}: {title} {content}".strip())
                parts.append("")

        if extract_tables:
            try:
                tables = page.find_tables()
                if tables and tables.tables:
                    parts.append("Tables:")
                    for table_index, table in enumerate(tables.tables, start=1):
                        rows = table.extract()
                        parts.append(f"Table {table_index}:")
                        parts.append(_markdown_table(rows))
                        parts.append("")
            except Exception as error:
                parts.append(f"Tables: Error extracting tables: {error}")
                parts.append("")

        if list_images:
            images = page.get_images(full=True)
            if images:
                parts.append("Images:")
                for image_index, image in enumerate(images, start=1):
                    xref = image[0]
                    width = image[2]
                    height = image[3]
                    colorspace = image[5]
                    parts.append(f"- Image {image_index}: xref={xref}, {width}x{height}, colorspace={colorspace}")
                parts.append("")

    return "\n".join(parts)


def _pages_to_read(doc, total_pages, start_page, end_page, max_pages, search, context_pages):
    if search:
        pages = set()

        for page_index in range(total_pages):
            page = doc[page_index]
            if page.search_for(search):
                start = max(1, page_index + 1 - context_pages)
                end = min(total_pages, page_index + 1 + context_pages)

                for page_number in range(start, end + 1):
                    pages.add(page_number)

        return sorted(pages)

    start = max(1, int(start_page or 1))
    end = int(end_page or min(total_pages, start + max_pages - 1))
    end = min(end, total_pages)

    if start > end or start > total_pages:
        return []

    return list(range(start, end + 1))


def _markdown_table(rows):
    if not rows:
        return "[Empty table]"

    cleaned_rows = [
        ["" if cell is None else str(cell).replace("\n", " ").strip() for cell in row]
        for row in rows
    ]

    header = cleaned_rows[0]
    body = cleaned_rows[1:]

    lines = [
        "| " + " | ".join(header) + " |",
        "| " + " | ".join(["---"] * len(header)) + " |"
    ]

    for row in body:
        while len(row) < len(header):
            row.append("")
        lines.append("| " + " | ".join(row[:len(header)]) + " |")

    return "\n".join(lines)
