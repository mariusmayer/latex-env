import argparse

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-f", "--file", required=True)
    ap.add_argument("-s", "--sel", required=True)
    args = ap.parse_args()
    s_line, s_col, e_line, e_col = map(int, args.sel.split(","))

    with open(args.file) as f:
        lines = f.readlines()

    # lines are 1-based, cols are 0-based
    s_line -= 1
    e_line -= 1

    if s_line == e_line:
        line   = lines[s_line]
        before = line[:s_col]
        middle = line[s_col:e_col]
        after  = line[e_col:]
        lines[s_line] = before + r"\hl{" + middle + "}" + after
    else:
        first_part   = lines[s_line][:s_col]
        middle_first = lines[s_line][s_col:]
        middle_last  = lines[e_line][:e_col]
        last_part    = lines[e_line][e_col:]
        middle       = middle_first + "".join(lines[s_line+1:e_line]) + middle_last
        lines[s_line:e_line+1] = [first_part + r"\hl{" + middle + "}" + last_part]

    with open(args.file, "w") as f:
        f.writelines(lines)

if __name__ == "__main__":
    main()
