import re
import json

from pathlib import Path
from datetime import datetime

ID_FN = None
# TS_FN = lambda x: datetime.strptime(x, TIMESTAMP_FORMAT)
TS_FN = ID_FN

INTERVAL_TITLE_REGEX = r"(\d{2}:\d{2}:\d{2}) Report # (\d+), Interval (\d+)"
INTERVAL_TITLE_OUT = [("timestamp", TS_FN), ("report_num", int), ("interval", int)]
INTERVAL_ELEMENT_REGEX = r"\s+-([^:]+): ([\d.]+)"
INTERVAL_ELEMENT_OUT = [("class", ID_FN), ("score", float)]

REPORT_TITLE_REGEX = r"(\d{2}:\d{2}:\d{2}) Results for report # (\d+)"
REPORT_TITLE_OUT = [("timestamp", TS_FN), ("report_num", int)]
REPORT_ELEMENT_REGEX = r"\s+\d\. Label: ([\w -]+), Depth: ([\d.]+) m, Score: ([\d.]+)"
REPORT_ELEMENT_OUT = [("class", ID_FN), ("depth", float), ("score", float)]

TIMESTAMP_FORMAT = "%H:%M:%S"

REPORT_TIME_IDX_START = 17
REPORT_TIME_IDX_END = REPORT_TIME_IDX_START + 8
REPORT_FNAME_FN = lambda t: f"ClarifEye-Report-{t}.txt"
PER_INTERVAL_FNAME_FN = lambda t: f"ClarifEye-PerInterval-{t}.txt"


def load_files(folder: Path, t):
    per_interval, report = open(folder / PER_INTERVAL_FNAME_FN(t)), open(folder / REPORT_FNAME_FN(t))
    text_per_interval, text_report = per_interval.read(), report.read()
    per_interval.close(), report.close()
    return text_per_interval.splitlines()[1:], text_report.splitlines()[1:]


def parse(lines: list, title_regex, title_out, element_regex, element_out):
    ret = None 
    for l in lines:
        if l[0] != "\t":
            if ret is not None:
                yield ret
            ret = {
                k: (v if fn is None else fn(v))
                for (k, fn), v in zip(title_out, re.findall(title_regex, l)[0])
            }
            ret["detections"] = list()
        else:
            ret["detections"].append(
                {
                    k: (v if fn is None else fn(v))
                    for (k, fn), v in zip(element_out, re.findall(element_regex, l)[0])
                }
            )

    if ret is not None:
        yield ret


def compile_results(per_interval, report):
    result = list()

    REP_2_IDX = {}
    start_time = None

    for i, rep in enumerate(report):
        if start_time is None:
            start_time = rep["timestamp"]
        rep["per_interval"] = list()
        result.append(rep)
        REP_2_IDX[rep["report_num"]] = rep

    for pi in per_interval:
        rnum = pi.pop("report_num")
        res = REP_2_IDX.get(rnum+1)
        if res is None:
            # print("No report for interval", rnum)
            continue

        assert pi["interval"] == len(res["per_interval"]), "FAILED"
        del pi["interval"]
        # assert pi["timestamp"] == res["timestamp"], str(pi["timestamp"]) + " != " + str(res["timestamp"])
        res["per_interval"].append(pi)

    return result


def parse_results(folder, t):
    try:
        per_interval, report = load_files(folder, t)
    except FileNotFoundError as e:
        return None

    report_parsed = parse(report, REPORT_TITLE_REGEX, REPORT_TITLE_OUT, REPORT_ELEMENT_REGEX, REPORT_ELEMENT_OUT)
    per_interval_parsed = parse(per_interval, INTERVAL_TITLE_REGEX, INTERVAL_TITLE_OUT, INTERVAL_ELEMENT_REGEX, INTERVAL_ELEMENT_OUT)

    # print(list(report_parsed))
    # print(list(per_interval_parsed))

    return compile_results(per_interval_parsed, report_parsed)


if __name__ == "__main__":
    folder = Path("./verification-data")
    for i, f in enumerate(folder.glob(REPORT_FNAME_FN("*"))):
        t = f.name[REPORT_TIME_IDX_START:REPORT_TIME_IDX_END]
        print(i, f.name, t, end="")

        result = parse_results(folder, t)
        
        if result is None:
            print(": Missing files for", t)
            continue
        else:
            print()

        with open(folder / f"result-{t}.json", "w") as f:
            json.dump(result, f, indent=2)
