#!/usr/bin/env python3
"""Align LaTeX table columns so & delimiters line up vertically.

Usage:
  # Align a specific line range (1-based, inclusive), in-place:
  python align_tex_table.py -f file.tex -s 528 -e 549

  # Preview without writing (dry-run):
  python align_tex_table.py -f file.tex -s 528 -e 549 -n

  # Align ALL tabular environments in a file, in-place:
  python align_tex_table.py -f file.tex -a

  # Pipe from stdin:
  cat selection.tex | python align_tex_table.py
"""

import sys, re, argparse


def _align_block(text_lines):
    """Align & in a list of lines, treating all &-lines as one table."""
    entries = []
    for raw in text_lines:
        if '&' not in raw or raw.lstrip().startswith('%'):
            entries.append(('pass', raw))
            continue
        lws = raw[: len(raw) - len(raw.lstrip())]
        # Split on unescaped & (won't split \&)
        cells = re.split(r'(?<!\\)&', raw)
        cells = [c.strip() for c in cells]
        # Extract trailing \\ (and optional \hline etc.) from last cell
        last = cells[-1]
        m = re.search(r'(\s*\\\\.*)$', last)
        trail = ''
        if m:
            cells[-1] = last[: m.start()].strip()
            trail = m.group(1).strip()
        entries.append(('table', lws, cells, trail))

    tbl = [e for e in entries if e[0] == 'table']
    if not tbl:
        return text_lines

    ncols = max(len(r[2]) for r in tbl)
    widths = [0] * ncols
    for _, _, cells, _ in tbl:
        for i, c in enumerate(cells):
            widths[i] = max(widths[i], len(c))

    common_lws = tbl[0][1]

    out = []
    for e in entries:
        if e[0] == 'pass':
            out.append(e[1])
            continue
        _, _, cells, trail = e
        parts = [c.ljust(widths[i]) for i, c in enumerate(cells)]
        line = common_lws + ' & '.join(parts)
        if trail:
            line = line.rstrip() + ' ' + trail
        out.append(line)
    return out


def align_full_file(text_lines):
    """Find every tabular-like environment and align it."""
    result = list(text_lines)
    begin_re = re.compile(r'\\begin\{(?:tabular[x*]?|longtable|array)\}')
    end_re   = re.compile(r'\\end\{(?:tabular[x*]?|longtable|array)\}')
    i = 0
    while i < len(result):
        if begin_re.search(result[i]):
            j = i + 1
            while j < len(result) and not end_re.search(result[j]):
                j += 1
            inner = result[i + 1 : j]
            aligned = _align_block(inner)
            result[i + 1 : j] = aligned
            i = j + 1
        else:
            i += 1
    return result


def main():
    ap = argparse.ArgumentParser(description='Align LaTeX table & columns')
    ap.add_argument('-f', '--file', help='TeX file path')
    ap.add_argument('-s', '--start', type=int, help='Start line (1-based, inclusive)')
    ap.add_argument('-e', '--end', type=int, help='End line (1-based, inclusive)')
    ap.add_argument('-a', '--all', action='store_true', help='Align all tables in the file')
    ap.add_argument('-n', '--dry-run', action='store_true', help='Print to stdout instead of writing')
    args = ap.parse_args()

    if args.file:
        with open(args.file) as fh:
            all_lines = fh.readlines()
        raw = [l.rstrip('\n') for l in all_lines]
        trailing_nl = all_lines[-1].endswith('\n') if all_lines else False

        if args.all:
            aligned = align_full_file(raw)
            text = '\n'.join(aligned) + ('\n' if trailing_nl else '')
            if args.dry_run:
                sys.stdout.write(text)
            else:
                with open(args.file, 'w') as fh:
                    fh.write(text)
                print(f'Aligned all tables in {args.file}', file=sys.stderr)
        else:
            s = (args.start - 1) if args.start else 0
            e = args.end if args.end else len(raw)
            aligned = _align_block(raw[s:e])
            if args.dry_run:
                print('\n'.join(aligned))
            else:
                new = raw[:s] + aligned + raw[e:]
                text = '\n'.join(new) + ('\n' if trailing_nl else '')
                with open(args.file, 'w') as fh:
                    fh.write(text)
                print(f'Aligned lines {args.start}-{args.end} in {args.file}', file=sys.stderr)
    else:
        lines = [l.rstrip('\n') for l in sys.stdin.readlines()]
        print('\n'.join(_align_block(lines)))


if __name__ == '__main__':
    main()
